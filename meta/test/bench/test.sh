#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="BENCH.LUA"

cd ../../../util
echo | $INTERP $SCRIPT 1980
cd ../meta/bench
echo | $INTERP $SCRIPT 1980
echo "BENCH: PASS"