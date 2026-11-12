#!/bin/bash
# ssh into the installed Haiku (haiku.sh boot, build VM), with this VM's own key only
# (the agent's keys would use up sshd's MaxAuthTries first).
HERE=$(dirname "$(realpath "$0")")
exec ssh -i "$HERE/ssh_key" -o IdentitiesOnly=yes -o IdentityAgent=none -p 2244 \
    -o UserKnownHostsFile="$HERE/known_hosts" -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 -o ServerAliveInterval=30 user@127.0.0.1 "$@"
