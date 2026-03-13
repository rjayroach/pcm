---
---

# Plan 01 — Provider Model

## Context — read these files first

- `CLAUDE.md` — project overview, current schema documentation
- `pcm` — the main script, all changes happen here
- `~/.config/pcm/conf.d/vaults.yml` — current vault/roles config (will be migrated)
- `~/.config/pcm/conf.d/gh.yml` — credential definition using `vault:` key
- `~/.config/pcm/conf.d/aws.yml` — credential definition using `vault:` key

## Overview

Replace the `roles` config concept with `providers` throughout the pcm script.
Rename CLI flags, env vars, and internal function names. Update the config
loading to read `providers:` instead of `roles:`, and credential definitions
to use `provider:` instead of `vault:`.

This plan does NOT touch docs (CLAUDE.md, README.md) — that's Plan 04.
This plan does NOT touch plugin files — that's Plan 03.
This plan does NOT add `~/.config/pcm/pcm.yml` loading — that's Plan 02.

## Implementation

### 1. Config schema comment block (top of pcm script)

Update the embedded schema documentation. The new schema is:

```yaml
backend: op

providers:
  workspace: vault-name
  user: vault-name
  accounts: vault-name

credentials:
  gh:
    provider: user
    fields:
      token:
        env: GH_TOKEN
```

Replace the old comment block that shows `defaults:`, `vaults:`, `roles:`, and `credentials:` with the new schema. Remove `defaults:` section from the comment — `backend:` is now top-level.

### 2. Config reading section

After `_build_config` and `_cfg` are defined, the script currently reads:

```bash
PCM_DEFAULT_BACKEND=$(_cfg '.defaults.backend // "op"')
_cfg_workspace=$(_cfg '.roles.workspace')
_cfg_personal=$(_cfg '.roles.personal')
_cfg_credentials=$(_cfg '.roles.credentials')
PCM_VAULT_ROLE_WORKSPACE="${PCM_VAULT_ROLE_WORKSPACE:-$_cfg_workspace}"
PCM_VAULT_ROLE_PERSONAL="${PCM_VAULT_ROLE_PERSONAL:-$_cfg_personal}"
PCM_VAULT_ROLE_CREDENTIALS="${PCM_VAULT_ROLE_CREDENTIALS:-$_cfg_credentials}"
```

Replace with:

```bash
PCM_DEFAULT_BACKEND=$(_cfg '.backend // .defaults.backend // "op"')

_cfg_workspace=$(_cfg '.providers.workspace')
_cfg_user=$(_cfg '.providers.user')
_cfg_accounts=$(_cfg '.providers.accounts')

PCM_PROVIDER_WORKSPACE="${PCM_PROVIDER_WORKSPACE:-$_cfg_workspace}"
PCM_PROVIDER_USER="${PCM_PROVIDER_USER:-$_cfg_user}"
PCM_PROVIDER_ACCOUNTS="${PCM_PROVIDER_ACCOUNTS:-$_cfg_accounts}"
```

Note: backend reading supports both `backend:` (new) and `defaults.backend` (existing) for transitional compatibility within this refactoring — the old `defaults:` path will be removed once all config files are migrated.

### 3. Vault role resolution functions

Rename all internal functions and variables:

- `_require_workspace_vault` → `_require_workspace` — check `PCM_PROVIDER_WORKSPACE`
- `_require_personal_vault` → `_require_user` — check `PCM_PROVIDER_USER`
- `_require_credentials_vault` → `_require_accounts` — check `PCM_PROVIDER_ACCOUNTS`
- `_resolve_vault` — update the case statement:
  - `personal)` → `user)` calling `_require_user`, using `$PCM_PROVIDER_USER`
  - `workspace)` → stays `workspace)` calling `_require_workspace`, using `$PCM_PROVIDER_WORKSPACE`
  - `credentials)` → `accounts)` calling `_require_accounts`, using `$PCM_PROVIDER_ACCOUNTS`
  - Default (empty) still falls through to workspace
  - `*` wildcard still treats unknown values as literal vault names

### 4. `cmd_get` help text and flags

Update `cmd_get_help`:
- Change `-p` description from "from personal vault" to nothing (remove `-p`)
- Add `-u` as "from user provider"
- Change `-c` description from "from credentials vault" to nothing (remove `-c`)
- Add `-a` as "from accounts provider"
- Update examples to use `provider` language
- Update "Vault selection" comment to "Provider selection"

Update `cmd_get` flag parsing:
- `-p)` → `-u)` setting `from="user"`
- `-c)` → `-a)` setting `from="accounts"`
- `-w)` stays, setting `from="workspace"`

### 5. `cmd_vault` (renamed to `cmd_vault`)

The `cmd_vault_list` function currently uses `_show_role` with `PCM_VAULT_ROLE_*` vars.

Update `cmd_vault_list`:
- Show providers instead of roles:
  - `_show_role "workspace"   "${PCM_PROVIDER_WORKSPACE:-}"    "PCM_PROVIDER_WORKSPACE"`
  - `_show_role "user"        "${PCM_PROVIDER_USER:-}"         "PCM_PROVIDER_USER"`
  - `_show_role "accounts"    "${PCM_PROVIDER_ACCOUNTS:-}"     "PCM_PROVIDER_ACCOUNTS"`

Update `cmd_vault_show`:
- Replace `PCM_VAULT_ROLE_WORKSPACE/PERSONAL/CREDENTIALS` references with `PCM_PROVIDER_WORKSPACE/USER/ACCOUNTS`
- Update role detection to use the new names

Update `cmd_vault_create`:
- Replace `_require_credentials_vault` with `_require_accounts`
- Replace `PCM_VAULT_ROLE_CREDENTIALS` with `PCM_PROVIDER_ACCOUNTS`

### 6. Credential resolution in `_get_credential_env`

The function currently reads `.credentials.${cred_name}.vault` to determine which vault/provider to use. Update to read `.credentials.${cred_name}.provider` first, falling back to `.credentials.${cred_name}.vault` during transition:

```bash
local cred_provider
cred_provider=$(_cfg ".credentials.${cred_name}.provider")
# Fallback to vault for transitional compatibility
if [[ -z "$cred_provider" ]]; then
  cred_provider=$(_cfg ".credentials.${cred_name}.vault")
fi
```

Same pattern in `cmd_get` where it reads `.credentials.${item_name}.vault` — update to check `.provider` first, fall back to `.vault`.

Same in `cmd_credentials_list` and `cmd_credentials_show`.

### 7. `cmd_token` section

Update:
- `_require_workspace_vault` → `_require_workspace`
- `PCM_VAULT_ROLE_WORKSPACE` → `PCM_PROVIDER_WORKSPACE`
- `_require_credentials_vault` → `_require_accounts`
- `PCM_VAULT_ROLE_CREDENTIALS` → `PCM_PROVIDER_ACCOUNTS`
- Keychain key stays: `pcm-sa-token-${PCM_PROVIDER_WORKSPACE}` (same format)

### 8. `cmd_remote_env` section

Update:
- `_require_workspace_vault` → `_require_workspace`
- `PCM_VAULT_ROLE_WORKSPACE` → `PCM_PROVIDER_WORKSPACE`
- `_require_credentials_vault` → `_require_accounts`
- `PCM_VAULT_ROLE_CREDENTIALS` → `PCM_PROVIDER_ACCOUNTS`

### 9. `cmd_config` section

Update the "Roles:" section to "Providers:":

```bash
echo ""
echo "Providers:"
_show_role "workspace"   "${PCM_PROVIDER_WORKSPACE:-}"    "PCM_PROVIDER_WORKSPACE"
_show_role "user"        "${PCM_PROVIDER_USER:-}"         "PCM_PROVIDER_USER"
_show_role "accounts"    "${PCM_PROVIDER_ACCOUNTS:-}"     "PCM_PROVIDER_ACCOUNTS"
```

Also update the "Backend:" section to read from the new config path:

```bash
echo "Backend:"
echo "  ${PCM_DEFAULT_BACKEND}"
```

### 10. `cmd_list` section

Update `_require_workspace_vault` → `_require_workspace` and `PCM_VAULT_ROLE_WORKSPACE` → `PCM_PROVIDER_WORKSPACE`.

### 11. `cmd_help`

Update:
- Flag descriptions: `-p` → `-u` (user provider), `-c` → `-a` (accounts provider)
- "Env var overrides" section: rename all three vars
- General language: "vault" → "provider" where it refers to the logical concept

### 12. Dispatch table

No changes needed — the dispatch table routes by command name, not by internal concepts.

### 13. Migrate config files

After all script changes, update the actual config files:

**`~/.config/pcm/conf.d/vaults.yml`** — rename `roles:` to `providers:`, rename keys:

```yaml
# PCM vault configuration

backend: op

vaults:
  rjayroach:
  Private:
  lgat:

providers:
  user: rjayroach
  accounts: Private
```

Note: `defaults:` section is removed. `backend:` moves to top level. `roles:` becomes `providers:`. `personal` becomes `user`. `credentials` becomes `accounts`.

**`~/.config/pcm/conf.d/gh.yml`** — change `vault:` to `provider:`:

```yaml
credentials:
  gh:
    provider: user
    fields:
      token:
        env: GH_TOKEN
```

**`~/.config/pcm/conf.d/aws.yml`** — change `vault:` to `provider:`:

```yaml
credentials:
  aws:
    provider: workspace
    fields:
      access-key-id:
        env: AWS_ACCESS_KEY_ID
      secret-access-key:
        env: AWS_SECRET_ACCESS_KEY
```

**`~/spaces/rjayroach/technical/infra/unifi/.pcm.yml`** — change `vault:` to `provider:`:

```yaml
credentials:
  unifi:
    provider: workspace
    fields:
      credential:
        env: UNIFI_API_KEY
      hostname:
        env: UNIFI_API
  wifi:
    provider: workspace
    fields:
      password:
        env: TF_VAR_wifi_passphrase
```

### 14. Update completions

In `lib/completions.zsh`:
- Update `_pcm_get` to use `-u` and `-a` instead of `-p` and `-c`
- Update descriptions to use "provider" language

## Test Spec

No automated tests (this is a bash script). Manual verification:

```bash
# Provider resolution
pcm vault list
# Should show: workspace, user, accounts with vault names

pcm config
# Should show Providers: section (not Roles:)
# Should show Backend: op

# Credential reading with new flags
pcm get -u gh/token           # should read from user provider (rjayroach vault)
pcm get -w unifi/credential   # should read from workspace provider
pcm get -a some-token         # should read from accounts provider

# Credential mode
pcm get gh                    # should output export GH_TOKEN='...'
pcm get aws                   # should output export lines

# Help
pcm help                      # should show -u, -a flags (not -p, -c)
pcm get                       # help should show -u, -a
```

## Verification

- [ ] `grep -n 'VAULT_ROLE' pcm` — returns nothing (all renamed to PROVIDER)
- [ ] `grep -n 'roles\.' pcm` — returns nothing (all renamed to providers)
- [ ] `grep -n '\-p)' pcm` — returns nothing in cmd_get (flag removed)
- [ ] `grep -n '\-c)' pcm` — returns nothing in cmd_get (flag removed)
- [ ] `pcm config` shows "Providers:" section with workspace, user, accounts
- [ ] `pcm vault list` shows workspace, user, accounts
- [ ] `pcm help` shows `-u` and `-a` flags
- [ ] `pcm get -u gh/token` reads from the correct vault
- [ ] `pcm credentials list` shows provider name (not vault name) for each credential
