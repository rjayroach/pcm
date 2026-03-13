# PCM — Personal Credentials Manager

## Active Work

Current unit: **Cleanup** — `chorus/units/cleanup.md` — API restructuring

Plans are in `chorus/units/cleanup/*/plan.md` — execute sequentially.

Completed units:
- **Production** — Provider model refactoring (done)
- **Platform** — Validate, generate, provision (done)

## What This Is

A backend-agnostic credential manager implemented as a single bash script. PCM provides a unified interface for reading credentials from vaults, managing service account tokens, and forwarding credentials to remote hosts via SSH. The 1Password CLI (`op`) is the first backend; others (Bitwarden, etc.) can be added by dropping a shell script in `lib/`.

PCM has zero runtime dependencies beyond its backend CLI tool and `yq` for YAML parsing.

## Repository Layout

```
~/.local/share/pcm/           # git clone (the repo)
├── pcm                        # main script, symlinked to ~/.local/bin/pcm
├── pcm.zsh                    # shell wrapper for commands needing shell context (ssh)
├── install.sh                 # installer: clone repo, symlink binary, seed config
└── lib/
    ├── op.sh                  # 1Password backend plugin
    └── completions.zsh        # zsh tab completions
```

## Configuration

PCM uses a unified `.pcm.yml` schema. All config files share the same format and are merged in order (later wins):

1. `~/.config/pcm/pcm.yml` — primary global config
2. `~/.config/pcm/conf.d/*.yml` — optional global fragments (alphabetical)
3. `.pcm.yml` / `pcm.yml` files walking up from `$PWD` — outermost first, innermost last

Both `.pcm.yml` (hidden) and `pcm.yml` (visible) are supported in every directory. If both exist in the same directory, the hidden file takes precedence.

### Unified Schema

```yaml
# Any .pcm.yml can contain any combination of these keys

backend: op                      # default backend for all vaults

vaults:                          # vault registry
  my-vault:
  another-vault:
    backend: bw                  # per-vault backend override

providers:                       # named vault references
  workspace: my-vault            # current project context
  user: my-vault                 # personal/identity credentials
  accounts: another-vault        # where SA tokens are stored

settings:                        # credential resolution settings
  prefix: ${PCM_SITE}            # template string, env vars expanded
  separator: "-"                 # between prefix and credential name (default: -)

credentials:                     # credential definitions
  gh:
    provider: user
    fields:
      token:
        env: GH_TOKEN            # exported as env var
  unifi:
    provider: workspace
    fields:
      credential:
        env: UNIFI_API_KEY       # single env var
      hostname:
        env: UNIFI_API
  some-service:
    provider: workspace
    fields:
      api-key:
        env: [SVC_API_KEY, TF_VAR_svc_api_key]  # multiple env vars
      endpoint:                  # field with no env export

plugins:                         # tracks which plugins have been initialized
  - aws
  - unifi
```

### Field Schema

Fields are declared field-name-first. The field name corresponds to the field in the credential store (e.g., the 1Password item field). The optional `env` key declares how the field is exported:

- **String**: `env: GH_TOKEN` — exports as a single env var
- **Array**: `env: [VAR_A, VAR_B]` — exports the same value to multiple env vars
- **Omitted**: field exists but is not exported by `pcm credential get <credential>`; still readable via `pcm credential get <credential>/<field>`

### Config Files

```
~/.config/pcm/
├── pcm.yml                      # primary global config (backend, providers, credentials)
└── conf.d/                      # optional fragments (split by concern)

~/spaces/myproject/.pcm.yml      # project-local settings + credentials
```

### Prefix System

When `settings.prefix` is declared, credential item names are prefixed:

- `settings.prefix: ${PCM_SITE}` with `PCM_SITE=singapore` and `separator: "-"`
- Credential `unifi`, field `credential` → reads item `singapore-unifi`, field `credential`
- Full `op read` ref: `op://vault/singapore-unifi/credential`

If prefix is declared, all env vars in the template must be set or PCM hard-fails. If prefix is not declared, item names are used as-is.

Prefix applies in both modes:
- **Ref mode:** `pcm credential get unifi/credential` — if `unifi` is a configured credential, prefix is applied
- **Credential mode:** `pcm credential get unifi` — outputs export lines for fields with env mappings, with prefix

## Plugins

Plugins are installable workflow kits that provide credential definitions, env schemas, mise tasks, and project scaffolding. They live in a separate registry repo (`pcm-plugins`).

### Plugin Structure

```
plugins/
  gh/
    plugin.yml                   # manifest
    credentials/
      gh.yml                     # credential definition
  unifi/
    plugin.yml                   # manifest
    credentials/
      unifi.yml                  # credential definitions
      wifi.yml
    templates/
      .env.schema                # varlock schema (included if varlock detected)
      mise.toml                  # mise tasks (included if mise detected)
```

### Plugin Commands

```
pcm plugin list                  List plugins in the registry
pcm plugin list --installed      List plugins installed in current project
pcm plugin show <name>           Show plugin details
pcm plugin add <name>            Apply plugin to current directory (composable)
```

The registry is cached locally at `~/.cache/pcm/registry/` and refreshed by `pcm update`.

## Architecture

### Providers

PCM organizes vaults into three providers:

- **workspace** — the vault for the current context (changes as you move between projects/spaces)
- **user** — your personal vault (identity-level credentials like GitHub tokens)
- **accounts** — where SA tokens are stored (meta-credentials vault)

Providers are configured in `.pcm.yml` under `providers:` and overridden by env vars:

| Provider | YAML key | Env var override |
|----------|----------|-----------------|
| workspace | `providers.workspace` | `PCM_PROVIDER_WORKSPACE` |
| user | `providers.user` | `PCM_PROVIDER_USER` |
| accounts | `providers.accounts` | `PCM_PROVIDER_ACCOUNTS` |

Resolution order: env var → merged config → error.

### Backend System

Backends are shell scripts in `lib/` that implement a standard interface:

```bash
_pcm_read <vault> <ref>                          # read a secret
_pcm_list <vault>                                # list items (JSON)
_pcm_list_vaults                                 # list all vaults (JSON)
_pcm_vault_exists <name>                         # check if vault exists
_pcm_vault_info <name>                           # get vault details (JSON)
_pcm_create_vault <name>                         # create a vault
_pcm_create_sa <name> <vault> [permissions]      # create SA, return token
_pcm_create_item <vault> <title> <category> ...  # store a credential
_pcm_sa_token <vault> <credentials_vault>        # read SA token
_pcm_remote_env <vault> <credentials_vault>      # output env exports for SSH
```

The default backend is set via `backend:` (top-level key). Individual vaults can override the backend. Adding a backend = dropping a `lib/<name>.sh` file.

### Shell Wrapper (pcm.zsh)

The `pcm.zsh` file defines a shell function that wraps the `pcm` script. This is needed for `pcm ssh` which must run `ssh` in the current shell context. All other commands delegate to the script via `command pcm`.

## CLI Reference

```
pcm credential list                 List configured credentials
pcm credential show <name>          Show config details for a credential
pcm credential get <name>           Fetch field values (export lines)
pcm credential get <name/field>     Fetch a single field value
pcm credential validate [--fix]     Check credentials exist, optionally provision

pcm vault list                      List vaults in the backend
pcm vault show <name>               Show vault details
pcm vault create <name>             Create vault + SA + store token
  [--permissions PERMS]

pcm plugin list [--installed]       List available (or installed) plugins
pcm plugin show <name>              Show plugin details
pcm plugin add <name>               Apply a plugin to the current directory

pcm cache list                      List cached SA tokens
pcm cache show [vault]              Show cached SA token
pcm cache clear [vault]             Clear cached SA token

pcm config                          Show effective merged configuration
pcm update                          Update pcm + plugin registry
pcm help                            Show help

# Hidden (functional, not advertised)
pcm completions <shell>             Generate shell completions
pcm remote-env                      Env exports for SSH (used by pcm.zsh)
```

All commands support `--debug` as the first argument for verbose output.

## Installation

### Via the install script

```bash
curl -fsSL https://raw.githubusercontent.com/rjayroach/pcm/main/install.sh | bash
```

### Dependencies

- `yq` — YAML parser (required)
- `jq` — JSON parser (required for `op` backend output)
- Backend CLI tool (e.g. `op` for 1Password)
- `security` CLI — macOS Keychain (optional, for SA token caching)

## Naming Conventions

### 1Password items

- SA tokens: `{vault}-sa-token` in the accounts vault, field name `password`
- Service accounts: `{vault}-sa`
- Credentials: `{item}/{field}` (e.g. `github/token`, `unifi/credential`)
- With prefix: `{prefix}-{item}/{field}` (e.g. `singapore-unifi/credential`)

### Keychain entries

- SA token cache: `pcm-sa-token-{vault}` keyed by `$USER`

### Env vars

| Variable | Purpose |
|----------|---------|
| `PCM_PROVIDER_WORKSPACE` | Override workspace provider |
| `PCM_PROVIDER_USER` | Override user provider |
| `PCM_PROVIDER_ACCOUNTS` | Override accounts provider |
| `PCM_DEBUG` | Enable debug output |
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password SA token (on remote hosts) |
