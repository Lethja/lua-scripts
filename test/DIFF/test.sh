#!/usr/bin/env sh

INTERP=${INTERP:-lua}
SCRIPT="../DIFF.LUA"
FAIL=0

test_case() {
  mkdir -p result
  cp "case$1"/* result
  cd "result" || die
  $INTERP $SCRIPT a.txt b.txt > "diff"
  patch -s --batch -p0 < "diff"
  if cmp -s a.txt b.txt; then
    echo "CASE $1: PASS"
  else
    echo "CASE $1: FAIL"
    FAIL=$((FAIL + 1))
  fi
  cd .. || die
  rm -R result
}

for i in $(seq -w 1 16); do test_case "$i"; done
echo ""
if [ $FAIL -gt 0 ]; then echo "$FAIL FAIL" exit 1; fi
echo "ALL PASS"
