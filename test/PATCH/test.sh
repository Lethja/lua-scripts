#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="../PATCH.LUA"
FAIL=0

test_case() {
  mkdir -p result
  cp "case$1"/* result
  cd "result"
  diff -u a.txt b.txt > "diff"
  $INTERP $SCRIPT diff
  if { set +e; cmp -s a.txt b.txt; }; then
    printf "\tCASE %s: PASS\n" "$1"
  else
    printf "\tCASE %s: FAIL\n" "$1"
    FAIL=$((FAIL + 1))
  fi
  cd ..
  rm -R result
}
echo "PATCH:"
for i in $(seq -w 1 15); do test_case "$i"; done
echo ""
if [ $FAIL -gt 0 ]; then echo "PATCH: $FAIL FAIL"; exit 1; fi
echo "PATCH: ALL PASS"
