#!/bin/bash
# Copy the host source tree's changes since the release (its first commit) into the
# build VM's tree, /build/src/qtwebengine-everywhere-src-6.10.3. Files the
# port deletes are deleted there too.
set -euo pipefail
HERE=$(dirname "$(realpath "$0")")
# The prepared tree on the host (scripts/prepare-source.sh); set QTWE_SRC.
SRC=${QTWE_SRC:?set QTWE_SRC to the prepared qtwebengine-everywhere-src-6.10.3}
DST=/build/src/qtwebengine-everywhere-src-6.10.3
SSH="ssh -i $HERE/ssh_key -o IdentitiesOnly=yes -o IdentityAgent=none -o UserKnownHostsFile=$HERE/known_hosts -p 2244"
cd "$SRC"
BASE=$(git rev-list --max-parents=0 HEAD)
git ls-files -m -o --exclude-standard > /tmp/haiku-sync-wt.txt
{ git diff --name-only --diff-filter=d $BASE HEAD; grep -v '^$' /tmp/haiku-sync-wt.txt || true; } | sort -u | while read -r f; do [ -f "$f" ] && echo "$f"; done > /tmp/haiku-sync.txt
rsync -a --files-from=/tmp/haiku-sync.txt -e "$SSH" . user@127.0.0.1:$DST/
gone=$(git diff --name-only --diff-filter=D $BASE HEAD)
[ -n "$gone" ] && echo "$gone" | $SSH user@127.0.0.1 "cd $DST && xargs rm -f"
echo "synced $(wc -l < /tmp/haiku-sync.txt) files"
