# Lua Scripts

[![Lua Scripts](https://github.com/Lethja/lua-scripts/actions/workflows/LuaScripts.yml/badge.svg)](https://github.com/Lethja/lua-scripts/actions/workflows/LuaScripts.yml)

These are Lua scripts that are distributed with or help build 
[Lua for Watcom](https://github.com/Lethja/lua-watcom) 
but are useful scripts that can be used with any Lua 5.4 compatible interpreter.
The scripts range from simple demos to clones of unix utilities,
which can be particularly useful on platforms that have no native equivalent.

Most scripts have a unit test to make sure they work as intended.

The scripts are split into the following folders:

| Folder Name      | Description                                                                                                              |
|------------------|--------------------------------------------------------------------------------------------------------------------------|
| [bench](./bench) | Contains symbolic links to each script that is needed to run every benchmark in `BENCH.LUA`                              |
| [core](./core)   | Scripts that go in all distributions of Lua for Watcom, namely included in the 160K floppy disk image for really old PCs |
| [test](./test)   | Unit tests                                                                                                               |
| [util](./util)   | Scripts that help with the build process of Lua for Watcom but aren't included on any disk                               | 
| [xtra](./xtra)   | Extra scripts that are omitted from the 160K floppy disk image duo to space constants                                    |
