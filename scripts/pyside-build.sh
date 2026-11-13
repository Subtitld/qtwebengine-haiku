#!/bin/sh
# Build PySide6 6.10.3 with its QtWebEngineCore and QtWebEngineWidgets
# modules against the QtWebEngine installed in $QTWE_PREFIX, in the VM.
#
# Needs: llvm21 llvm21_clang llvm21_libs llvm21_openmp pyside6_python3.14
# installer_python3.14 build_python3.14 setuptools_python3.14
# wheel_python3.14 packaging_python3.14, and `cmake --install /build/out`
# done (it installs into /build/install).
#
# The source is the release tarball with HaikuPorts' patchset for it
# (dev-python/pyside6) and this repository's patches/pyside on top. Only
# the modules QtWebEngineWidgets needs are built; the result is in
# build/qfp-py3.14-qt6.10.3-64bit-release/package (PySide6, shiboken6).
set -e
QTWE_PREFIX=${QTWE_PREFIX:-/build/install}
WORK=${WORK:-/build/pyside}
PATCHES=${PATCHES:-$(dirname "$(realpath "$0")")/../patches/pyside}
VERSION=6.10.3
TARBALL=pyside-setup-everywhere-src-$VERSION.tar.xz
SHA256=2c7462fe0cecb5b8ac0a3d92014b8d0b88bd4d9f8646709dab5286d9416f45bc
HAIKUPORTS=https://raw.githubusercontent.com/haikuports/haikuports/master/dev-python/pyside6/patches/pyside6-$VERSION.patchset

mkdir -p "$WORK" && cd "$WORK"
SRC=$WORK/pyside-setup-everywhere-src-$VERSION
if [ ! -d "$SRC" ]; then
	[ -f $TARBALL ] || curl -fLO https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-$VERSION-src/$TARBALL
	echo "$SHA256  $TARBALL" | sha256sum -c -
	[ -f pyside6-$VERSION.patchset ] || curl -fLo pyside6-$VERSION.patchset $HAIKUPORTS
	tar xf $TARBALL
	cd "$SRC"
	patch -p1 < "$WORK/pyside6-$VERSION.patchset"
	for p in "$PATCHES"/*.patch; do patch -p1 < "$p"; done
fi

cd "$SRC"
unset HAIKU_USE_VENDOR_DIRECTORIES
export CMAKE_PREFIX_PATH=$QTWE_PREFIX
export QT_ADDITIONAL_PACKAGES_PREFIX_PATH=$QTWE_PREFIX
# llvm-config --libdir says develop/lib; clang's builtin headers are in lib/clang/21.
export CLANG_INSTALL_DIR=/boot/system
# The .pyi step runs Python with LIBRARY_PATH set to the build's libraries plus
# this value (read at configure time): it needs the system's paths, and
# QtWebEngine's.
export LIBRARY_PATH="$QTWE_PREFIX/lib:%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib"
python3.14 setup.py build \
	--qtpaths=/boot/system/lib/Qt6/qtpaths6 \
	--qt-tools-path=/boot/system/lib/Qt6 \
	--no-qt-tools --reuse-build --parallel=3 \
	--module-subset=Core,Gui,Widgets,PrintSupport,Network,WebChannel,Positioning,WebEngineCore,WebEngineWidgets
