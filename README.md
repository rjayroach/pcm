# PCM — Personal Credentials Manager

PCM is a backend-agnostic credential manager for homelabs, small teams, and solo developers. It provides a single CLI for reading credentials from any password manager, with a flexible configuration system that adapts to your project structure.

PCM ships with a 1Password backend. Adding Bitwarden, KeePass, or any other backend is a matter of dropping a shell script into `lib/`.

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/rjayroach/pcm/main/install.sh | bash

# Read a credential from your workspace vault
pcm get unifi/credential

# Read all fields for a configured credential
eval $(pcm get aws)

# Show effective config for current directory
pcm config
```

## How It Works

PCM resolves credentials through three layers:

1. **Vaults** — where credentials are stored (1Password vaults, Bitwarden collections, etc.)
2. **Roles** — named references to vaults (`workspace`, `personal`, `credentials`) that decouple your commands from specific vault names
3. **Credentials** — named mappings that connect environment variables to vault item fields

```
pcm get unifi/credential
     │         │
     │         └── field name in the vault item
     └── item name (or credential name from config)

     ┌─────────────────────────────┐
     │  .pcm.yml (credentials)     │
     │  unifi → vault: workspace   │
     │          fields:            │
     │            UNIFI_API_KEY:   │
     │              credential     │
     └──────────┬──────────────────┘
                │
     ┌──────────▼──────────────────┐
     │  roles                      │
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

1. **`~/.config/pcm/conf.d/*.yml`** — global fragments, loaded alphabetically
2. **`.pcm.yml` / `pcm.yml` walked up from `$PWD`** — outermost directory first, innermost (closest to `$PWD`) last

Both `.pcm.yml` (hidden) and `pcm.yml` (visible) are supported in every directory, like mise. If both exist in the same directory, the hidden file takes precedence.

### Schema

Every config file uses the same format. Include only the keys you need:

```yaml
# Any .pcm.yml can contain any combination of these top-level keys

defaults:
  backend: op                    # default backend for all vaults

vaults:                          # vault registry
  my-vault:
  another-vault:
    backend: bw                  # per-vault backend override

roles:                           # named vault references
  workspace: my-vault            # the "current context" vault
  personal: my-vault             # identity-level credentials
  credentials: another-vault     # where SA tokens are stored

settings:
  prefix: ${PCM_SITE}            # item name prefix (env var template)
  separator: "-"                 # between prefix and item name (default: -)

credentials:
  gh:
    vault: personal
    fields:
      GH_TOKEN: token
  aws:
    vault: workspace
    fields:
      AWS_ACCESS_KEY_ID: access-key-id
      AWS_SECRET_ACCESS_KEY: secret-access-key
```

### Typical Setup

Global fragments define vaults, roles, and always-available credentials:

```
~/.config/pcm/conf.d/
├── vaults.yml          # vault registry + roles + backend
├── gh.yml              # credentials.gh (vault: personal)
└── aws.yml             # credentials.aws (vault: workspace)
```

Project-local files add context-specific credentials and settings:

```
~/spaces/myorg/
├── .pcm.yml            # roles.workspace: myorg
└── infra/
    ├── .pcm.yml        # settings.prefix: ${PCM_SITE}
    └── unifi/
        └── .pcm.yml    # credentials.unifi, credentials.wifi
```

When you `cd` into `infra/unifi/`, PCM merges everything: vaults and roles from global, prefix from infra, credentials from unifi.

### Environment Variable Overrides

Vault roles can be overridden by environment variables, which take precedence over config files:

| Role | Env var | Typical source |
|------|---------|---------------|
| workspace | `PCM_VAULT_ROLE_WORKSPACE` | mise (per-space `.mise.toml`) |
| personal | `PCM_VAULT_ROLE_PERSONAL` | global config |
| credentials | `PCM_VAULT_ROLE_CREDENTIALS` | global config |

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
- **Prefix applies in both modes**: `pcm get unifi/credential` (single field) and `pcm get unifi` (all fields).
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
      vault: workspace
      fields:
        UNIFI_API_KEY: credential
        UNIFI_API: hostname
    wifi:
      vault: workspace
      fields:
        TF_VAR_wifi_passphrase: password
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
PCM_SITE=singapore pcm get unifi/credential   # reads singapore-unifi/credential
PCM_SITE=rochester pcm get wifi/password       # reads rochester-wifi/password
```

### Scaling to Multiple WLANs

If a site has multiple WiFi networks, use credential names that include the SSID:

```yaml
credentials:
  wifi-iot:
    vault: workspace
    fields:
      TF_VAR_wifi_iot_passphrase: password
  wifi-guest:
    vault: workspace
    fields:
      TF_VAR_wifi_guest_passphrase: password
```

Items become `singapore-wifi-iot`, `singapore-wifi-guest`. No new features needed — the credential name is arbitrary.

## CLI Reference

### pcm get

Read credentials from a vault.

```bash
# Single field (ref mode)
pcm get unifi/credential              # from workspace vault
pcm get -p github/token               # from personal vault
pcm get --from my-vault db/password   # from a named vault

# Single field with export
pcm get -p github/token GH_TOKEN      # outputs: export GH_TOKEN='...'

# All fields for a credential (credential mode)
pcm get gh                            # outputs export lines for all fields
eval $(pcm get aws)                   # load into shell
```

If the item name in a ref matches a configured credential, the prefix and vault from config are applied automatically. Unknown refs pass through as-is.

**Vault flags** (ref mode only — credential mode uses the configured vault):

| Flag | Vault |
|------|-------|
| `-w` (default) | workspace |
| `-p` | personal |
| `-c` | credentials |
| `--from <name>` | named vault or role |

### pcm credentials

Inspect credential configuration.

```bash
pcm credentials list              # list all configured credentials
pcm credentials show unifi        # show details for a credential
```

### pcm vault

Manage vaults.

```bash
pcm vault list                    # show vault roles
pcm vault show workspace          # show details for a vault
pcm vault create my-vault         # create vault + service account + store token
```

### pcm config

Show the effective merged configuration for the current directory.

```bash
pcm config                        # shows sources, roles, prefix, credential count
```

### pcm token

Manage service account tokens (macOS Keychain cached).

```bash
pcm token                         # get SA token for workspace vault
pcm token clear                   # clear cached token
pcm token list                    # list cached tokens
```

### Other Commands

```bash
pcm list                          # list items in workspace vault (JSON)
pcm remote-env                    # output env exports for remote SSH hosts
pcm ssh <host>                    # SSH with credential forwarding (via pcm.zsh)
pcm update                        # git pull the repo
pcm help                          # show help
```

All commands support `--debug` as the first argument for verbose output.

## Integration with Varlock

PCM pairs with [varlock](https://github.com/dmno-dev/varlock) for environment variable validation and injection. A `.env.schema` file declares required variables and resolves them via `exec()`:

```bash
# .env.schema
# @defaultRequired=true

# @type=string @required @sensitive=false
PCM_SITE=

# @type=string @sensitive
UNIFI_API_KEY=exec(`pcm get unifi/credential`)

# @type=url @sensitive=false
UNIFI_API=exec(`pcm get unifi/hostname`)
```

```bash
PCM_SITE=singapore varlock load     # validate all credentials resolve
PCM_SITE=singapore varlock run -- tofu plan  # inject and run
```

## Integration with Mise

PCM's workspace role is typically set by [mise](https://mise.jdx.dev) based on directory context:

```toml
# ~/spaces/myorg/.mise.toml
[env]
PCM_VAULT_ROLE_WORKSPACE = "myorg"
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
defaults:
  backend: op          # global default

vaults:
  my-bw-vault:
    backend: bw        # this vault uses Bitwarden
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
- **Vault roles over vault names** — commands reference roles which resolve to names. Switch context by changing one env var.
- **Prefix for multi-tenancy** — one credential definition works across sites, environments, or tenants via templated prefixes.
- **Zero runtime dependencies** — beyond `yq`, `jq`, and your backend CLI. No gems, no npm, no containers.
