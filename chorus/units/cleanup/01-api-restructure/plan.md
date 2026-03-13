---
---

# Plan 01 — API Restructure

## Context — read these files first

- `CLAUDE.md` — project overview, current API
- `pcm` — main script (all changes happen here)
- `lib/completions.zsh` — shell completions
- `chorus/units/cleanup.md` — target API and design decisions

## Overview

Restructure the entire CLI surface into four resource groups with consistent
REST verbs and singular nouns. This is a rename/reorganize of existing
functionality — no new features, no behavior changes.

The current-to-target mapping:

| Current | Target | Notes |
|---------|--------|-------|
| `pcm get <cred>` | `pcm credential get <cred>` | move under resource group |
| `pcm get <cred/field>` | `pcm credential get <cred/field>` | move under resource group |
| `pcm credentials list` | `pcm credential list` | singular |
| `pcm credentials show` | `pcm credential show` | singular |
| `pcm validate [--fix]` | `pcm credential validate [--fix]` | move under resource group |
| `pcm vault list` | `pcm vault list` | unchanged (already lists backend vaults) |
| `pcm vault show` | `pcm vault show` | unchanged |
| `pcm vault create` | `pcm vault create` | unchanged |
| `pcm plugins available` | `pcm plugin list` | singular + rename verb |
| `pcm plugins show` | `pcm plugin show` | singular |
| `pcm init <plugin>` | `pcm plugin add <name>` | move under resource group |
| `pcm plugins list --installed` | `pcm plugin list --installed` | new flag |
| `pcm token get` | `pcm cache show` | rename group + verb |
| `pcm token list` | `pcm cache list` | rename group |
| `pcm token clear` | `pcm cache clear` | rename group |
| `pcm list` | (removed) | redundant with credential validate |
| `pcm new` | (removed) | redundant with plugin add |
| `pcm get` (top-level) | (removed) | use credential get |
| `pcm completions` | (hidden) | not in help or completions |
| `pcm remote-env` | (hidden) | not in help or completions |

## Implementation

### 1. Restructure `cmd_credentials` → `cmd_credential`

Rename the function group from `cmd_credentials*` to `cmd_credential*`.

Add `get` and `validate` as subcommands. The existing `cmd_get` logic
(both credential mode and ref mode) moves into `cmd_credential_get`.
The existing `cmd_validate` logic moves into `cmd_credential_validate`.

The new `cmd_credential` dispatcher:

```bash
cmd_credential_help() {
  cat <<'EOF'
pcm credential — Credential operations

Usage: pcm credential <subcommand> [args...]

Subcommands:
  list                          List configured credentials
  show <name>                   Show config details for a credential
  get <name>                    Fetch all field values (export lines)
  get <name/field>              Fetch a single field value
  validate [--fix] [-y]         Check credentials exist, optionally provision
EOF
}

cmd_credential() {
  local subcmd="${1:-}"
  shift 2>/dev/null || true

  case "$subcmd" in
    list)     cmd_credential_list ;;
    show)     cmd_credential_show "$@" ;;
    get)      cmd_credential_get "$@" ;;
    validate) cmd_credential_validate "$@" ;;
    "")       cmd_credential_help ;;
    *)
      _error "Unknown credential subcommand: $subcmd"
      cmd_credential_help
      exit 1
      ;;
  esac
}
```

**`cmd_credential_list`**: Rename from `cmd_credentials_list`. No logic changes.

**`cmd_credential_show`**: Rename from `cmd_credentials_show`. No logic changes.

**`cmd_credential_get`**: Absorb the logic from the current `cmd_get`.
Remove the `-w`, `-u`, `-a`, `--from` flags — credential get is always
project-scoped, the provider comes from config. Remove the `VAR_NAME`
positional argument (the `export VAR='value'` output mode) — that's
handled by the env mapping in the field schema.

The simplified logic:
- If ref contains `/` → read single field from configured credential
- If ref has no `/` → read all fields (export lines) for credential

```bash
cmd_credential_get() {
  local ref="${1:-}"

  if [[ -z "$ref" ]]; then
    _error "Usage: pcm credential get <name> or pcm credential get <name/field>"
    exit 1
  fi

  _require_prefix

  # Credential mode: no slash means export all fields
  if [[ "$ref" != */* ]]; then
    if _get_credential_env "$ref"; then
      return 0
    else
      _error "'${ref}' is not a configured credential"
      exit 1
    fi
  fi

  # Ref mode: name/field — must be a configured credential
  local cred_name="${ref%%/*}"
  local field_name="${ref#*/}"

  local cred_provider
  cred_provider=$(_cfg ".credentials.${cred_name}.provider")
  if [[ -z "$cred_provider" ]]; then
    cred_provider=$(_cfg ".credentials.${cred_name}.vault")
  fi
  if [[ -z "$cred_provider" ]]; then
    _error "'${cred_name}' is not a configured credential"
    exit 1
  fi

  local vault
  vault=$(_resolve_vault "$cred_provider")

  local full_ref
  full_ref=$(_build_ref "$cred_name" "$field_name")
  _debug "Reading ${full_ref} from vault ${vault}"

  local value
  value=$(_pcm_read "$vault" "$full_ref")
  if [[ -z "$value" ]]; then
    _error "Failed to read ${full_ref} from vault ${vault}"
    exit 1
  fi

  echo "$value"
}
```

**`cmd_credential_validate`**: Rename from `cmd_validate`. Move the entire
function body (including `_validate_fix_item` helper). No logic changes.

### 2. Restructure `cmd_vault`

The current `cmd_vault_list` shows provider-to-vault mappings. Change it
to list vaults from the backend (replacing the old top-level `cmd_list`):

```bash
cmd_vault_list() {
  _load_backend "$PCM_DEFAULT_BACKEND"
  _debug "Listing vaults from backend ${PCM_DEFAULT_BACKEND}"
  # Use _pcm_list_vaults if available, otherwise list all known vaults
  # For op backend, this calls: op vault list --format json
  _pcm_list_vaults
}
```

This requires adding `_pcm_list_vaults` to the backend interface.

Add to `lib/op.sh`:

```bash
_pcm_list_vaults() {
  op vault list --format json 2> >(_pcm_stderr)
}
```

Update `cmd_vault_help`:

```bash
cmd_vault_help() {
  cat <<'EOF'
pcm vault — Vault operations

Usage: pcm vault <subcommand> [args...]

Subcommands:
  list                          List vaults in the backend
  show <name>                   Show details for a vault
  create <name>                 Create vault + service account + store SA token
    [--permissions PERMS]         SA permissions (default: read_items)
EOF
}
```

`cmd_vault_show` and `cmd_vault_create` — no changes needed.

### 3. Restructure `cmd_plugins` → `cmd_plugin`

Rename from `cmd_plugins*` to `cmd_plugin*`. Add `add` subcommand
(absorbs `cmd_init` logic). Add `--installed` flag to `list`.

```bash
cmd_plugin_help() {
  cat <<'EOF'
pcm plugin — Plugin operations

Usage: pcm plugin <subcommand> [args...]

Subcommands:
  list [--installed]            List available plugins (or installed in project)
  show <name>                   Show plugin details
  add <name>                    Apply a plugin to the current directory
EOF
}

cmd_plugin() {
  local subcmd="${1:-}"
  shift 2>/dev/null || true

  case "$subcmd" in
    list) cmd_plugin_list "$@" ;;
    show) cmd_plugin_show "$@" ;;
    add)  cmd_plugin_add "$@" ;;
    "")   cmd_plugin_help ;;
    *)
      _error "Unknown plugin subcommand: $subcmd"
      cmd_plugin_help
      exit 1
      ;;
  esac
}
```

**`cmd_plugin_list`**: Rename from `cmd_plugins_available`. Add `--installed` flag:

```bash
cmd_plugin_list() {
  local installed=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --installed) installed=1; shift ;;
      *) break ;;
    esac
  done

  if [[ $installed -eq 1 ]]; then
    # Show plugins from current project's .pcm.yml
    local plugins
    plugins=$(_cfg '.plugins | .[]')
    if [[ -z "$plugins" ]]; then
      echo "No plugins installed in current project"
      return 0
    fi
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      echo "  $p"
    done <<< "$plugins"
  else
    # Show available from registry (existing cmd_plugins_available logic)
    _require_registry

    local found=0
    for plugin_dir in "${PCM_PLUGINS_DIR}"/*/; do
      [[ -d "$plugin_dir" ]] || continue
      local manifest="${plugin_dir}plugin.yml"
      [[ -f "$manifest" ]] || continue

      local name description
      name=$(_yq '.name' "$manifest")
      description=$(_yq '.description' "$manifest")
      printf "%-15s %s\n" "$name" "$description"
      found=1
    done

    if [[ $found -eq 0 ]]; then
      echo "No plugins found in registry"
    fi
  fi
}
```

**`cmd_plugin_show`**: Rename from `cmd_plugins_show`. No logic changes.

**`cmd_plugin_add`**: Absorb the logic from `cmd_init`. Rename function.
No logic changes.

### 4. Restructure `cmd_token` → `cmd_cache`

Rename from `cmd_token*` to `cmd_cache*`. Rename subcommands:
`get` → `show`, `clear` stays, `list` stays.

```bash
cmd_cache_help() {
  cat <<'EOF'
pcm cache — Local cache management

Usage: pcm cache <subcommand> [args...]

Subcommands:
  list                          List cached SA tokens
  show [vault]                  Show cached SA token for a vault (default: workspace)
  clear [vault]                 Clear cached SA token
EOF
}

cmd_cache() {
  local subcmd="${1:-}"
  shift 2>/dev/null || true

  case "$subcmd" in
    list)  cmd_cache_list ;;
    show)  cmd_cache_show "$@" ;;
    clear) cmd_cache_clear "$@" ;;
    "")    cmd_cache_help ;;
    *)
      _error "Unknown cache subcommand: $subcmd"
      cmd_cache_help
      exit 1
      ;;
  esac
}
```

**`cmd_cache_list`**: Rename from `cmd_token_list`. No logic changes.
**`cmd_cache_show`**: Rename from `cmd_token_get`. No logic changes.
**`cmd_cache_clear`**: Rename from `cmd_token_clear`. No logic changes.

### 5. Remove dropped commands

Delete the following functions entirely:
- `cmd_get` and `cmd_get_help` — absorbed into `cmd_credential_get`
- `cmd_list` — removed (use `pcm vault list` or `pcm credential validate`)
- `cmd_new` and `cmd_new_help` — removed (use `pcm plugin add`)
- `cmd_init` and `cmd_init_help` — absorbed into `cmd_plugin_add`
- `cmd_validate` and `cmd_validate_help` — absorbed into `cmd_credential_validate`
- `cmd_token` and all `cmd_token_*` — replaced by `cmd_cache_*`
- `cmd_credentials` and all `cmd_credentials_*` — replaced by `cmd_credential_*`
- `cmd_plugins` and all `cmd_plugins_*` — replaced by `cmd_plugin_*`

### 6. Update dispatch table

```bash
case "$command" in
  credential)   cmd_credential "$@" ;;
  vault)        cmd_vault "$@" ;;
  plugin)       cmd_plugin "$@" ;;
  cache)        cmd_cache "$@" ;;
  config)       cmd_config ;;
  update)       cmd_update ;;
  help)         cmd_help ;;
  # Hidden commands (functional but not advertised)
  completions)  cmd_completions "$@" ;;
  remote-env)   cmd_remote_env ;;
  *)
    _error "Unknown command: $command"
    cmd_help
    exit 1
    ;;
esac
```

### 7. Update `cmd_help`

```bash
cmd_help() {
  cat <<'EOF'
pcm — Personal Credentials Manager

Usage: pcm [--debug] <command> [args...]

Credential operations (project-scoped):
  credential list                 List configured credentials
  credential show <name>          Show config details for a credential
  credential get <name>           Fetch field values from backend (export lines)
  credential get <name/field>     Fetch a single field value
  credential validate [--fix]     Check credentials exist, optionally provision

Vault operations (backend-scoped):
  vault list                      List vaults in the backend
  vault show <name>               Show vault details
  vault create <name>             Create vault + service account + store token

Plugin operations (registry-scoped):
  plugin list [--installed]       List available (or project-installed) plugins
  plugin show <name>              Show plugin details
  plugin add <name>               Apply a plugin to the current directory

Cache operations (local device):
  cache list                      List cached SA tokens
  cache show [vault]              Show cached SA token
  cache clear [vault]             Clear cached SA token

Meta:
  config                          Show effective configuration
  update                          Update pcm + plugin registry
  help                            Show this help

Configuration (merged in order, later wins):
  ~/.config/pcm/pcm.yml            Primary global config
  ~/.config/pcm/conf.d/*.yml       Optional global fragments
  .pcm.yml                         Project/space-local (walked up from $PWD)

Env var overrides:
  PCM_PROVIDER_WORKSPACE    Override workspace provider
  PCM_PROVIDER_USER         Override user provider
  PCM_PROVIDER_ACCOUNTS     Override accounts provider
  PCM_DEBUG                 Enable debug output

When settings.prefix is declared in .pcm.yml, credential commands
require the prefix env vars to be set (e.g. PCM_SITE).

Run 'pcm <command>' for subcommand help.
EOF
}
```

### 8. Update `cmd_config`

The config diagnostic currently shows providers under "Providers:" with
the `_show_role` helper. This is still correct — providers are displayed
in `pcm config`. No changes to config output needed.

However, rename the internal `_show_role` helper to `_show_provider` for
consistency:

```bash
_show_provider() {
  local label="$1" value="$2" env_var="$3"
  if [[ -n "$value" ]]; then
    printf "%-13s%s\n" "${label}:" "$value"
  else
    printf "%-13s(not set) export %s=<vault_name>\n" "${label}:" "$env_var"
  fi
}
```

Update all calls from `_show_role` to `_show_provider`.

### 9. Add `_pcm_list_vaults` to backend interface

In `lib/op.sh`, add:

```bash
_pcm_list_vaults() {
  op vault list --format json 2> >(_pcm_stderr)
}
```

Update the backend interface comment block at the top of `op.sh` to
include `_pcm_list_vaults`.

### 10. Update `pcm.zsh`

The shell wrapper may reference `command pcm` with old command names.
Check and update if needed. The `pcm ssh` function likely calls
`pcm remote-env` which still exists (hidden). No changes expected,
but verify.

### 11. Update shell completions (`lib/completions.zsh`)

Rewrite completions to match the new API:

- Top-level commands: `credential`, `vault`, `plugin`, `cache`, `config`,
  `update`, `help` (NOT completions, remote-env, get, list, new, init,
  validate, token, plugins, credentials)
- `credential` subcommands: `list`, `show`, `get`, `validate`
- `vault` subcommands: `list`, `show`, `create`
- `plugin` subcommands: `list`, `show`, `add`
- `cache` subcommands: `list`, `show`, `clear`

For `credential show/get`: complete with credential names from config.
For `plugin show/add`: complete with plugin names from registry.
For `vault show`: complete with known vault names.
For `cache show/clear`: complete with vault names.
For `plugin list`: complete `--installed` flag.
For `credential validate`: complete `--fix` and `-y` flags.

### 12. Update `.env.schema` template

In `~/spaces/rjayroach/technical/pcm-plugins/plugins/unifi/templates/.env.schema`,
update `pcm get` references to `pcm credential get`:

```
UNIFI_API_KEY=exec(`pcm credential get unifi/credential`)
UNIFI_API=exec(`pcm credential get unifi/hostname`)
TF_VAR_wifi_passphrase=exec(`pcm credential get wifi/password`)
```

Also update the live `.env.schema` at
`~/spaces/rjayroach/technical/infra/unifi/.env.schema`.

### 13. Clean up comments

Update the schema comment block at the top of the pcm script to reference
the new command names. Remove any references to old commands in inline
comments throughout the script.

## Test Spec

Manual verification:

```bash
# Credential operations
pcm credential list
pcm credential show gh
pcm credential show aws
PCM_SITE=singapore pcm credential get unifi
PCM_SITE=singapore pcm credential get unifi/credential
pcm credential validate
PCM_SITE=singapore pcm credential validate

# Vault operations
pcm vault list                    # should show vaults from 1Password
pcm vault show rjayroach          # should show vault details

# Plugin operations
pcm plugin list                   # should show registry plugins
pcm plugin list --installed       # should show project plugins (if in a project dir)
pcm plugin show unifi

# Cache operations
pcm cache list                    # should show cached tokens
pcm cache show                    # should show/cache workspace token

# Meta
pcm config                        # should show full config
pcm help                          # should show grouped commands

# Verify old commands are gone
pcm get aws 2>&1                  # should show "Unknown command: get"
pcm list 2>&1                     # should show "Unknown command: list"
pcm new unifi test 2>&1           # should show "Unknown command: new"
pcm init unifi 2>&1               # should show "Unknown command: init"
pcm validate 2>&1                 # should show "Unknown command: validate"
pcm token list 2>&1               # should show "Unknown command: token"

# Verify hidden commands still work
pcm completions zsh >/dev/null    # should succeed silently
pcm remote-env 2>/dev/null        # should work (may error on missing vault, that's ok)

# Tab completion
pcm <tab>                         # should show: credential vault plugin cache config update help
pcm credential <tab>              # should show: list show get validate
pcm plugin <tab>                  # should show: list show add
```

## Verification

- [ ] `pcm help` shows four grouped sections (credential, vault, plugin, cache)
- [ ] `pcm help` does NOT show: get, list, new, init, validate, token, completions, remote-env
- [ ] `pcm credential get gh` returns the token value
- [ ] `pcm credential list` shows configured credentials
- [ ] `pcm credential validate` works
- [ ] `pcm vault list` shows vaults from the backend
- [ ] `pcm plugin list` shows registry plugins
- [ ] `pcm plugin list --installed` shows project plugins
- [ ] `pcm plugin add` works (test in a temp directory)
- [ ] `pcm cache list` shows cached tokens
- [ ] `pcm cache show` shows/caches workspace token
- [ ] Old commands (`get`, `list`, `new`, `init`, `validate`, `token`) return "Unknown command"
- [ ] Hidden commands (`completions`, `remote-env`) still work
- [ ] Shell completions only show new command names
- [ ] `.env.schema` templates use `pcm credential get`
- [ ] No references to old command names in script comments
- [ ] `grep -n 'cmd_get\b' pcm` — only matches inside `cmd_credential_get` (no standalone)
- [ ] `grep -n 'cmd_list\b' pcm` — returns nothing
- [ ] `grep -n 'cmd_new\b' pcm` — returns nothing
- [ ] `grep -n 'cmd_init\b' pcm` — returns nothing (absorbed into cmd_plugin_add)
- [ ] `grep -n 'cmd_token' pcm` — returns nothing
- [ ] `grep -n 'cmd_credentials' pcm` — returns nothing (now cmd_credential)
- [ ] `grep -n 'cmd_plugins' pcm` — returns nothing (now cmd_plugin)
