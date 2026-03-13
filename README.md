# PCM — Personal Credentials Manager

PCM is a backend-agnostic credential manager for homelabs, small teams, and solo developers. It provides a single CLI for reading credentials from any password manager, with a flexible configuration system that adapts to your project structure.

PCM ships with a 1Password backend. Adding Bitwarden, KeePass, or any other backend is a matter of dropping a shell script into `lib/`.

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/rjayroach/pcm/main/install.sh | bash

# Read a credential from your workspace vault
pcm credential get unifi/credential

# Read all fields for a configured credential
eval $(pcm credential get aws)

# Show effective config for current directory
pcm config
```

## How It Works

PCM resolves credentials through three layers:

1. **Vaults** — where credentials are stored (1Password vaults, Bitwarden collections, etc.)
2. **Providers** — named references to vaults (`workspace`, `user`, `accounts`) that decouple your commands from specific vault names
3. **Credentials** — named mappings that connect environment variables to vault item fields

```
pcm credential get unifi/credential
                    │         │
                    │         └── field name in the vault item
                    └── item name (or credential name from config)

     ┌─────────────────────────────┐
     │  .pcm.yml (credentials)     │
     │  unifi → provider: workspace│
     │          fields:            │
     │            credential:      │
     │              env: UNIFI_..  │
     └──────────┬──────────────────┘
                │
     ┌──────────▼──────────────────┐
     │  providers                  │
     │  workspace → rjayroach      │
     └──────────┬──────────────────┘
                │
     ┌──────────▼──────────────────┐
     │  1Password (op backend)     │
     │  op://rjayroach/unifi/      │
     │         credential          │
     └─────────────────────────────┘
```

## Configuration

PCM uses a single YAML schema (`.pcm.yml` or `pcm.yml`) that can appear anywhere — global config, space root, project directory. All files are deep-merged in order, so you can split concerns across files and directories.

### Loading Order

Config is merged in this order (later wins for same keys):

1. **`~/.config/pcm/pcm.yml`** — primary global config
2. **`~/.config/pcm/conf.d/*.yml`** — optional global fragments, loaded alphabetically
3. **`.pcm.yml` / `pcm.yml` walked up from `$PWD`** — outermost directory first, innermost (closest to `$PWD`) last

Both `.pcm.yml` (hidden) and `pcm.yml` (visible) are supported in every directory, like mise. If both exist in the same directory, the hidden file takes precedence.

### Schema

Every config file uses the same format. Include only the keys you need:

```yaml
# Any .pcm.yml can contain any combination of these top-level keys

backend: op                      # default backend for all vaults

vaults:                          # vault registry
  my-vault:
  another-vault:
    backend: bw                  # per-vault backend override

providers:                       # named vault references
  workspace: my-vault            # the "current context" vault
  user: my-vault                 # identity-level credentials
  accounts: another-vault        # where SA tokens are stored

settings:
  prefix: ${PCM_SITE}            # item name prefix (env var template)
  separator: "-"                 # between prefix and item name (default: -)

credentials:
  gh:
    provider: user
    fields:
      token:
        env: GH_TOKEN
  aws:
    provider: workspace
    fields:
      access-key-id:
        env: AWS_ACCESS_KEY_ID
      secret-access-key:
        env: AWS_SECRET_ACCESS_KEY
```

### Typical Setup

The primary global config defines vaults, providers, and always-available credentials:

```
~/.config/pcm/
├── pcm.yml              # backend, vaults, providers, global credentials
└── conf.d/              # optional fragments (split by concern)
```

Project-local files add context-specific credentials and settings:

```
~/spaces/myorg/
├── .pcm.yml            # providers.workspace: myorg
└── infra/
    ├── .pcm.yml        # settings.prefix: ${PCM_SITE}
    └── unifi/
        └── .pcm.yml    # credentials.unifi, credentials.wifi
```

When you `cd` into `infra/unifi/`, PCM merges everything: vaults and providers from global, prefix from infra, credentials from unifi.

### Environment Variable Overrides

Providers can be overridden by environment variables, which take precedence over config files:

| Provider | Env var | Typical source |
|----------|---------|---------------|
| workspace | `PCM_PROVIDER_WORKSPACE` | mise (per-space `.mise.toml`) |
| user | `PCM_PROVIDER_USER` | global config |
| accounts | `PCM_PROVIDER_ACCOUNTS` | global config |

## Prefix System

PCM can prefix credential item names with a template string, enabling one set of credential definitions to work across multiple sites, environments, or tenants.

### How It Works

When `settings.prefix` is declared in any `.pcm.yml`:

```yaml
settings:
  prefix: ${PCM_SITE}
```

The credential name is prefixed when resolving items:

```
credential: unifi, field: credential
PCM_SITE=singapore
→ item name: singapore-unifi
→ op read op://vault/singapore-unifi/credential
```

### Rules

- **If prefix is declared**, all referenced env vars must be set. PCM hard-fails with a clear error if any variable is unset. This prevents silent misresolution.
- **If prefix is not declared**, item names are used as-is. Existing behavior is fully preserved.
- **Prefix applies in both modes**: `pcm credential get unifi/credential` (single field) and `pcm credential get unifi` (all fields).
- **Compound prefixes are supported**: `${PCM_ORG}-${PCM_SITE}-${PCM_ENV}` works — any number of variables can be composed.
- **Separator is configurable**: defaults to `-`. Set `settings.separator` to change it.

### Multi-Site Example

With infrastructure across three physical sites:

```
infra/.pcm.yml:
  settings:
    prefix: ${PCM_SITE}

infra/unifi/.pcm.yml:
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

1Password items in the workspace vault:

| Item | Category | Fields |
|------|----------|--------|
| singapore-unifi | API Credentials | credential, hostname |
| singapore-wifi | Password | password |
| rochester-unifi | API Credentials | credential, hostname |
| rochester-wifi | Password | password |

Usage:

```bash
PCM_SITE=singapore pcm credential get unifi/credential   # reads singapore-unifi/credential
PCM_SITE=rochester pcm credential get wifi/password       # reads rochester-wifi/password
```

### Scaling to Multiple WLANs

If a site has multiple WiFi networks, use credential names that include the SSID:

```yaml
credentials:
  wifi-iot:
    provider: workspace
    fields:
      password:
        env: TF_VAR_wifi_iot_passphrase
  wifi-guest:
    provider: workspace
    fields:
      password:
        env: TF_VAR_wifi_guest_passphrase
```

Items become `singapore-wifi-iot`, `singapore-wifi-guest`. No new features needed — the credential name is arbitrary.

## CLI Reference

### pcm credential

Credential operations (project-scoped).

```bash
# List configured credentials
pcm credential list

# Show config details for a credential
pcm credential show unifi

# Fetch a single field value
pcm credential get unifi/credential

# Fetch all fields for a credential (export lines)
pcm credential get gh
eval $(pcm credential get aws)

# Validate credentials exist in the backend
pcm credential validate
pcm credential validate --fix        # provision missing items
pcm credential validate --fix -y     # skip confirmation
```

### pcm vault

Vault operations (backend-scoped).

```bash
pcm vault list                    # list vaults from the backend (JSON)
pcm vault show rjayroach          # show details for a vault
pcm vault create my-vault         # create vault + service account + store token
```

### pcm plugin

Plugin operations (registry-scoped).

```bash
pcm plugin list                   # list available plugins in the registry
pcm plugin list --installed       # list plugins installed in current project
pcm plugin show unifi             # show plugin details
pcm plugin add unifi              # apply a plugin to the current directory
```

### pcm cache

SA token cache management (local device, macOS Keychain).

```bash
pcm cache list                    # list cached SA tokens
pcm cache show                    # show/cache SA token for workspace vault
pcm cache clear                   # clear cached token
```

### pcm config

Show the effective merged configuration for the current directory.

```bash
pcm config                        # shows sources, providers, prefix, credential count
```

### Other Commands

```bash
pcm ssh <host>                    # SSH with credential forwarding (via pcm.zsh)
pcm update                        # git pull the repo + plugin registry
pcm help                          # show help
```

All commands support `--debug` as the first argument for verbose output.

## Plugins

PCM plugins are installable workflow kits that bundle credential definitions, env schemas, and task automation for a specific tool or use case. Plugins live in a separate registry repo.

```bash
# Browse available plugins
pcm plugin list

# Show what a plugin provides
pcm plugin show unifi

# Apply a plugin to the current directory (composable)
cd existing-project
pcm plugin add aws
pcm plugin add unifi
```

`pcm plugin add` merges credential definitions into `.pcm.yml`, copies template files based on tool detection (varlock schemas if varlock is installed, mise tasks if mise is installed), and tracks which plugins have been applied.

Plugins are cached at `~/.cache/pcm/registry/` and refreshed by `pcm update`.

## Integration with Varlock

PCM pairs with [varlock](https://github.com/dmno-dev/varlock) for environment variable validation and injection. A `.env.schema` file declares required variables and resolves them via `exec()`:

```bash
# .env.schema
# @defaultRequired=true

# @type=string @required @sensitive=false
PCM_SITE=

# @type=string @sensitive
UNIFI_API_KEY=exec(`pcm credential get unifi/credential`)

# @type=url @sensitive=false
UNIFI_API=exec(`pcm credential get unifi/hostname`)
```

```bash
PCM_SITE=singapore varlock load     # validate all credentials resolve
PCM_SITE=singapore varlock run -- tofu plan  # inject and run
```

## Integration with Mise

PCM's workspace provider is typically set by [mise](https://mise.jdx.dev) based on directory context:

```toml
# ~/spaces/myorg/.mise.toml
[env]
PCM_PROVIDER_WORKSPACE = "myorg"
```

Mise tasks can pass site context to PCM via varlock:

```toml
[tasks.plan]
description = "Run tofu plan for a site"
usage = 'arg "<site>"'
run = """
PCM_SITE={{arg(name='site')}} varlock run -- tofu plan -var-file="envs/{{arg(name='site')}}.tfvars"
"""
```

```bash
mise run plan singapore     # sets PCM_SITE, varlock validates, tofu runs
```

## Backends

PCM delegates all credential operations to backend plugins. The main script has zero knowledge of 1Password, Bitwarden, or any specific tool.

### Adding a Backend

Create `lib/<name>.sh` implementing:

```bash
_pcm_read <vault> <ref>                          # read a secret value
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

Set the backend globally or per-vault:

```yaml
backend: op              # global default

vaults:
  my-bw-vault:
    backend: bw          # this vault uses Bitwarden
```

### 1Password Backend (op.sh)

The default backend. Requires `op` CLI v2.18.0+. Authenticates via the 1Password desktop app (local) or `OP_SERVICE_ACCOUNT_TOKEN` (remote/CI).

Ref format: `op://vault/item/field`

### 1Password Item Conventions

| Item type | Use case | Built-in fields |
|-----------|----------|----------------|
| API Credentials | Service accounts, API keys | `credential`, `hostname` |
| Password | WiFi passphrases, simple secrets | `password` |
| Login | Web service accounts | `username`, `password` |

Custom fields work with any item type. The `op read` ref is always `vault/item/field` regardless of category.

## Dependencies

- **`yq`** — YAML parser (required)
- **`jq`** — JSON parser (required for op backend output)
- **Backend CLI** — e.g. `op` for 1Password
- **`security`** — macOS Keychain (optional, for SA token caching)

## Design Principles

- **Backend-agnostic** — PCM delegates all operations to backend plugins. Adding a backend = dropping a shell script.
- **Config is optional** — env vars can drive everything. Config files provide defaults and structure.
- **Merge, don't mandate** — any `.pcm.yml` can contain any config key. Split by concern or combine — your choice.
- **Providers over vault names** — commands reference providers which resolve to vault names. Switch context by changing one env var.
- **Prefix for multi-tenancy** — one credential definition works across sites, environments, or tenants via templated prefixes.
- **Zero runtime dependencies** — beyond `yq`, `jq`, and your backend CLI. No gems, no npm, no containers.
