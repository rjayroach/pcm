---
---

# Plan 04 — Prefix Guard

## Context — read these files first

- `CLAUDE.md` — project overview
- `pcm` — main script, specifically `_resolve_prefix` and the command dispatch
- `chorus/units/platform/02-validate-command/log.md` — validate changes
- `chorus/units/platform/03-generate-and-prompt/log.md` — fix mode changes

## Overview

Add a centralized prefix guard that validates prefix env vars are set
before any command that resolves credentials. Currently `_resolve_prefix`
already hard-fails when vars are unset, but the error message is opaque
and comes mid-operation. This plan makes the check explicit and early.

## Implementation

### 1. Add `_require_prefix` guard function

Insert in the helpers section of the pcm script:

```bash
# Check that all prefix env vars are set.
# Call this before any command that resolves credential item names.
# No-op if settings.prefix is not declared.
_require_prefix() {
  if [[ -z "$_PCM_SETTINGS_PREFIX" ]]; then
    return 0
  fi

  local var_names
  var_names=$(echo "$_PCM_SETTINGS_PREFIX" | grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' | sed 's/\${\(.*\)}/\1/' | sort -u)

  local missing=()
  while IFS= read -r var; do
    [[ -z "$var" ]] && continue
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done <<< "$var_names"

  if [[ ${#missing[@]} -gt 0 ]]; then
    _error "Prefix requires env vars that are not set:"
    for var in "${missing[@]}"; do
      _error "  ${var} (from settings.prefix: ${_PCM_SETTINGS_PREFIX})"
    done
    _error ""
    _error "Set them before running this command, e.g.:"
    _error "  ${missing[0]}=<value> pcm ${command:-validate}"
    exit 1
  fi
}
```

### 2. Call `_require_prefix` at command entry points

Add the guard call at the top of commands that resolve credentials:

- `cmd_get` — after parsing flags, before resolving refs
- `cmd_validate` — at the start, before iterating credentials
- `cmd_credentials_list` — before listing (it shows resolved item names)
- `cmd_credentials_show` — before showing

Do NOT add to:
- `cmd_plugins` — no credential resolution
- `cmd_vault` — operates on vaults, not credentials
- `cmd_config` — diagnostic, should work even without prefix set
  (it already handles this gracefully with "unresolvable")
- `cmd_token` — operates on SA tokens, not credential items
- `cmd_help` — no resolution
- `cmd_new` / `cmd_init` — creates config, doesn't resolve

### 3. Remove redundant check from `_resolve_prefix`

The existing `_resolve_prefix` function already checks for unset vars and
exits. With the guard in place, this check is redundant but harmless as a
safety net. Keep it, but update its error message to be consistent with
the guard's message format.

### 4. Update help text

Add a note to `cmd_help` about prefix env vars:

```
  When settings.prefix is declared in .pcm.yml, commands that resolve
  credentials require the prefix env vars to be set (e.g. PCM_SITE).
```

## Test Spec

Manual verification:

```bash
# In a project with prefix configured
cd ~/spaces/rjayroach/technical/infra/unifi

# Without prefix var — should get clean error
pcm validate
# Expected: "Prefix requires env vars that are not set: PCM_SITE"

pcm credentials list
# Expected: same error

pcm get unifi/credential
# Expected: same error

# With prefix var — should work
PCM_SITE=singapore pcm validate
PCM_SITE=singapore pcm credentials list
PCM_SITE=singapore pcm get unifi/credential

# In a project without prefix — should work without any env vars
cd /tmp
echo 'credentials:
  test:
    provider: workspace
    fields:
      token:
        env: TEST' > .pcm.yml
pcm credentials list
# Should work (no prefix configured)
rm .pcm.yml

# Config should work without prefix set
cd ~/spaces/rjayroach/technical/infra/unifi
pcm config
# Should show prefix as "(unresolvable)" but not error
```

## Verification

- [ ] `_require_prefix` function exists in pcm script
- [ ] `pcm validate` without prefix vars shows clean error
- [ ] `pcm get <ref>` without prefix vars shows clean error
- [ ] `pcm credentials list` without prefix vars shows clean error
- [ ] `pcm config` works without prefix vars (diagnostic, no guard)
- [ ] `pcm plugins available` works without prefix vars (no guard)
- [ ] With prefix vars set, all commands work normally
- [ ] In projects without `settings.prefix`, no guard triggers
