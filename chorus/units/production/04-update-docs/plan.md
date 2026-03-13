---
---

# Plan 04 — Update Docs

## Context — read these files first

- `CLAUDE.md` — current project documentation (will be rewritten)
- `README.md` — current user-facing documentation (will be updated)
- `chorus/units/production/01-provider-model/log.md` — Plan 01 changes
- `chorus/units/production/02-global-config/log.md` — Plan 02 changes
- `chorus/units/production/03-update-plugins/log.md` — Plan 03 changes

## Overview

Rewrite CLAUDE.md and update README.md to reflect the new provider model,
global config file, field schema, and plugin system. These are the
authoritative references for the project.

## Implementation

### 1. Rewrite CLAUDE.md

The entire CLAUDE.md needs to be updated. Key changes:

**Schema section:**
- `backend:` as top-level key (not under `defaults:`)
- `providers:` replaces `roles:` — three names: `workspace`, `user`, `accounts`
- Credential definitions use `provider:` not `vault:`
- Field schema is field-name-first with `env:` (string or array)
- Document `generate:` field attribute as future/planned
- `plugins:` list tracks initialized plugins

**Config files section:**
- `~/.config/pcm/pcm.yml` is primary global config
- `conf.d/` is optional for splitting
- Loading order: pcm.yml → conf.d → walked .pcm.yml files

**Architecture section:**
- "Vault Roles" → "Providers"
- Three providers: workspace, user, accounts
- Env var overrides: `PCM_PROVIDER_WORKSPACE`, `PCM_PROVIDER_USER`, `PCM_PROVIDER_ACCOUNTS`
- Table updated with new var names

**CLI Reference section:**
- `pcm get` flags: `-w`, `-u`, `-a` (not `-p`, `-c`)
- Add `pcm plugins available/show`
- Add `pcm init <plugin>`
- Add `pcm new <plugin> [name]`

**Env vars table:**
- `PCM_PROVIDER_WORKSPACE`, `PCM_PROVIDER_USER`, `PCM_PROVIDER_ACCOUNTS`

### 2. Update README.md

Key changes throughout README.md:

**Schema examples:**
- All `vault:` → `provider:` in credential definitions
- All `roles:` → `providers:` with renamed keys
- `defaults: backend:` → top-level `backend:`
- Add `~/.config/pcm/pcm.yml` to loading order
- Field schema examples already updated (done in prior refactoring)

**Flow diagram:**
- Update the ASCII art to show `provider: workspace` instead of `vault: workspace`

**Env var table:**
- Rename from `PCM_VAULT_ROLE_*` to `PCM_PROVIDER_*`

**CLI flags in get section:**
- `-p` → `-u` (user provider)
- `-c` → `-a` (accounts provider)

**Config loading order section:**
- Add `~/.config/pcm/pcm.yml` as step 0

**Multi-site example:**
- `vault:` → `provider:` in credential definitions

**Scaling example:**
- `vault:` → `provider:` in credential definitions

**Plugins section:**
- Already added in prior refactoring, should be correct

**Design Principles section:**
- Update "Vault roles over vault names" to "Providers over vault names"

### 3. Grep sweep

After making changes, verify no stale references remain:

```bash
grep -n 'vault:' CLAUDE.md    # should only appear in vaults: section context
grep -n 'roles' CLAUDE.md     # should not appear (except maybe in historical context)
grep -n 'VAULT_ROLE' CLAUDE.md # should not appear
grep -n '\-p ' README.md       # should not appear as a CLI flag
grep -n '\-c ' README.md       # should not appear as a CLI flag
grep -n 'VAULT_ROLE' README.md # should not appear
```

## Test Spec

Documentation review — no automated tests. Verify:

1. CLAUDE.md schema examples are internally consistent
2. README.md examples match actual config format
3. CLI flag documentation matches actual `pcm help` output
4. Env var names match actual script behavior

## Verification

- [ ] `grep -c 'VAULT_ROLE' CLAUDE.md` returns 0
- [ ] `grep -c 'VAULT_ROLE' README.md` returns 0
- [ ] `grep 'provider:' CLAUDE.md` shows credential definitions use `provider:`
- [ ] `grep 'providers:' CLAUDE.md` shows providers section
- [ ] README.md loading order lists `~/.config/pcm/pcm.yml` first
- [ ] README.md CLI reference shows `-u` and `-a` flags
