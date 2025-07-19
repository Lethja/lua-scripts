#!/usr/bin/env sh

INTERP=${INTERP:-lua}
TEST="S256SUM"
SCRIPT="S256SUM.LUA"

GNU=$(sha256sum $SCRIPT)
LUA=$($INTERP $SCRIPT $SCRIPT)

if [ "$GNU" = "$LUA" ]; then
  echo "$TEST PASS"
  exit 0
else
  echo "$TEST FAIL"
  exit 1
fi