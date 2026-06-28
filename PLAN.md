# Fix Plan for mpv-progress-sync

## Issues Found

### Critical Bugs

1. **OS detection broken on Linux with LuaJIT** (`main.lua:198-199`)
   mpv bundles LuaJIT, so `jit.os` returns `"Linux"`. But the conditions check for `'GNU/Linux'`, `'OSX'`, `'Darwin'` — `"Linux"` matches none of them. The script silently loads no decoder/encoder and writes to an empty folder. This is likely the #1 reason the script doesn't work for most users.

2. **OS detection broken on Toybox Android** (`main.lua:202-208`)
   Toybox-based Android ROMs return `"Linux"` from `uname -o`. Same problem — no condition matches, script silently fails.

3. **JSON decode can crash mpv** (`main.lua:82`)
   If a position file is corrupted, `decode(content)` throws an unhandled error that crashes mpv. Should be wrapped in `pcall`.

4. **`data.loc` used without nil check** (`main.lua:89`)
   If the JSON file doesn't have a `loc` key, `mp.commandv("seek", nil, "absolute+exact")` crashes mpv.

### Medium Issues

5. **Decoder/encoder loaded on every `file-loaded` event** (`main.lua:28-34, 45-51, 63-69`)
   These are expensive to load via `loadfile()`. Should be done once at script startup.

6. **Path definitions duplicated** — script folder paths appear in both the `file-loaded` handler (lines 26, 43, 60-61) and `getFilename()` (lines 163, 167, 170-171). Changing a path requires editing two places.

7. **`mkdir` without quoting** (`main.lua:117-120`)
   `os.execute("mkdir " .. folder)` breaks if the path contains spaces.

8. **`filename` global can be overwritten** between `file-loaded` and `shutdown`
   If another file loads between the timer firing and shutdown, the shutdown handler sanitizes whatever `filename` is at that point, not the one being shut down.

9. **`data` from JSON not validated** (`main.lua:82-89`)
   If `decode()` returns a non-table or table without `loc`, the seek crashes.

### Minor / Style Issues

10. `decode = nil` on line 13 then immediately reassigned — unnecessary.
11. `md5 = nil` on line 161 then reassigned — unnecessary.
12. `loadFile()` defined at line 152 but used from line 28 — works in Lua, but bad order.
13. `myos` is declared global at line 6 but also assigned inside `getOS()` — confusing scope.
14. `duration` local in `getFilename()` (line 185) shadows the global — works correctly but is confusing.
15. No error logging if write fails (`main.lua:127-129`).
16. `"OSX"` check on line 23 is only reachable if LuaJIT is present — it's not dead code, but the dual OS detection path (`jit.os` vs `uname -o`) is fragile.

## Plan

| # | Fix | File | Effort |
|---|-----|------|--------|
| 1 | **Fix OS detection**: normalize `jit.os` and `uname -o` output to a single canonical set (Linux, OSX, Windows, Android). Map `"Linux"` → Linux path, `"Android"`/`"Toybox"` → Android path. | `main.lua` | Small |
| 2 | **Wrap JSON decode in `pcall`** with graceful fallback (no seek, print warning) | `main.lua` | Small |
| 3 | **Validate `data` and `data.loc`** before seeking | `main.lua` | Small |
| 4 | **Load decoder/encoder once at startup**, not per file | `main.lua` | Small |
| 5 | **Deduplicate path constants** into a single table, referenced from both `file-loaded` and `getFilename()` | `main.lua` | Small |
| 6 | **Quote paths in `mkdir`** calls | `main.lua` | Trivial |
| 7 | **Capture filename per-file** (local in file-loaded) instead of relying on global for shutdown | `main.lua` | Small |
| 8 | Clean up: remove redundant `nil` assignments, reorder `loadFile` definition, clean up `getOS()` scope | `main.lua` | Trivial |
