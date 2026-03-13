---
status: complete
started_at: "2026-03-13T15:42:00+08:00"
completed_at: "2026-03-13T15:48:21+08:00"
deviations: null
summary: Restructured CLI into four resource groups (credential, vault, plugin, cache) with consistent REST verbs
---

# Execution Log

## What Was Done

- Renamed `cmd_credentials*` → `cmd_credential*` (singular noun)
- Moved `cmd_get` logic into `cmd_credential_get` (simplified: no flags, project-scoped only)
- Moved `cmd_validate` logic into `cmd_credential_validate`
- Renamed `cmd_plugins*` → `cmd_plugin*` (singular noun)
- Added `cmd_plugin_list --installed` flag for project-installed plugins
- Moved `cmd_init` logic into `cmd_plugin_add`
- Renamed `cmd_token*` → `cmd_cache*` with verb renames (get→show)
- Changed `cmd_vault_list` to list vaults from the backend via new `_pcm_list_vaults` interface
- Removed dropped commands: `get` (top-level), `list`, `new`, `init`, `validate`, `token`
- Hidden `completions` and `remote-env` from help and completions (still functional)
- Updated dispatch table to only route new command names
- Updated `cmd_help` to show four grouped sections
- Renamed `_show_role` → `_show_provider`
- Added `_pcm_list_vaults` to `lib/op.sh` backend interface
- Rewrote `lib/completions.zsh` for new API surface
- Updated `.env.schema` templates in pcm-plugins and infra repos (`pcm get` → `pcm credential get`)
- Updated script header comments

## Removed Functions

- `cmd_get`, `cmd_get_help`
- `cmd_list`
- `cmd_new`, `cmd_new_help`
- `cmd_init`, `cmd_init_help`
- `cmd_validate`, `cmd_validate_help`
- `cmd_token`, `cmd_token_help`, `cmd_token_get`, `cmd_token_clear`, `cmd_token_list`
- `cmd_credentials`, `cmd_credentials_help`, `cmd_credentials_list`, `cmd_credentials_show`
- `cmd_plugins`, `cmd_plugins_help`, `cmd_plugins_available`, `cmd_plugins_show`

## Test Results

- `pcm help` — shows four grouped sections, no old commands
- `pcm credential list` — works
- `pcm credential show gh` — works
- `pcm credential validate` — works
- `pcm vault list` — returns JSON from 1Password backend
- `pcm vault show rjayroach` — works
- `pcm plugin list` — shows registry plugins
- `pcm plugin list --installed` — works (shows "no plugins" when not in a project)
- `pcm plugin show unifi` — works
- `pcm cache list` — works
- `pcm config` — works
- Old commands (`get`, `list`, `new`, `init`, `validate`, `token`) return "Unknown command"
- Hidden commands (`completions`, `remote-env`) still functional
- `grep` confirms no stale function names

## Context Updates

- CLI surface restructured into four resource groups: `credential`, `vault`, `plugin`, `cache` — all singular nouns with consistent REST verbs.
- `pcm credential get` replaces top-level `pcm get`. Simplified: no `-w/-u/-a/--from` flags, no `VAR_NAME` positional — always project-scoped via config.
- `pcm credential validate` replaces top-level `pcm validate`.
- `pcm plugin add` replaces `pcm init` and `pcm new`.
- `pcm cache {list,show,clear}` replaces `pcm token {list,get,clear}`.
- `pcm vault list` now lists vaults from the backend (JSON) instead of showing provider mappings. Backend interface gained `_pcm_list_vaults`.
- `completions` and `remote-env` are hidden commands — functional but not in help or completions.
- Internal helper `_show_role` renamed to `_show_provider`.
