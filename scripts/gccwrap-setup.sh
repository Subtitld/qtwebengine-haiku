#!/bin/bash
# Make /build/gcc-wrap a GCC_EXEC_PREFIX whose cc1/cc1plus run the real ones
# with GCC's garbage collector set to collect early (less peak memory per
# job); everything else in GCC's directory is linked as is. The driver
# derives -iprefix from GCC_EXEC_PREFIX, so the wrappers put the real one
# back for the standard headers to be found.
set -e
real=$(g++ -print-prog-name=cc1plus)
realdir=$(dirname "$real")
triple=$(g++ -dumpmachine)
version=$(g++ -dumpversion)
dir=/build/gcc-wrap/$triple/$version
rm -rf /build/gcc-wrap
mkdir -p "$dir"
for f in "$realdir"/*; do ln -s "$f" "$dir/$(basename "$f")"; done
for prog in cc1 cc1plus; do
  rm -f "$dir/$prog"
  cat > "$dir/$prog" <<WRAP
#!/bin/bash
args=()
fix=0
for a in "\$@"; do
  if [ \$fix = 1 ]; then args+=("$realdir/"); fix=0; continue; fi
  [ "\$a" = -iprefix ] && fix=1
  args+=("\$a")
done
exec "$realdir/$prog" --param ggc-min-expand=20 --param ggc-min-heapsize=131072 "\${args[@]}"
WRAP
  chmod +x "$dir/$prog"
done
ls "$dir" | head -20
