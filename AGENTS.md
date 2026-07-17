# AGENTS.md

## Repo overview

Lua mpv script that saves playback position using a content-based hash (MD5 of file-size + duration) so the same file at different paths/devices resolves to the same progress file. Deployed by copying `mpv-progress-sync/` into mpv's `scripts/` directory.

No build system, no tests, no CI, no package manager. Editing is direct Lua editing.

## Architecture

- `mpv-progress-sync/main.lua` — entrypoint. Registers two mpv events:
  - `file-loaded` — reads `{hash}.json` from the position folder and seeks to saved position
  - `shutdown` — writes current `time-pos` to `{hash}.json`
- `mpv-progress-sync/lib/` — vendored dependencies: `md5.lua`, `decoder.lua` (lunajson), `encoder.lua` (lunajson), `sax.lua` (lunajson dependency). Do not move or delete.

## Platform paths (hardcoded in `main.lua`)

These are the only place deploy locations are configured. Changing the install path requires editing these variables:

| Platform | Position folder | Script folder |
|---|---|---|
| Linux/Mac | `$HOME/.config/mpv/mpv-positions/` | `$HOME/.config/mpv/scripts/mpv-progress-sync/lib/` |
| Windows (scoop) | `%USERPROFILE%\scoop\apps\mpv\current\portable_config\mpv-positions\` | `%USERPROFILE%\scoop\apps\mpv\current\portable_config\scripts\mpv-progress-sync\lib\` |
| Android | `/storage/emulated/0/Android/media/is.xyz.mpv/mpv-positions/` | `/storage/emulated/0/Android/media/is.xyz.mpv/mpv-progress-sync/lib/` |

## Gotchas

- The `isPlaying` global flag prevents saving a nil position on exit (mpv sets `time-pos` to nil during shutdown).
- Positions less than 2 seconds are not saved. Files with under 5 seconds remaining have position reset to 0 before saving.
- Filename sanitization (`[^%w%.%-_]` → `_`) applies to the hash, not the original filename — the hash is MD5 of `file-size + duration`, so it's always alphanumeric.
- YouTube videos use `mp.get_property("force-media-title")` instead of file metadata for the hash.
- `mkdir` on Windows does not support `-p`; the script branches on OS to handle this.
- Cross-device sync requires an external sync tool (e.g., Syncthing) to keep the position folders in sync.
