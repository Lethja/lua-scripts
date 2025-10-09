#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
TEST="BASE64 ENCODE"
SCRIPT="BASE64.LUA"

GNU=$(base64 $SCRIPT)
LUA=$($INTERP $SCRIPT $SCRIPT)

if [ "$GNU" = "$LUA" ]; then
  echo "$TEST: PASS"
else
  echo "$TEST: FAIL"
  exit 1
fi

TEST="BASE64 DECODE"

LUA=$(echo $GNU | $INTERP $SCRIPT -d)
GNU=$(cat $SCRIPT)

if [ "$GNU" = "$LUA" ]; then
  echo "$TEST: PASS"
  exit 0
else
  echo "$TEST: FAIL"
  exit 1
fi