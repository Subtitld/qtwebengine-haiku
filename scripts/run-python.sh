#!/bin/sh
# Run Python with the PySide6 that pyside-build.sh built and the QtWebEngine
# in $QTWE_PREFIX, e.g. `run-python.sh smoke-test.py out.png`. EXTRAPY adds
# to PYTHONPATH; TMO is the time limit in seconds.
QTWE_PREFIX=${QTWE_PREFIX:-/build/install}
QTWE_OUT=${QTWE_OUT:-/build/out}
P=${WORK:-/build/pyside}/pyside-setup-everywhere-src-6.10.3/build/qfp-py3.14-qt6.10.3-64bit-release/package
export LIBRARY_PATH="$QTWE_PREFIX/lib:%A/lib:/boot/home/config/non-packaged/lib:/boot/home/config/lib:/boot/system/non-packaged/lib:/boot/system/lib"
export PYTHONPATH=$P${EXTRAPY:+:$EXTRAPY}
export QTWEBENGINEPROCESS_PATH=$QTWE_PREFIX/lib/Qt6/QtWebEngineProcess
export QTWEBENGINE_RESOURCES_PATH=$QTWE_OUT/src/core/Release/x86_64
export QTWEBENGINE_LOCALES_PATH=$QTWE_OUT/src/core/Release/x86_64/qtwebengine_locales
exec timeout ${TMO:-150} python3.14 "$@"
