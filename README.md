These are Lua scripts that are distributed with or help build 
[Lua for Watcom](https://github.com/Lethja/lua-watcom).
The scripts range from simple demos to clones of unix utilities
that are particularly useful on platforms that have no native equivalent.

Unfortunately, some scripts have been squashed
so they can all fit in the size limits of a floppy disk, 
which can cause unintentional obfuscation of code.
Unit tests have been created in these instances to make sure the script works
as intended.

The scripts are split into the following folders:

| Folder Name      | Description                                                                                                              |
|------------------|--------------------------------------------------------------------------------------------------------------------------|
| [bench](./bench) | Contains symbolic links to each script that is needed to run every benchmark in `BENCH.LUA`                              |
| [core](./core)   | Scripts that go in all distributions of Lua for Watcom, namely included in the 160K floppy disk image for really old PCs |
| [test](./test)   | Unit tests for scripts that require them                                                                                 |
| [util](./util)   | Scripts that help with the build process of Lua for Watcom but aren't included on any disk                               | 
| [xtra](./xtra)   | Extra scripts that are omitted from the 160K floppy disk image duo to space constants                                    |
