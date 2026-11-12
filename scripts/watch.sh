#!/bin/bash
# Wait until the VM's build has a new failure, has ended, or SSH stops
# answering for 10 minutes; then print the state. Checks once a minute.
HERE=$(dirname "$(realpath "$0")")
start=$("$HERE/ssh.sh" -o BatchMode=yes 'grep -c "^FAILED:" /build/out/build.log; true' 2>/dev/null | head -1); start=${start:-0}
misses=0
while true; do
  sleep 60
  out=$(timeout 60 "$HERE/ssh.sh" -o BatchMode=yes 'L=/build/out/build.log; echo "$(grep -c "^FAILED:" $L) $(grep -c "^exit " $L)"' 2>/dev/null)
  if [ -z "$out" ]; then
    misses=$((misses+1)); [ $misses -ge 10 ] && { echo "VM not answering for 10 minutes"; break; }
    continue
  fi
  misses=0
  set -- $out
  if [ "$1" -gt "$start" ] || [ "$2" -gt 0 ]; then break; fi
done
timeout 60 "$HERE/ssh.sh" -o BatchMode=yes 'tail -1 /build/mem.log; L=/build/out/build.log; grep -E "^\[[0-9]+/[0-9]+\]" $L | tail -1 | cut -c1-40; grep -c "^FAILED:" $L; tail -1 $L | cut -c1-60; grep -E "(fatal )?error:" $L | sed -E "s/.*chromium\///" | sed -E "s/:[0-9]+:[0-9]+:/:/" | cut -c1-200 | sort | uniq -c | sort -rn | head -30'
