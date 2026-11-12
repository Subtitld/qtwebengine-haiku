#!/bin/bash
# Haiku R1/beta6 build VM for porting QtWebEngine 6, in QEMU.
# system.qcow2 is haiku-test's clean-base snapshot (fresh install, SSH set up);
# build.qcow2 (200 GB) is a second disk for sources and build trees, mounted at /build.
#   haiku.sh boot       boot it: ssh on 127.0.0.1:2244 (ssh.sh), screen on VNC :7
#   haiku.sh stop       shut Haiku down from inside and wait for QEMU to end
#   haiku.sh shot OUT.png
# Never power it off while Haiku runs (qmp quit, kill): it loses cached writes.
# The disk this lives on is a USB drive: keep it plugged in and mounted while it runs.
set -euo pipefail
HERE=$(dirname "$(realpath "$0")")
RUN=$HERE/run
mkdir -p "$RUN"
running() { [ -f "$RUN/qemu.pid" ] && kill -0 "$(cat "$RUN/qemu.pid")" 2>/dev/null; }
case "${1:-}" in
boot)
    running && { echo "already running"; exit 1; }
    qemu-system-x86_64 -name haiku-build -machine q35 -accel kvm -cpu host \
        -smp "${SMP:-8}" -m "${MEM:-8192}" \
        -device qemu-xhci -device usb-tablet -vga std \
        -display none -vnc 127.0.0.1:7 -qmp unix:"$RUN/qmp.sock",server=on,wait=off \
        -daemonize -pidfile "$RUN/qemu.pid" \
        -serial file:"$RUN/serial-$(date +%Y%m%d-%H%M).log" \
        -drive file="$HERE/system.qcow2",if=none,id=d0 -device ide-hd,drive=d0,bus=ide.1,bootindex=0 \
        -drive file="$HERE/build.qcow2",if=none,id=d1 -device ide-hd,drive=d1,bus=ide.2 \
        -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2244-:22 -device e1000,netdev=n0
    ;;
stop)
    running || { echo "not running"; exit 0; }
    "$HERE/ssh.sh" 'sync; shutdown -q' >/dev/null 2>&1 || true
    for _ in $(seq 180); do running || { echo "stopped"; exit 0; }; sleep 1; done
    echo "still running after 3 minutes: shut it down from its screen (Deskbar, Shut down)"; exit 1
    ;;
shot)
    "$HERE/qmp.py" shot "$2"
    ;;
*)
    sed -n 2,9p "$0"; exit 1
    ;;
esac
