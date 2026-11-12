#!/bin/bash
# Sync the host tree, run the build until it stops, then print the first
# compiler/ninja error with some context.
HERE=$(dirname "$(realpath "$0")")
"$HERE/sync.sh" >/dev/null || exit 1
"$HERE/ssh.sh" 'sh /build/build.sh
L=/build/out/build.log
grep -E "^\[[0-9]+/[0-9]+\]" $L | tail -1
n=$(grep -n -m1 -E "^FAILED:|^ninja: error|error:" $L | cut -d: -f1)
[ -n "$n" ] && sed -n "$((n)),$((n+'"${1:-40}"'))p" $L | cut -c1-400
tail -1 $L'
