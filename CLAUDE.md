# PCM — Personal Credentials Manager

## What This Is

A backend-agnostic credential manager implemented as a single bash script. PCM provides a unified interface for reading credentials from vaults, managing service account tokens, and forwarding credentials to remote hosts via SSH. The 1Password CLI (`op`) is the first backend; others (Bitwarden, etc.) can be added by dropping a shell script in `lib/`.

PCM has zero runtime dependencies beyond its backend CLI tool and `yq` for YAML parsing.

## Repository Layout

```
~/.local/share/pcm/           # git clone (the repo)
├── pcm                        # main script, symlinked to ~/.local/bin/pcm
├── pcm.zsh                    # shell wrapper for commands needing shell context (ssh)
├── install.sh                 # installer: clone repo, symlink binary, seed config
├── vaults.yml                 # default vaults config (shipped with repo)
├── config                     # legacy reference file (not used at runtime)
└── lib/
    └── op.sh                  # 1Password backend plugin
```

## Configuration

PCM uses a unified `.pcm.yml` schema. All config files share the same format and are merged in order (later wins):

1. `~/.config/pcm/conf.d/*.yml` — global fragments (alphabetical)
2. `.pcm.yml` / `pcm.yml` files walking up from `$PWD` — outermost first, innermost last

Both `.pcm.yml` (hidden) and `pcm.yml` (visible) are supported in every directory. If both exist in the same directory, the hidden file takes precedence.

Legacy files (`~/.config/pcm/vaults.yml`, `~/.config/pcm/tools.yml`) are supported and auto-transformed during loading, but conf.d takes precedence when present.

### Unified Schema

```yaml
# Any .pcm.yml can contain any combination of these keys

defaults:
  backend: op                    # default backend for all vaults

vaults:                          # vault registry
  my-vault:
  another-vault:
    backend: bw                  # per-vault backend override

roles:                           # vault role assignments
  workspace: my-vault
  personal: my-vault
  credentials: another-vault

settings:                        # credential resolution settings
  prefix: ${PCM_SITE}            # template string, env vars expanded
  separator: "-"                 # between prefix and credential name (default: -)

credentials:                     # credential mappings
  gh:
    vault: personal
    fields:
      GH_TOKEN: token
  unifi:
    vault: workspace
    fields:
      UNIFI_API_KEY: credential
      UNIFI_API: hostname
```

### Config Files

```
~/.config/pcm/conf.d/           # global config fragments
├── vaults.yml                   # vault registry, roles, backend defaults
├── gh.yml                       # github credential mapping
└── aws.yml                      # aws credential mapping

~/spaces/myproject/.pcm.yml      # project-local settings + credentials
```

### Prefix System

When `settings.prefix` is declared, credential item names are prefixed:

- `settings.prefix: ${PCM_SITE}` with `PCM_SITE=singapore` and `separator: "-"`
- Credential `unifi`, field `credential` → reads item `singapore-unifi`, field `credential`
- Full `op read` ref: `op://vault/singapore-unifi/credential`

If prefix is declared, all env vars in the template must be set or PCM hard-fails. If prefix is not declared, item names are used as-is (backward compatible).

Prefix applies in both modes:
- **Ref mode:** `pcm get unifi/credential` — if `unifi` is a configured credential, prefix is applied
- **Credential mode:** `pcm get unifi` — outputs export lines for all fields, with prefix

## Architecture

### Vault Roles

PCM organizes vaults into three roles:

- **workspace** — the vault for the current context (changes as you move between projects/spaces)
- **personal** — your personal vault (identity-level credentials like GitHub tokens)
- **credentials** — where SA tokens are stored (meta-credentials vault)

Roles are configured in `.pcm.yml` under `roles:` and overridden by env vars:

| Role | YAML key | Env var override |
|------|----------|-----------------|
| workspace | `roles.workspace` | `PCM_VAULT_ROLE_WORKSPACE` |
| personal | `roles.personal` | `PCM_VAULT_ROLE_PERSONAL` |
| credentials | `roles.credentials` | `PCM_VAULT_ROLE_CREDENTIALS` |

Resolution order: env var → merged config → error.

### Backend System

Backends are shell scripts in `lib/` that implement a standard interface:

```bash
_pcm_read <vault> <ref>                          # read a secret
_pcm_list <vault>                                # list items (JSON)
_pcm_vault_exists <n>                         # check if vault exists
_pcm_vault_info <n>                           # get vault details (JSON)
_pcm_create_vault <n>                         # create a vault
_pcm_create_sa <n> <vault> [permissions]      # create SA, return token
_pcm_create_item <vault> <title> <category> ...  # store a credential
_pcm_sa_token <vault> <credentials_vault>        # read SA token
_pcm_remote_env <vault> <credentials_vault>      # output env exports for SSH
```

The default backend is set under `defaults.backend`. Individual vaults can override the backend. Adding a backend = dropping a `lib/<n>.sh` file.

### Shell Wrapper (pcm.zsh)

The `pcm.zsh` file defines a shell function that wraps the `pcm` script. This is needed for `pcm ssh` which must run `ssh` in the current shell context. All other commands delegate to the script via `command pcm`.

## CLI Reference

```
pcm get [flags] <ref> [VAR]       Read a single field (ref = item/field)
pcm get <credential>              Read all fields for a credential (export lines)
  -w                                from workspace vault (default)
  -p                                from personal vault
  -c                                from credentials vault
  --from <vault>                    from a named vault or role

pcm vault list                    Show configured vault roles
pcm vault show [name|role]        Show backend details for a vault
pcm vault create <n>           Create vault + SA + store token
  [--permissions PERMS]

pcm credentials list              List configured credentials and field mappings
pcm credentials show <n>       Show details for a specific credential

pcm config                        Show effective merged configuration

pcm list                          List items in workspace vault (JSON)

pcm token [get]                   Get SA token (keychain cached)
pcm token clear [vault]           Clear cached SA token
pcm token list                    List cached SA tokens

pcm ssh <host> [ssh-args...]      SSH with credential forwarding (via pcm.zsh)
pcm remote-env                    Output backend env exports for remote hosts

pcm update                        Git pull the repo
pcm help                          Show help
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

- SA tokens: `{vault}-sa-token` in the credentials vault, field name `password`
- Service accounts: `{vault}-sa`
- Credentials: `{item}/{field}` (e.g. `github/token`, `unifi/credential`)
- With prefix: `{prefix}-{item}/{field}` (e.g. `singapore-unifi/credential`)

### Keychain entries

- SA token cache: `pcm-sa-token-{vault}` keyed by `$USER`

### Env vars

| Variable | Purpose |
|----------|---------|
| `PCM_VAULT_ROLE_WORKSPACE` | Override workspace vault role |
| `PCM_VAULT_ROLE_PERSONAL` | Override personal vault role |
| `PCM_VAULT_ROLE_CREDENTIALS` | Override credentials vault role |
| `PCM_DEBUG` | Enable debug output |
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password SA token (on remote hosts) |
