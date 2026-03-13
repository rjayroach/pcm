---
---

# Plan 02 — Update Docs

## Context — read these files first

- `CLAUDE.md` — current project docs (rewrite needed)
- `README.md` — current user docs (update needed)
- `chorus/units/cleanup/01-api-restructure/log.md` — what Plan 01 changed

## Overview

Rewrite CLAUDE.md and README.md to reflect the final API. This is the
authoritative documentation for the project — every command, every example,
every schema snippet must match the implemented behavior.

## Implementation

### 1. Rewrite CLAUDE.md

Key changes:

**Active Work section**: Remove or update — cleanup unit is the current work.

**CLI Reference section**: Replace entirely with the new API:

```
pcm credential list                 List configured credentials
pcm credential show <n>          Show config details for a credential
pcm credential get <n>           Fetch field values (export lines)
pcm credential get <name/field>     Fetch a single field value
pcm credential validate [--fix]     Check credentials exist, optionally provision

pcm vault list                      List vaults in the backend
pcm vault show <n>               Show vault details
pcm vault create <n>             Create vault + SA + store token

pcm plugin list [--installed]       List available (or installed) plugins
pcm plugin show <n>              Show plugin details
pcm plugin add <n>               Apply a plugin to the current directory

pcm cache list                      List cached SA tokens
pcm cache show [vault]              Show cached SA token
pcm cache clear [vault]             Clear cached SA token

pcm config                          Show effective configuration
pcm update                          Update pcm + plugin registry
pcm help                            Show help

# Hidden (functional, not advertised)
pcm completions <shell>             Generate shell completions
pcm remote-env                      Env exports for SSH (used by pcm.zsh)
```

**Schema examples**: Ensure all examples use `provider:` (not `vault:`),
field-first schema with `env:`, and the `type:` / `generate:` attributes
where relevant.

**Plugin section**: Update to show `pcm plugin add` not `pcm init`.

**Any pcm get references**: Change to `pcm credential get`.

### 2. Update README.md

Key changes:

**Quick Start section**: Update commands:

```bash
# Read a credential
pcm credential get unifi/credential

# Read all fields for a configured credential
eval $(pcm credential get aws)

# Show effective config
pcm config
```

**CLI Reference section**: Replace with new grouped API. Remove all
references to top-level `get`, `list`, `new`, `init`, `validate`, `token`.

**Flow diagram**: If present, update command references.

**Varlock integration section**: Update `.env.schema` examples to use
`pcm credential get`:

```
UNIFI_API_KEY=exec(`pcm credential get unifi/credential`)
```

**Mise integration section**: No command references to update (mise tasks
use varlock, not pcm directly). But verify.

**Plugin section**: Update to show `pcm plugin add`, `pcm plugin list`,
`pcm plugin show` instead of `pcm init`, `pcm plugins available`, etc.

**Design Principles section**: No changes needed unless it references
specific commands.

### 3. Grep sweep

After making changes, verify no stale command references remain:

```bash
# Old top-level commands
grep -n 'pcm get ' CLAUDE.md README.md          # should not appear (use pcm credential get)
grep -n 'pcm list' CLAUDE.md README.md           # should not appear (use pcm vault list)
grep -n 'pcm new ' CLAUDE.md README.md           # should not appear
grep -n 'pcm init ' CLAUDE.md README.md          # should not appear (use pcm plugin add)
grep -n 'pcm validate' CLAUDE.md README.md       # should not appear (use pcm credential validate)
grep -n 'pcm token' CLAUDE.md README.md          # should not appear (use pcm cache)

# Old plural forms
grep -n 'pcm credentials' CLAUDE.md README.md    # should not appear (use pcm credential)
grep -n 'pcm plugins' CLAUDE.md README.md        # should not appear (use pcm plugin)

# .env.schema references
grep -rn 'pcm get' ~/spaces/rjayroach/technical/pcm-plugins/    # should not appear
grep -rn 'pcm get' ~/spaces/rjayroach/technical/infra/unifi/    # should not appear
```

## Test Spec

Documentation review — verify:

1. Every command in `pcm help` output has a corresponding section in README.md
2. Every example in CLAUDE.md uses correct command syntax
3. Every `.env.schema` in the plugins repo uses `pcm credential get`
4. No references to dropped or renamed commands anywhere in docs

## Verification

- [ ] `grep -c 'pcm get ' CLAUDE.md` returns 0
- [ ] `grep -c 'pcm get ' README.md` returns 0
- [ ] `grep -c 'pcm credentials' CLAUDE.md` returns 0
- [ ] `grep -c 'pcm credentials' README.md` returns 0
- [ ] `grep -c 'pcm plugins' CLAUDE.md` returns 0
- [ ] `grep -c 'pcm plugins' README.md` returns 0
- [ ] `grep -c 'pcm token' CLAUDE.md` returns 0
- [ ] `grep -c 'pcm token' README.md` returns 0
- [ ] `grep -c 'pcm init ' CLAUDE.md` returns 0
- [ ] `grep -c 'pcm init ' README.md` returns 0
- [ ] `grep -c 'pcm new ' CLAUDE.md` returns 0
- [ ] `grep -c 'pcm new ' README.md` returns 0
- [ ] `grep -c 'pcm validate' CLAUDE.md` returns 0 (should be pcm credential validate)
- [ ] `grep -rn 'pcm get' ~/spaces/rjayroach/technical/pcm-plugins/` returns 0
- [ ] CLAUDE.md CLI reference matches `pcm help` output exactly
- [ ] README.md Quick Start examples work when copy-pasted
