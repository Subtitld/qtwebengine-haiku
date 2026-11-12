#!/bin/sh
# Build Chromium (the QtWebEngineCore ninja target) directly, keeping going
# past failures (-k 0), so one pass lists every file that fails.
# Log: /build/out/chromium.log; the failing commands: /build/out/failed.txt
D=/build/out/src/core/Release/x86_64
cd $D || exit 1
echo "start $(date)" > /build/out/chromium.log
NODEJS_EXECUTABLE=/boot/system/bin/node ninja -k 0 -j3 QtWebEngineCore >> /build/out/chromium.log 2>&1
echo "exit $? $(date)" >> /build/out/chromium.log
grep "^FAILED:" /build/out/chromium.log > /build/out/failed.txt
