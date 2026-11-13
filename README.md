# QtWebEngine 6 for Haiku

A port of **QtWebEngine 6.10.3** (Chromium 134) to Haiku x86_64, built from
source with Haiku's GCC 13.

Status: **work in progress**. The whole module builds on Haiku
(`libQt6WebEngineCore`, `libQt6WebEngineWidgets`, `QtWebEngineProcess`),
and `scripts/smoke-test.cpp` passes: a `QWebEngineView` on the offscreen
platform loads a page, runs JavaScript, grabs it to an image with a
transparent background and exits cleanly, with software compositing
(`--disable-gpu --no-sandbox`). GPU rasterisation does not work yet, and
there are no Python (PySide6) bindings for it yet.

The first goal is what [Subtitld](https://subtitld.org) needs: QtWebEngine
Widgets rendering pages offscreen in software, with a transparent
background, so its HTML subtitle renderer works on Haiku. The configuration
switches off what that does not need (WebRTC, PDF, printing, spellcheck,
extensions, geolocation, proprietary codecs, Vulkan, Quick).

## How the port is put together

The tree is built in three layers (`scripts/prepare-source.sh`):

1. The QtWebEngine 6.10.3 release tarball.
2. FreeBSD ports' `www/qt6-webengine` patches for Qt 6.10.2
   (freebsd-ports commit `fbb8b4880d68`), about 1,000 files: they make
   Chromium build on a POSIX system that is not Linux. They are fetched from
   the FreeBSD ports repository, not copied here. 1,034 of 1,037 apply to
   6.10.3 as they are; the security rollup is left out (6.10.3 carries those
   fixes) and one patch is ported by hand (`patches/freebsd/`).
3. The Haiku patches in `patches/haiku/`, one commit each.

The idea that keeps layer 3 small: in GN, Haiku is `is_linux`, `is_bsd`
and `is_haiku`; in C++ it is `IS_BSD`, `IS_HAIKU` and `IS_POSIX` (not
`IS_LINUX`). Every exception FreeBSD added to Chromium's Linux code applies
to Haiku too, and the compiler points at each place where a BSD-only call
(sysctl, kqueue vnodes, pthread_np) needs a Haiku branch. The same is done
in each library with its own OS detection (V8, PartitionAlloc, Perfetto,
Abseil, Skia, Dawn, WebRTC).

## Haiku-specific findings

- Haiku's `runtime_loader` rejects the `R_X86_64_TPOFF64` relocations a
  position-independent executable gets for libstdc++'s `std::call_once`
  state ("Troubles relocating: Bad data" in `/var/log/syslog`), so
  executables link without `-pie`.
- Haiku's GCC defines no `__unix__`, maps `__declspec(x)` to
  `__attribute__((x))`, and uses the old copy-on-write `std::string`.
- Node's `os.cpus()` is empty on Haiku, which left terser with no workers
  and rollup waiting for ever in the DevTools build.
- Chromium's `pkg-config.py` returns nothing on unknown platforms.
- No epoll or eventfd: Chromium's message pump waits with `poll()` (it
  already keeps a poll list beside its epoll set) and wakes through a pipe.
- Thread ids, stack bounds, process lists, memory statistics, the
  executable path and debugger detection come from Haiku's kernel API
  (`find_thread`, `get_thread_info`, `get_team_info`, `get_next_area_info`,
  `get_next_image_info`).
- Haiku's ninja can stop with "Error writing to build log: Interrupted
  system call"; it resumes cleanly, so `scripts/build.sh` restarts it.
- `getifaddrs` lists interfaces without an address.
- Qt's offscreen platform on Haiku gives the same family for every font
  style hint, and Haiku's fontconfig has no aliases for its Noto fonts, so
  the default web fonts are chosen by name there.
- Powering the VM off mid-build can leave files damaged inside while they
  still look valid. Here it broke six build tools (`brotli` among them,
  which left Blink with an empty default stylesheet).
  `scripts/hostcheck.sh` relinks each tool and keeps the new copy only
  where it differs.

## Known limitations

No sandbox (Haiku has none to use), no camera, USB or HID access, no
file-change watching, no V8 WebAssembly trap handler, media start times
without FFmpeg's first DTS (Haiku's FFmpeg 6.1 does not export it), UDP
multicast without interface indexes.

## Building

A Haiku R1/beta6 x86_64 VM in QEMU does the building; the host keeps the
git tree and syncs changes into the VM.

1. Install Haiku, enable SSH, and put the VM's key next to the scripts as
   `ssh_key` (with `ssh_key.pub` in Haiku's `~/config/settings/ssh/authorized_keys`).
   `scripts/haiku.sh` expects `system.qcow2` and a second disk
   `build.qcow2` (200 GB, BFS, mounted at `/build`) in the same folder.
2. In the VM, install the build dependencies:
   `qt6_base_devel qt6_declarative_devel qt6_webchannel_devel
   qt6_tools_devel qt6_positioning_devel qt6_svg_devel
   qt6_shadertools_devel cmake ninja nodejs24 gperf bison flex git
   python3.10 html5lib_python310 icu74_devel harfbuzz_devel
   fontconfig_devel freetype_devel libjpeg_turbo_devel libpng16_devel
   libwebp_devel lcms_devel opus_devel libxslt_devel libxml2_devel
   zlib_devel minizip_devel snappy_devel re2_devel nss_devel pkgconfig
   ffmpeg6_devel dbus_devel expat_devel libexecinfo_devel rsync`.
3. On the host, `scripts/prepare-source.sh DIR` builds the patched tree.
   In the VM, unpack the same release tarball in `/build/src`; then
   `QTWE_SRC=DIR/qtwebengine-everywhere-src-6.10.3 scripts/sync.sh` copies
   every file the patches touch into it.
4. In the VM: `/build/configure.sh`, then `/build/build.sh` (log in
   `/build/out/build.log`). `scripts/watch.sh` on the host waits for the
   next failure.

`haiku.sh` logs the VM's serial port to `run/serial-*.log`; with
`serial_debug_output true` in Haiku's
`~/config/settings/kernel/drivers/kernel`, kernel messages and the kernel
debugger land there.

Memory decides how many jobs Haiku can take: GCC needs 1–3 GB per Blink
file, and when Haiku runs short of physical pages (its kernel logs
"low resource pages: critical") it freezes rather than slowing down. What
keeps a 10 GB VM going:

- no jumbo build, 1 job: some content/browser files need about 4 GB of
  GCC each, so even 2 overrun 8 GB;
- `scripts/gccwrap-setup.sh` builds `/build/gcc-wrap`, a `GCC_EXEC_PREFIX`
  whose `cc1`/`cc1plus` run GCC with `--param ggc-min-expand=20
  --param ggc-min-heapsize=131072` (it collects garbage early); `build.sh`
  exports it. Compile commands stay the same, so nothing is rebuilt;
- no BFS indexes on the build disk (`rmindex -d /build name`, `size`,
  `last_modified`): they serve only file queries, cost a write per file,
  and a damaged one made every write to the disk hang;
- `scripts/memguard.py`, run in the VM, follows the kernel's low-resource
  state in the syslog and pauses the newest compiler from the warning level
  ("note") on: a paused compiler keeps its memory, so waiting for
  "critical" is too late.

## Prior work

- HaikuPorts' QtWebEngine 5.15 port (Gerasim Troeglazov), the guide to where
  Chromium needs Haiku code; parts of its V8 platform file are carried
  forward here.
- FreeBSD ports' `www/qt6-webengine` (layer 2 above).

## Licence

The patches here are under the licences of the files they change (Qt's
LGPL/GPL for QtWebEngine, BSD for Chromium). The scripts are under the
BSD 3-clause licence (`scripts/LICENSE`).
