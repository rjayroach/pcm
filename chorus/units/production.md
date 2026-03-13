---
objective: You can trust it
status: complete
---

Production tier — Provider model refactoring.

Replaces the `roles` concept with `providers`, restructures the global config,
renames CLI flags and env vars, and updates all config files, plugins, and docs
to match the new model.

## Key Design Decisions

- Three built-in **providers**: `workspace`, `user`, `accounts`
  - `workspace` — current project context (replaces roles.workspace)
  - `user` — the entity operating the tool, personal credentials (replaces roles.personal)
  - `accounts` — service account tokens for vault access (replaces roles.credentials)
- `backend:` is a top-level config key (not nested)
- `vaults:` section is optional, only needed for multi-backend scenarios
- Primary global config at `~/.config/pcm/pcm.yml`, loaded before `conf.d/`
- Credential definitions use `provider:` instead of `vault:`
- CLI flags: `-w` (workspace), `-u` (user), `-a` (accounts)
- Env vars: `PCM_PROVIDER_WORKSPACE`, `PCM_PROVIDER_USER`, `PCM_PROVIDER_ACCOUNTS`

## Completion Criteria

- `roles:` section completely removed from config schema and code
- `vault:` key in credential definitions replaced with `provider:`
- CLI flags `-p` and `-c` replaced with `-u` and `-a`
- Env vars renamed from `PCM_VAULT_ROLE_*` to `PCM_PROVIDER_*`
- `~/.config/pcm/pcm.yml` loaded as primary global config before `conf.d/`
- All plugin credential definitions use `provider:` not `vault:`
- CLAUDE.md and README.md reflect the new model
- All existing config files migrated
- `pcm config` shows provider resolution correctly
- `pcm help` reflects new flags and terminology
