# Relink every host tool; keep the new copy only where it differs from the old one.
cd /build/out/src/core/Release/x86_64
for f in $(find host -maxdepth 1 -type f -perm -u+x); do
  case $f in *.so|*.py|*.sh) continue;; esac
  cp -p $f $f.bak && rm $f
  if ninja $f > /dev/null 2>&1 && [ -f $f ]; then
    if cmp -s $f $f.bak; then mv $f.bak $f; else echo "DIFFERS $f"; rm $f.bak; fi
  else
    echo "relink failed $f"; mv $f.bak $f
  fi
done
echo done
