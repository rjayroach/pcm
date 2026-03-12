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

## User Config Files

```
~/.config/pcm/
├── vaults.yml                 # vault backends, roles, and registry
└── tools.yml                  # tool wrapper credential mappings
```

These are user-editable, not managed by pcm. The installer seeds `vaults.yml` on first install only.

## Architecture

### Vault Roles

PCM organizes vaults into three roles:

- **workspace** — the vault for the current context (changes as you move between projects/spaces)
- **personal** — your personal vault (identity-level credentials like GitHub tokens)
- **credentials** — where SA tokens are stored (meta-credentials vault)

Roles are configured in `vaults.yml` under `vault_roles:` and overridden by env vars:

| Role | YAML key | Env var override |
|------|----------|-----------------|
| workspace | `vault_roles.workspace` | `PCM_VAULT_ROLE_WORKSPACE` |
| personal | `vault_roles.personal` | `PCM_VAULT_ROLE_PERSONAL` |
| credentials | `vault_roles.credentials` | `PCM_VAULT_ROLE_CREDENTIALS` |

Resolution order: env var → `vault_roles:` in YAML → error.

The workspace role is typically set dynamically by mise based on directory context. The personal and credentials roles are typically static in `vaults.yml`.

### Backend System

Backends are shell scripts in `lib/` that implement a standard interface:

```bash
_pcm_read <vault> <ref>                          # read a secret
_pcm_list <vault>                                # list items (JSON)
_pcm_vault_exists <name>                         # check if vault exists
_pcm_vault_info <name>                           # get vault details (JSON)
_pcm_create_vault <name>                         # create a vault
_pcm_create_sa <name> <vault> [permissions]      # create SA, return token
_pcm_create_item <vault> <title> <category> ...  # store a credential
_pcm_sa_token <vault> <credentials_vault>        # read SA token
_pcm_remote_env <vault> <credentials_vault>      # output env exports for SSH
```

The default backend is set in `vaults.yml` under `defaults.vault_backend`. Individual vaults can override the backend:

```yaml
vaults:
  my-bw-vault:
    backend: bw
```

The backend is loaded on-demand when a vault is accessed. Adding a backend = dropping a `lib/<name>.sh` file.

### Shell Wrapper (pcm.zsh)

The `pcm.zsh` file defines a shell function that wraps the `pcm` script. This is needed for `pcm ssh` which must run `ssh` in the current shell context. All other commands delegate to the script via `command pcm`.

Sourced from zsh config (e.g. via a symlink in `~/.config/zsh/`).

### Tools Configuration

`~/.config/pcm/tools.yml` declares how CLI tools map to vault credentials:

```yaml
gh:
  vault: personal
  environment:
    GH_TOKEN: github/token
aws:
  vault: workspace
  environment:
    AWS_ACCESS_KEY_ID: aws/access-key-id
    AWS_SECRET_ACCESS_KEY: aws/secret-access-key
```

The `vault` field accepts role names (workspace, personal, credentials) or literal vault names. The `environment` section maps env var names to credential paths within the vault.

## CLI Reference

```
pcm get [flags] <ref> [VAR]       Read a credential
  -w                                from workspace vault (default)
  -p                                from personal vault
  -c                                from credentials vault
  --from <vault>                    from a named vault or role

pcm vault list                    Show configured vault roles
pcm vault show [name|role]        Show backend details for a vault
pcm vault create <name>           Create vault + SA + store token
  [--permissions PERMS]

pcm list                          List items in workspace vault (JSON)

pcm token [get]                   Get SA token (keychain cached)
pcm token clear [vault]           Clear cached SA token
pcm token list                    List cached SA tokens

pcm tools list                    List configured tool wrappers
pcm tools show <tool>             Show tool details

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

This clones the repo to `~/.local/share/pcm`, symlinks `~/.local/bin/pcm`, and seeds `~/.config/pcm/vaults.yml`.

### Via ppm

The ppm package (`pde-ppm/packages/pcm`) runs the install script and symlinks `pcm.zsh` into `~/.config/zsh/`.

### Dependencies

- `yq` — YAML parser (required)
- `jq` — JSON parser (required for `op` backend output)
- Backend CLI tool (e.g. `op` for 1Password)
- `security` CLI — macOS Keychain (optional, for SA token caching)

## Design Principles

- **Backend-agnostic** — PCM delegates all credential operations to backend plugins. The main script has zero knowledge of 1Password, Bitwarden, etc.
- **Config is optional** — env vars can drive everything. `vaults.yml` provides defaults; `tools.yml` is additive. PCM works with zero config files if all roles are set via env vars.
- **No custom YAML parsing** — uses `yq` for all YAML operations.
- **Vault roles, not vault names** — commands reference roles (workspace, personal, credentials) which resolve to vault names. This decouples the CLI from specific vault naming.
- **Debug with `--debug`** — all commands respect `PCM_DEBUG` for verbose output including backend stderr.

## Naming Conventions

### 1Password items

- SA tokens: `{vault}-sa-token` in the credentials vault, field name `password`
- Service accounts: `{vault}-sa`
- Credentials: `{service}/{field}` (e.g. `github/token`, `aws/access-key-id`)

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
