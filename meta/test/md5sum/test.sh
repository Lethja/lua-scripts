#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
TEST="MD5SUM"
SCRIPT="MD5SUM.LUA"

GNU=$(md5sum $SCRIPT)
LUA=$($INTERP $SCRIPT $SCRIPT)

if [ "$GNU" = "$LUA" ]; then
  echo "$TEST: PASS"
  exit 0
else
  echo "$TEST: FAIL"
  exit 1
fi