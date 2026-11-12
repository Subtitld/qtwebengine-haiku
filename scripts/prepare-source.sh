#!/bin/bash
# Build the patched QtWebEngine 6.10.3 source tree for Haiku:
#   1. the release tarball (sha256 checked),
#   2. FreeBSD ports' www/qt6-webengine patches (Qt 6.10.2, freebsd-ports
#      fbb8b4880d68), fetched from GitHub and applied as is, except the
#      security rollup (6.10.3 already has it) and one patch ported by hand,
#   3. the Haiku patches in patches/haiku, in order.
#
# Usage: prepare-source.sh DIR      (DIR is created; the tree ends up in
#                                     DIR/qtwebengine-everywhere-src-6.10.3,
#                                     a git repo with one commit per layer)
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
DIR=${1:?usage: prepare-source.sh DIR}
VERSION=6.10.3
TARBALL=qtwebengine-everywhere-src-$VERSION.tar.xz
SHA256=07c95f81d64391b3dd5b0edce7fc7eb2e8d39844e4904f82ae53f5533f4cf043
FREEBSD_COMMIT=fbb8b4880d68baab53928de9cf4caecfea559668

mkdir -p "$DIR"
cd "$DIR"

if [ ! -f "$TARBALL" ]; then
  curl -fL -o "$TARBALL" \
    "https://download.qt.io/archive/qt/6.10/$VERSION/submodules/$TARBALL"
fi
echo "$SHA256  $TARBALL" | sha256sum -c -

SRC=$DIR/qtwebengine-everywhere-src-$VERSION
[ -e "$SRC" ] && { echo "$SRC already exists"; exit 1; }
tar xf "$TARBALL"

cd "$SRC"
git init -q -b main
git add -A
git commit -q -m "QtWebEngine $VERSION as released ($TARBALL)"

# FreeBSD layer.
FREEBSD=$DIR/freebsd-ports
if [ ! -d "$FREEBSD/www/qt6-webengine/files" ]; then
  git init -q "$FREEBSD"
  git -C "$FREEBSD" remote add origin https://github.com/freebsd/freebsd-ports.git
  git -C "$FREEBSD" config core.sparseCheckout true
  echo www/qt6-webengine/ > "$FREEBSD/.git/info/sparse-checkout"
  git -C "$FREEBSD" fetch -q --depth 1 --filter=blob:none origin "$FREEBSD_COMMIT"
  git -C "$FREEBSD" checkout -q FETCH_HEAD
fi
failed=()
for p in "$FREEBSD"/www/qt6-webengine/files/patch-*; do
  case "$(basename "$p")" in
    patch-security-rollup) continue ;;
    patch-src_3rdparty_chromium_base_allocator_partition__allocator_src_partition__alloc_partition__alloc__constants.h) continue ;;
  esac
  # -N: QtToolchainHelpers' patch reports a hunk as already applied.
  patch -p0 -s -N --no-backup-if-mismatch -r - < "$p" > /dev/null || failed+=("$(basename "$p")")
done
for f in "${failed[@]}"; do
  [ "$f" = patch-cmake_QtToolchainHelpers.cmake ] || { echo "FreeBSD patch failed: $f"; exit 1; }
done
git apply "$HERE/patches/freebsd/partition_alloc_constants.patch"
mkdir -p src/3rdparty/chromium/media/audio/sndio \
         src/3rdparty/chromium/sandbox/policy/freebsd \
         src/3rdparty/chromium/sandbox/policy/openbsd
git add -A
git commit -q -m "FreeBSD ports www/qt6-webengine patches (freebsd-ports ${FREEBSD_COMMIT:0:12}, Qt 6.10.2)"

# Haiku layer.
git am -q "$HERE"/patches/haiku/*.patch
git log --oneline | head -3
echo "Source ready: $SRC"
