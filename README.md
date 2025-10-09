# Lua Scripts

[![Lua Scripts](https://github.com/Lethja/lua-scripts/actions/workflows/LuaScripts.yml/badge.svg)](https://github.com/Lethja/lua-scripts/actions/workflows/LuaScripts.yml)

These are Lua scripts that are distributed with or help build 
[Lua for Watcom](https://github.com/Lethja/lua-watcom) 
but are useful scripts that can be used with any Lua 5.4 compatible interpreter.
The scripts range from simple demos to clones of unix utilities,
which can be particularly useful on platforms that have no native equivalent.

Most scripts have a unit test to make sure they work as intended.

The scripts are split into the following folders:

| Folder Name      | Description                                                                                                                |
|------------------|----------------------------------------------------------------------------------------------------------------------------|
| [dev](./dev)     | Scripts focused on software development an maintenance                                                                     |
| [edu](./edu)     | Simple scripts intended for those learning how to write Lua                                                                |
| [games](./games) | Simple text based games                                                                                                    |
| [lib](./lib)     | Scripts pulled in by require and not intended to be executed directly                                                      |                                                                              |
| [meta](./meta)   | Symbolic links to scripts that are structured in a way that defines a purpose such as a benchmark, unit test or disk image |
| [util](./util)   | Utility scripts that perform a common system task such as file integrity or converting line endings in a text file         |
