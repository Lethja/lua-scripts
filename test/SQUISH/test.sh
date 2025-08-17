#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="SQUISH.LUA"

mkdir -p test
cp $SCRIPT test
SCRIPT="test/$SCRIPT"
BEFORE=$(stat -L -c%s "$SCRIPT")
$INTERP $SCRIPT $SCRIPT
AFTER=$(stat -L -c%s "$SCRIPT")
if [ "$AFTER" -ge "$BEFORE" ]; then echo "SQUISH: FAIL"; exit 1; fi
$INTERP $SCRIPT $SCRIPT
FINAL=$(stat -L -c%s "$SCRIPT")
echo

rm -R test

if [ "$AFTER" -eq "$FINAL" ]; then
  echo "SQUISH: PASS";
else
  echo "SQUISH: FAIL"; exit 1;
fi