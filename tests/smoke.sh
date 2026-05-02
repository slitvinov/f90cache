#!/bin/sh
# smoke.sh — sanity test for f90cache.
#
# Verifies cache hit/miss for the two patches in this fork:
#   * INCLUDE files are part of the hash (changing SIZE produces a miss)
#   * -D flags are part of the hash (toggling -DBAR produces a miss)
#
# Builds f90cache if needed, runs in an isolated cache dir, exits 0 on
# success.

set -e
DIR=$(cd "$(dirname "$0")"/.. && pwd)
F90CACHE=${F90CACHE:-$DIR/f90cache}

if [ ! -x "$F90CACHE" ]; then
    ( cd "$DIR" && make >/dev/null )
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cat > "$TMP/foo.f" <<'EOF'
      subroutine hello
      include 'SIZE'
      print *, 'lx1=', LX1
#ifdef BAR
      print *, 'with bar'
#endif
      end
EOF

cat > "$TMP/SIZE" <<'EOF'
      integer LX1
      parameter (LX1 = 8)
EOF

md5() {
    /sbin/md5 -q "$1" 2>/dev/null || md5sum "$1" | awk '{print $1}'
}

export F90CACHE_DIR="$TMP/cache"
"$F90CACHE" -z >/dev/null

# 1) cold compile
"$F90CACHE" gfortran -cpp -I"$TMP" -c "$TMP/foo.f" -o "$TMP/o1.o"
m1=$(md5 "$TMP/o1.o")

# 2) repeat — must hit the cache, identical .o
"$F90CACHE" gfortran -cpp -I"$TMP" -c "$TMP/foo.f" -o "$TMP/o1b.o"
m1b=$(md5 "$TMP/o1b.o")
[ "$m1" = "$m1b" ] || { echo "FAIL: identical compile produced different .o"; exit 1; }

# 3) edit the INCLUDE'd SIZE — must miss, different .o
cat > "$TMP/SIZE" <<'EOF'
      integer LX1
      parameter (LX1 = 12)
EOF
"$F90CACHE" gfortran -cpp -I"$TMP" -c "$TMP/foo.f" -o "$TMP/o2.o"
m2=$(md5 "$TMP/o2.o")
[ "$m1" != "$m2" ] || { echo "FAIL: SIZE change should miss the cache"; exit 1; }

# 4) toggle -DBAR — must miss, different .o
"$F90CACHE" gfortran -cpp -DBAR -I"$TMP" -c "$TMP/foo.f" -o "$TMP/o3.o"
m3=$(md5 "$TMP/o3.o")
[ "$m2" != "$m3" ] || { echo "FAIL: -DBAR should miss the cache"; exit 1; }

# 5) repeat with -DBAR — must hit
"$F90CACHE" gfortran -cpp -DBAR -I"$TMP" -c "$TMP/foo.f" -o "$TMP/o3b.o"
m3b=$(md5 "$TMP/o3b.o")
[ "$m3" = "$m3b" ] || { echo "FAIL: identical -DBAR compile differs"; exit 1; }

echo "smoke: ok"
