---
---

# Plan 02 — Global Config File

## Context — read these files first

- `CLAUDE.md` — project overview
- `pcm` — main script, specifically the `_build_config` function
- `~/.config/pcm/conf.d/vaults.yml` — current global vault config
- `chorus/units/production/01-provider-model/log.md` — what Plan 01 changed

## Overview

Add support for `~/.config/pcm/pcm.yml` as the primary global config file,
loaded before `conf.d/` fragments. Then consolidate the existing `conf.d/`
files into a single `pcm.yml` and remove the individual fragments.

## Implementation

### 1. Update `_build_config` in the pcm script

Add a new phase before the conf.d loading. The new loading order is:

1. `~/.config/pcm/pcm.yml` — primary global config (NEW)
2. `~/.config/pcm/conf.d/*.yml` — optional global fragments (alphabetical)
3. `.pcm.yml` / `pcm.yml` walked up from `$PWD` — project/space-local

Insert this block before the `# --- Phase 1: Load global conf.d fragments ---` comment:

```bash
# --- Phase 0: Load primary global config ---
local global_config="${HOME}/.config/pcm/pcm.yml"
if [[ -f "$global_config" ]]; then
  _debug "Loading global config: $global_config"
  yq -i '. *d load("'"$global_config"'")' "$tmpfile" 2>/dev/null || true
fi
```

### 2. Update `cmd_config` to show the new source

In the "Sources (merge order):" output, add the global config file before conf.d:

```bash
# Show primary global config
local global_config="${HOME}/.config/pcm/pcm.yml"
[[ -f "$global_config" ]] && echo "  $global_config"

# Show global conf.d
if [[ -d "$PCM_CONF_DIR" ]]; then
  ...
```

### 3. Create `~/.config/pcm/pcm.yml`

Consolidate everything from `conf.d/vaults.yml`, `conf.d/gh.yml`, and
`conf.d/aws.yml` into a single file:

```yaml
# PCM global configuration

backend: op

vaults:
  rjayroach:
  Private:
  lgat:

providers:
  user: rjayroach
  accounts: Private

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

### 4. Remove conf.d files

Delete:
- `~/.config/pcm/conf.d/vaults.yml`
- `~/.config/pcm/conf.d/gh.yml`
- `~/.config/pcm/conf.d/aws.yml`

Note: Do NOT remove the `conf.d/` directory itself — it's still supported
for users who prefer to split their config.

### 5. Update the schema comment in the pcm script

Update the loading order comment at the top of the config loading section to
include `~/.config/pcm/pcm.yml` as the first source:

```
# Files are merged in order (later wins):
#   0. ~/.config/pcm/pcm.yml (primary global config)
#   1. ~/.config/pcm/conf.d/*.yml (alphabetical)
#   2. .pcm.yml files walking up from $PWD (outermost first, innermost last)
```

### 6. Update install.sh

The install script should create `~/.config/pcm/pcm.yml` with a starter template:

```yaml
# PCM global configuration
# See: pcm help

backend: op

providers:
  workspace:
  user:
  accounts:
```

Replace the `mkdir -p "$PCM_CONF_D"` / `echo "Config directory: $PCM_CONF_D"`
with logic that creates `pcm.yml` if it doesn't exist:

```bash
# Create global config
mkdir -p "$PCM_CONFIG_DIR"
local global_config="${PCM_CONFIG_DIR}/pcm.yml"
if [[ ! -f "$global_config" ]]; then
  cat > "$global_config" << 'YAML'
# PCM global configuration
# See: pcm help

backend: op

providers:
  workspace:
  user:
  accounts:
YAML
  echo "Created $global_config"
else
  echo "Global config already exists at $global_config — skipping"
fi
```

## Test Spec

Manual verification:

```bash
# Verify loading order
pcm --debug config 2>&1 | head -20
# Should show: Loading global config: ~/.config/pcm/pcm.yml

# Verify merged config
pcm config
# Sources should list ~/.config/pcm/pcm.yml first
# Providers should resolve correctly
# Credentials gh and aws should appear

# Verify conf.d still works (create a test file)
echo 'credentials:
  test:
    provider: workspace
    fields:
      token:
        env: TEST_TOKEN' > ~/.config/pcm/conf.d/test.yml
pcm credentials list
# Should show test credential
rm ~/.config/pcm/conf.d/test.yml
```

## Verification

- [ ] `~/.config/pcm/pcm.yml` exists with backend, providers, and credentials
- [ ] `~/.config/pcm/conf.d/` directory is empty (or absent)
- [ ] `pcm config` lists `~/.config/pcm/pcm.yml` as first source
- [ ] `pcm credentials list` shows gh and aws
- [ ] `pcm vault list` shows correct provider-to-vault mappings
- [ ] Debug output shows correct loading order
