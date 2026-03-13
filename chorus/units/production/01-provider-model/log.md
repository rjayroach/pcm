---
status: complete
started_at: "2026-03-13T14:30:34+08:00"
completed_at: "2026-03-13T14:36:14+08:00"
deviations: null
summary: Replaced roles concept with providers throughout pcm script, config files, and completions
---

# Execution Log

## What Was Done

- Renamed `roles:` config key to `providers:` with keys `workspace`, `user`, `accounts`
- Moved `backend:` to top-level (with fallback to `defaults.backend` for transition)
- Renamed all internal functions: `_require_workspace_vault` → `_require_workspace`, `_require_personal_vault` → `_require_user`, `_require_credentials_vault` → `_require_accounts`
- Updated `_resolve_vault` case statement: `personal)` → `user)`, `credentials)` → `accounts)`
- Changed CLI flags: `-p` → `-u` (user), `-c` → `-a` (accounts)
- Renamed env vars: `PCM_VAULT_ROLE_*` → `PCM_PROVIDER_*`
- Updated credential resolution to read `.provider` first, falling back to `.vault` for transitional compatibility
- Updated `cmd_config` to show "Providers:" instead of "Roles:"
- Updated all credential display functions to show "provider:" instead of "vault:"
- Updated zsh completions (`lib/completions.zsh`) with new flags and provider names
- Migrated `~/.config/pcm/conf.d/vaults.yml`: `roles:` → `providers:`, `defaults:` → top-level `backend:`
- Migrated `~/.config/pcm/conf.d/gh.yml`: `vault: personal` → `provider: user`
- Migrated `~/.config/pcm/conf.d/aws.yml`: `vault: workspace` → `provider: workspace`
- Migrated `~/spaces/rjayroach/technical/infra/unifi/.pcm.yml`: `vault:` → `provider:`

## Test Results

- `grep VAULT_ROLE pcm` — no matches (all renamed)
- `grep 'roles\.' pcm` — no matches (all renamed)
- `grep '\-p)' pcm` — no matches in cmd_get
- `grep '\-c)' pcm` — no matches in cmd_get
- `pcm config` — shows "Providers:" with workspace, user, accounts
- `pcm vault list` — shows workspace, user, accounts
- `pcm help` — shows `-u` and `-a` flags
- `pcm get -u gh/token` — correctly resolves user → rjayroach vault
- `pcm credentials list` — shows provider name for each credential
- `pcm credentials show gh` — shows "Provider: user (rjayroach)"

## Notes

Pre-existing display issue: `cmd_credentials_list` and `cmd_credentials_show` show empty env var names after `->`. This is a yq syntax compatibility issue with the `if type == "array"` expression, not introduced by this change.

## Context Updates

- Three providers replace the former three roles: `workspace` (unchanged), `user` (was `personal`), `accounts` (was `credentials`).
- `backend:` is now a top-level config key. `defaults.backend` is still supported as fallback.
- CLI flags for `pcm get`: `-w` (workspace), `-u` (user), `-a` (accounts). Old `-p` and `-c` are removed.
- Env vars: `PCM_PROVIDER_WORKSPACE`, `PCM_PROVIDER_USER`, `PCM_PROVIDER_ACCOUNTS` replace the old `PCM_VAULT_ROLE_*` vars.
- Credential definitions support both `provider:` (new) and `vault:` (fallback) keys for transitional compatibility.
- Config files at `~/.config/pcm/conf.d/` use `providers:` and `provider:` keys.
