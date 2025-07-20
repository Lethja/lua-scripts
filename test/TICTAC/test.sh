#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="TICTAC.LUA"

printf "1\n2\n3\n4\n\5\n6\n7\n8\n9\nn\n" | $INTERP $SCRIPT
echo && echo "TICTAC: PASS"