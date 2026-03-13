---
---

# Plan 01 — Backend Write Interface

## Context — read these files first

- `CLAUDE.md` — project overview
- `pcm` — main script, specifically the backend loading section
- `lib/op.sh` — current 1Password backend implementation
- `chorus/units/production/01-provider-model/log.md` — provider model changes (if complete)

## Overview

Extend the backend interface with the functions needed for `pcm validate`:
item existence checking, and item creation with generic type-to-category
mapping. Also define the backend-agnostic type system.

This plan only changes `lib/op.sh` and adds the type mapping. The `pcm`
script itself is not modified — that's Plan 02.

## Implementation

### 1. Define generic types

PCM defines these backend-agnostic credential types. This is documented
in a comment block at the top of `lib/op.sh` (and any future backend):

| PCM type | Description | 1Password category |
|----------|-------------|-------------------|
| `secret` | Single secret value (password, token, passphrase) | `password` |
| `api` | API credentials (key + endpoint/hostname) | `api_credential` |
| `login` | Username + password pair | `login` |
| `note` | Freeform secure text | `secure_note` |

Start with `secret` and `api` — these cover the WiFi and UniFi use cases.
`login` and `note` are defined but not exercised until needed.

### 2. Add `_pcm_type_to_category` function in `op.sh`

```bash
# Map PCM generic types to 1Password categories
_pcm_type_to_category() {
  local pcm_type="$1"
  case "$pcm_type" in
    secret)  echo "password" ;;
    api)     echo "api_credential" ;;
    login)   echo "login" ;;
    note)    echo "secure_note" ;;
    *)
      _error "Unknown credential type: ${pcm_type}"
      _error "Valid types: secret, api, login, note"
      return 1
      ;;
  esac
}
```

### 3. Add `_pcm_item_exists` function in `op.sh`

Check if a specific item exists in a vault. Returns 0 if exists, 1 if not.
Does NOT error on missing items — this is a query, not a requirement.

```bash
_pcm_item_exists() {
  local vault="$1" item="$2"
  op item get "$item" --vault "$vault" --format json >/dev/null 2>&1
}
```

### 4. Add `_pcm_field_exists` function in `op.sh`

Check if a specific field exists on an existing item. This is used by
`pcm validate` to report partial items. Returns 0 if exists, 1 if not.

```bash
_pcm_field_exists() {
  local vault="$1" item="$2" field="$3"
  local value
  value=$(op read "op://${vault}/${item}/${field}" 2>/dev/null) || return 1
  [[ -n "$value" ]]
}
```

### 5. Update `_pcm_create_item` to accept generic types

The current signature is:

```bash
_pcm_create_item <vault> <title> <category> field=value...
```

Change to accept PCM generic type and do the mapping:

```bash
_pcm_create_item() {
  local vault="$1" title="$2" pcm_type="$3"
  shift 3

  local category
  category=$(_pcm_type_to_category "$pcm_type") || return 1

  _debug "Creating item: ${title} (type: ${pcm_type} -> category: ${category}) in vault ${vault}"
  op item create --vault="$vault" --title="$title" --category="$category" "$@" 2> >(_pcm_stderr)
}
```

Note: this is a breaking change to the internal interface. The only caller
of `_pcm_create_item` is `cmd_vault_create` which creates SA token items.
Update that call to use the `secret` type:

In the `cmd_vault_create` function, change:

```bash
_pcm_create_item "$PCM_PROVIDER_ACCOUNTS" "${name}-sa-token" "password" \
  "password=${token}"
```

to:

```bash
_pcm_create_item "$PCM_PROVIDER_ACCOUNTS" "${name}-sa-token" "secret" \
  "password=${token}"
```

(Note: env var name depends on whether production Plan 01 has been completed.
Use whichever variable name is current — `PCM_VAULT_ROLE_CREDENTIALS` or
`PCM_PROVIDER_ACCOUNTS`.)

### 6. Document the backend interface

Add a comment block at the top of `op.sh` listing the full interface with
the new functions:

```bash
# Backend interface:
#   _pcm_read <vault> <ref>                          Read a secret
#   _pcm_list <vault>                                List items (JSON)
#   _pcm_item_exists <vault> <item>                  Check if item exists
#   _pcm_field_exists <vault> <item> <field>         Check if field exists
#   _pcm_vault_exists <name>                         Check if vault exists
#   _pcm_vault_info <name>                           Get vault details (JSON)
#   _pcm_create_vault <name>                         Create a vault
#   _pcm_create_sa <name> <vault> [permissions]      Create SA, return token
#   _pcm_create_item <vault> <title> <type> ...      Create item (type-mapped)
#   _pcm_sa_token <vault> <creds_vault>              Read SA token
#   _pcm_remote_env <vault> <creds_vault>            Output env exports for SSH
#   _pcm_type_to_category <pcm_type>                 Map generic type to native
```

## Test Spec

Manual verification (requires 1Password CLI and a test vault):

```bash
# Test type mapping
source lib/op.sh
_pcm_type_to_category secret    # should output: password
_pcm_type_to_category api       # should output: api_credential
_pcm_type_to_category login     # should output: login
_pcm_type_to_category note      # should output: secure_note
_pcm_type_to_category bogus     # should error

# Test item exists (against a vault you have)
_pcm_item_exists rjayroach "some-known-item"   # should return 0
_pcm_item_exists rjayroach "nonexistent-item"  # should return 1

# Test field exists
_pcm_field_exists rjayroach "some-item" "password"   # should return 0
_pcm_field_exists rjayroach "some-item" "bogus"      # should return 1

# Test vault create still works (creates SA token as type 'secret')
# (Only test if you have a test vault available)
```

## Verification

- [ ] `_pcm_type_to_category` exists in `op.sh` and maps all four types
- [ ] `_pcm_item_exists` exists in `op.sh` and returns correct exit codes
- [ ] `_pcm_field_exists` exists in `op.sh` and returns correct exit codes
- [ ] `_pcm_create_item` accepts PCM generic type (not raw category)
- [ ] `cmd_vault_create` updated to pass `secret` instead of `password`
- [ ] `pcm vault create` still works end-to-end (if testable)
