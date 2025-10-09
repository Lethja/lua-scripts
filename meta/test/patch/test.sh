#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="../PATCH.LUA"
FAIL=0

test_case() {
  mkdir -p result
  cp "case$1"/* result
  cd "result"
  echo "## CASE $1: START  ##"
  diff -u a.txt b.txt > "diff"
  if [ -f "c.txt" ] && [ -f "d.txt" ]; then diff -u c.txt d.txt >> "diff"; fi
  $INTERP $SCRIPT diff
  if [ -f "c.txt" ] && [ -f "d.txt" ]; then
    if { set +e; cmp -s a.txt b.txt; } && { set +e; cmp -s c.txt d.txt; }; then
      printf "## CASE %s: PASS   ##\n" "$1"
    else
      printf "## CASE %s: FAIL   ##\n" "$1"
      FAIL=$((FAIL + 1))
    fi
  else
    if { set +e; cmp -s a.txt b.txt; }; then
      printf "## CASE %s: PASS   ##\n" "$1"
    else
      printf "## CASE %s: FAIL   ##\n" "$1"
      FAIL=$((FAIL + 1))
    fi
  fi
  cd ..
  rm -R result
}
echo "## PATCH:          ##"
for i in $(seq -w 1 21); do test_case "$i"; done
echo ""
if [ $FAIL -gt 0 ]; then echo "## PATCH: $FAIL FAIL ##"; exit 1; fi
echo "## PATCH: ALL PASS ##"
