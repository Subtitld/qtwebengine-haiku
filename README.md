# QtWebEngine 6 for Haiku

A port of **QtWebEngine 6.10.3** (Chromium 134) to Haiku x86_64, built from
source with Haiku's GCC 13.

Status: **work in progress**. The source configures and GN generates on
Haiku; Chromium compiles through V8 and most of the base, network and media
layers, and Chromium's own build tools run on Haiku. Nothing has been
linked or run yet.

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
file. With a 10 GB VM, 4 jobs and no jumbo build is stable; more made Haiku
page itself to a standstill.

## Prior work

- HaikuPorts' QtWebEngine 5.15 port (Gerasim Troeglazov), the guide to where
  Chromium needs Haiku code; parts of its V8 platform file are carried
  forward here.
- FreeBSD ports' `www/qt6-webengine` (layer 2 above).

## Licence

The patches here are under the licences of the files they change (Qt's
LGPL/GPL for QtWebEngine, BSD for Chromium). The scripts are under the
BSD 3-clause licence (`scripts/LICENSE`).
