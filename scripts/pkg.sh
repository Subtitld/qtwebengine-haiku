#!/bin/sh
# pkgman install with a log and a time limit (it once hung in the foreground).
nohup sh -c "pkgman install -y $* > /build/pkgman.log 2>&1; echo exit \$? >> /build/pkgman.log" < /dev/null > /dev/null 2>&1 &
for i in $(seq 90); do sleep 5; grep -q "^exit" /build/pkgman.log 2>/dev/null && break; done
grep -E "install package|upgrade package|^exit|rror" /build/pkgman.log
