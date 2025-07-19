These are Lua scripts are distributed or help build Lua for Watcom.
The scripts range from simple demos to clones of unix utilities
that are particularly useful on platforms that have no native equivalent.

Unfortunately, some scripts have been squashed
so they can all fit in the size limits of a floppy disk, 
which can cause unintentional obfuscation of code.
To rectify this, markdown files with the same name will document functions and
variables.

The scripts are split into the following folders:

| Folder Name    | Description                                                                                |
|----------------|--------------------------------------------------------------------------------------------|
| [core](./core) | Scripts that go in all distribution, namely included in the 160K floppy disk image         |
| [util](./util) | Scripts that help with the build process of Lua for Watcom but aren't included on any disk | 
| [xtra](./xtra) | Extra scripts that are omitted from the 160K floppy disk image duo to space constants      |
