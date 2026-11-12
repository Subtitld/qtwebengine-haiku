#!/usr/bin/env python3
"""Keep Haiku out of the page-starved freeze during the build.

Haiku logs its low-resource state for pages ("low resource pages: X -> Y")
to the syslog. While the state is critical, pause (SIGSTOP) the newest
compiler; once it has been normal for 30 s, resume the oldest paused one.
At least one compiler always keeps running. Logs to /build/memguard.log.
"""
import os
import re
import signal
import subprocess
import time

SYSLOG = '/var/log/syslog'
LOG = '/build/memguard.log'
STATE_RE = re.compile(r'low resource pages: \w+ -> (\w+)')


def log(msg):
    with open(LOG, 'a') as f:
        f.write(time.strftime('%H:%M:%S ') + msg + '\n')


def compilers():
    """Team ids of running cc1/cc1plus, oldest first (ids grow).

    ps cuts names at about 60 characters, which leaves GCC's programs as
    ".../lib/gcc/<triple>/": the only ones of ours that live there.
    """
    out = subprocess.run(['ps'], capture_output=True, text=True).stdout
    ids = []
    for line in out.splitlines():
        parts = line.split()
        if parts and '/lib/gcc/' in parts[0]:
            for p in parts[1:]:
                if p.isdigit():
                    ids.append(int(p))
                    break
    return sorted(set(ids))


def main():
    state = 'normal'
    normal_since = time.time()
    paused = []
    pos = os.path.getsize(SYSLOG) if os.path.exists(SYSLOG) else 0
    while True:
        try:
            size = os.path.getsize(SYSLOG)
            if size < pos:
                pos = 0  # rotated
            with open(SYSLOG, errors='replace') as f:
                f.seek(pos)
                for line in f:
                    m = STATE_RE.search(line)
                    if m:
                        state = m.group(1)
                        if state == 'normal':
                            normal_since = time.time()
                pos = f.tell()
        except OSError:
            pass

        paused = [t for t in paused if t in compilers()]
        running = [t for t in compilers() if t not in paused]
        if state == 'critical' and len(running) > 1:
            team = running[-1]
            os.kill(team, signal.SIGSTOP)
            paused.append(team)
            log(f'critical: paused {team} ({len(running) - 1} running)')
        elif (state == 'normal' and paused
              and time.time() - normal_since > 30):
            team = paused.pop(0)
            os.kill(team, signal.SIGCONT)
            normal_since = time.time()
            log(f'normal: resumed {team}')
        time.sleep(3)


if __name__ == '__main__':
    main()
