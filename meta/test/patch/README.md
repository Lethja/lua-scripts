# PATCH.LUA

## Overview

`patch.lua` reads a unified diff from standard patch format
and applies each hunk to the target file.

- splits each hunk into context, additions, deletions
- validates that the original text matches before removing lines
- writes the patched output (preserving or dropping a trailing newline as directed)

It is a self-contained, single-pass Lua script with no external dependencies.

## Usage

- `diff.txt` is a patch file in unified-diff format.
- The script will open each file mentioned by a `--- a.txt` / `+++ b.txt` header, back up its contents to `*.orig`, then
  rewrite it in place.

## How It Works

### Command-line & Main Loop

1. The script reads `diff.txt` line by line via `pf:read("*l")`.
2. It keeps a look-ahead `next_line` so it can detect the `\ No newline at end of file` marker before deciding whether
   to emit a `\n`.

### Filename Parsing (`parseFileName`)

- Extract the filename from a line like `--- "a.txt"` or `--- a.txt` end
- Strips quoting (`"` or `'`) if present.
- Otherwise, splits on whitespace and takes the second token.

### Preparing a File (`setPatchFile`)

1. Open `f` for reading
2. Copy its entire contents to `f.orig`
3. Reopen `f` for writing (truncating it)
4. Configures both reader (`rf`) and writer (`wf`) handles and lines (`rl`/`wl`)

- On failure at any step, aborts cleanly and reports the I/O error.

### Writing Remaining Context (`writeRemainder`)

After the last hunk of a file is applied, any lines remaining in the original (`rf`) are written unchanged to the new
file (`wf`).

### Diff-Line Dispatch

Each patch-file line is classified by its first character:

#### Additions (`+`)

- Lines beginning `+` (but not `++ `) are written to `wf`.

#### Deletions (`-`)

- A leading `-- ` indicates a new filename header (`--- a.txt`).
- Other `-` lines are verified against `rf:read("*l")`, then skipped (i.e. not written to `wf`).

#### Context (` `)

- Lines beginning with a space must match the next line in `rf`.
- If they do, they’re copied unchanged into `wf`; otherwise the script errors out.

#### Hunk Headers (`@@`)

- On seeing `@@ -oldStart,oldLen +newStart,newLen @@`, parse the four numbers.
- Before entering the new hunk, verify you consumed exactly `oldLen` & `newLen` lines since the last header.
- Skip any “leading context” between hunks by copying `(oldStart − 1) − rl` lines from `rf` → `wf`.

#### No-newline Marker (`\ No newline…`)

- If the next patch line after an addition is `\ No newline at end of file`, 
the script omits the final `\n` on that file.