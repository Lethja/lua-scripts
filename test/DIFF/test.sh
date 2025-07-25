#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="../DIFF.LUA"
FAIL=0

test_case() {
  mkdir -p result
  cp "case$1"/* result
  cd "result"
  diff -u a.txt b.txt > "diff-gnu"
  $INTERP $SCRIPT a.txt b.txt > "diff-lua"
  patch -s --posix --batch -p0 < "diff-lua"
  if { set +e; cmp -s a.txt b.txt; }; then
    printf "\tCASE %s: PASS\n" "$1"
    printf "\t\tSIZE:\n\t\t\tGNU: %'6d\n\t\t\tLUA: %'6d\n"\
      "$(stat -L -c%s diff-gnu)"\
      "$(stat -L -c%s diff-lua)"
  else
    printf "\tCASE %s: FAIL\n" "$1"
    FAIL=$((FAIL + 1))
  fi
  cd ..
  rm -R result
}
echo "DIFF:"
for i in $(seq -w 1 19); do test_case "$i"; done
echo ""
if [ $FAIL -gt 0 ]; then echo "DIFF: $FAIL FAIL"; exit 1; fi
echo "DIFF: ALL PASS"
