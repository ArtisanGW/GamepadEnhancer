#!/bin/sh
# Runs every test on LuaJIT and on elune (the game's Lua 5.1).
# From anywhere: tests/run_both.sh
cd "$(dirname "$0")/.." || exit 1
ELUNE="${ELUNE:-/var/home/artisan/Documents/Coding/WoW/elune/build/linux/bin/Release/lua5.1}"
echo "== luajit =="
luajit tests/run.lua || exit 1
echo "== elune =="
[ -x "$ELUNE" ] || { echo "elune not found at $ELUNE" >&2; exit 2; }
"$ELUNE" tests/run.lua
