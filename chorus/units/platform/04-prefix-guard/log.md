---
status: complete
started_at: "2026-03-13T14:56:30+08:00"
completed_at: "2026-03-13T14:58:01+08:00"
deviations: null
summary: Added centralized prefix guard that validates prefix env vars before credential resolution commands
---

# Execution Log

## What Was Done

- Added `_require_prefix` guard function after `_resolve_prefix` in the helpers section
- Guard checks all env vars referenced in `settings.prefix` and reports missing ones with a clear error message
- Added `_require_prefix` calls to:
  - `cmd_get` — after flag parsing, before resolving refs
  - `cmd_validate` — at start, after flag parsing
  - `cmd_credentials_list` — before listing
  - `cmd_credentials_show` — before showing
- Did NOT add guard to: cmd_config (diagnostic), cmd_plugins (no credential resolution), cmd_vault (vault operations), cmd_token (SA tokens), cmd_help, cmd_init/cmd_new (config creation)
- Added prefix note to `cmd_help` explaining the requirement
- Kept existing `_resolve_prefix` check as safety net

## Test Results

- `pcm validate` without PCM_SITE → "Prefix requires env vars that are not set: PCM_SITE"
- `pcm credentials list` without PCM_SITE → same clean error
- `pcm config` without PCM_SITE → works (diagnostic, no guard)
- `pcm plugins available` → works (no guard)
- With PCM_SITE set → all commands work normally
- In projects without `settings.prefix` → no guard triggers

## Notes

None.

## Context Updates

- `_require_prefix` is a centralized guard called early in credential-resolving commands.
- Commands that resolve credentials (get, validate, credentials list/show) now fail early with a clear error if prefix env vars are unset.
- Diagnostic commands (config, help) and vault/plugin commands are not guarded.
