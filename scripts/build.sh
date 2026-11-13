#!/bin/sh
# Build /build/out, logging to /build/out/build.log. Haiku's ninja sometimes
# stops with "Error writing to build log: Interrupted system call" (EINTR on
# .ninja_log); it resumes cleanly, so run it again when that is why it ended.
cd /build/out || exit 1
export NINJAFLAGS="-j1 -k 0"
# cc1/cc1plus wrappers that make GCC collect garbage early (gccwrap-setup.sh).
export GCC_EXEC_PREFIX=/build/gcc-wrap/
echo "start $(date)" > build.log
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  ninja -j1 >> build.log 2>&1
  status=$?
  grep -q "Error writing to build log: Interrupted system call" build.log || break
  sed -i 's/Error writing to build log: Interrupted system call/(ninja EINTR on its log, restarted)/' build.log
  echo "restart $attempt $(date)" >> build.log
done
echo "exit $status $(date)" >> build.log
