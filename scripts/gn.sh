#!/bin/bash
# Sync, rerun the outer build and stop as soon as GN finishes: print GN's error, or "GN OK".
HERE=$(dirname "$(realpath "$0")")
"$HERE/sync.sh" >/dev/null || exit 1
"$HERE/ssh.sh" 'nohup sh /build/build.sh > /dev/null 2>&1 < /dev/null &
sleep 5
until grep -qE "Running ninja for QtWebEngineCore|GN FAILED|^exit" /build/out/build.log; do sleep 10; done
if grep -q "GN FAILED" /build/out/build.log; then grep -A14 "ERROR at" /build/out/build.log | head -24; else echo "GN OK"; grep "Done. Made" /build/out/build.log; fi'
