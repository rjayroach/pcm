---
---

# Plan 03 — Generate and Prompt

## Context — read these files first

- `CLAUDE.md` — project overview
- `pcm` — main script, specifically `cmd_validate` and `_validate_fix_item` stub
- `lib/op.sh` — backend with `_pcm_create_item`, `_pcm_type_to_category`
- `chorus/units/platform/01-backend-write-interface/log.md` — backend changes
- `chorus/units/platform/02-validate-command/log.md` — validate command

## Overview

Implement the `--fix` mode for `pcm validate`. When a credential item is
entirely missing, PCM collects values for all fields (generating or prompting
as appropriate) and creates the item via the backend.

## Implementation

### 1. Password generation function

Add `_generate_password` to the pcm script (in the helpers section):

```bash
_generate_password() {
  local length="${1:-32}"
  # Use /dev/urandom for portability across macOS and Linux
  # Character set: alphanumeric + common special chars
  LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
}
```

### 2. Generic `_generate_value` dispatcher

This is the single entry point for generating field values. For now it only
supports `password`, but the structure allows easy addition of new types.

```bash
_generate_value() {
  local gen_type="$1"
  shift

  case "$gen_type" in
    password)
      local length=32
      # Parse remaining args as key=value
      while [[ $# -gt 0 ]]; do
        case "$1" in
          length=*) length="${1#length=}" ;;
        esac
        shift
      done
      _generate_password "$length"
      ;;
    *)
      _error "Unknown generate type: ${gen_type}"
      _error "Supported types: password"
      return 1
      ;;
  esac
}
```

### 3. Implement `_validate_fix_item`

Replace the stub with the real implementation. This function:

1. Reads the credential's `type:` (defaults to `secret` if not specified)
2. Iterates fields, collecting values via generate or prompt
3. Builds the `op item create` arguments
4. Calls `_pcm_create_item` to create the item

```bash
_validate_fix_item() {
  local cred_name="$1" vault="$2" item_name="$3"

  # Get the credential type (for backend category mapping)
  local cred_type
  cred_type=$(_cfg ".credentials.${cred_name}.type // \"secret\"")

  echo ""
  echo "  Provisioning ${item_name}..."

  # Collect field values
  local -a field_args=()
  local field_keys
  field_keys=$(_cfg ".credentials.${cred_name}.fields | keys | .[]")

  while IFS= read -r field_name; do
    [[ -z "$field_name" ]] && continue

    local value=""

    # Check for generate spec
    local gen_type
    gen_type=$(_cfg ".credentials.${cred_name}.fields.${field_name}.generate.type")

    if [[ -n "$gen_type" ]]; then
      # Build generate args from the spec
      local gen_args=""
      local gen_length
      gen_length=$(_cfg ".credentials.${cred_name}.fields.${field_name}.generate.length")
      [[ -n "$gen_length" ]] && gen_args="length=${gen_length}"

      value=$(_generate_value "$gen_type" $gen_args)
      if [[ -z "$value" ]]; then
        _error "Failed to generate value for ${cred_name}/${field_name}"
        return 1
      fi
      echo "    Generated ${field_name} (${gen_type}, ${gen_length:-32} chars)"
    else
      # Prompt the user
      echo -n "    Enter value for ${cred_name}/${field_name}: "
      read -r value
      if [[ -z "$value" ]]; then
        _error "Empty value for ${cred_name}/${field_name} — skipping item creation"
        return 1
      fi
    fi

    # Build the field argument for op item create
    # Format: field_name=value (op CLI accepts this for custom fields)
    field_args+=("${field_name}=${value}")
  done <<< "$field_keys"

  # Create the item
  _debug "Creating item ${item_name} (type: ${cred_type}) with ${#field_args[@]} fields"
  if _pcm_create_item "$vault" "$item_name" "$cred_type" "${field_args[@]}"; then
    echo "  ✓ Created ${item_name} in vault ${vault}"
  else
    _error "Failed to create ${item_name} in vault ${vault}"
    return 1
  fi
}
```

### 4. Credential type in the schema

The `type:` key on a credential definition is optional and defaults to
`secret`. Update the field schema documentation to include it:

```yaml
credentials:
  wifi:
    provider: workspace
    type: secret                  # optional, defaults to 'secret'
    fields:
      password:
        env: TF_VAR_wifi_passphrase
        generate:
          type: password
          length: 32
  unifi:
    provider: workspace
    type: api
    fields:
      credential:
        env: UNIFI_API_KEY
      hostname:
        env: UNIFI_API
```

Valid types: `secret`, `api`, `login`, `note`. Mapped to backend-native
categories by the backend plugin.

### 5. Update plugin credential definitions

Add `type:` and `generate:` where appropriate to the plugin YAMLs:

**`pcm-plugins/plugins/unifi/credentials/wifi.yml`:**

```yaml
credentials:
  wifi:
    provider: workspace
    type: secret
    fields:
      password:
        env: TF_VAR_wifi_passphrase
        generate:
          type: password
          length: 32
```

**`pcm-plugins/plugins/unifi/credentials/unifi.yml`:**

```yaml
credentials:
  unifi:
    provider: workspace
    type: api
    fields:
      credential:
        env: UNIFI_API_KEY
      hostname:
        env: UNIFI_API
```

(No `generate:` on unifi — the API key and hostname come from the UniFi
controller and must be entered by the user.)

**`pcm-plugins/plugins/gh/credentials/gh.yml`:**

No changes — GitHub tokens are obtained from GitHub, not generated.

**`pcm-plugins/plugins/aws/credentials/aws.yml`:**

No changes — AWS keys come from the AWS console.

### 6. Prompt security

When prompting for sensitive values, use `read -rs` (silent mode) to avoid
echoing to the terminal. Add a heuristic: if the field name contains
`password`, `secret`, `token`, `key`, or `credential`, use silent input:

```bash
local is_sensitive=0
case "$field_name" in
  *password*|*secret*|*token*|*key*|*credential*) is_sensitive=1 ;;
esac

if [[ $is_sensitive -eq 1 ]]; then
  echo -n "    Enter value for ${cred_name}/${field_name} (hidden): "
  read -rs value
  echo ""  # newline after hidden input
else
  echo -n "    Enter value for ${cred_name}/${field_name}: "
  read -r value
fi
```

### 7. Confirmation before creating

Before creating items, show a summary and ask for confirmation:

```
$ PCM_SITE=singapore pcm validate --fix

  ✓ gh/token
  ✓ aws/access-key-id
  ✓ aws/secret-access-key
✗ unifi — item 'singapore-unifi' not found in vault 'SA - development'
    credential (will prompt)
    hostname (will prompt)
✗ wifi — item 'singapore-wifi' not found in vault 'SA - development'
    password (will be generated)

2 items to create. Proceed? [y/N] y

  Provisioning singapore-unifi...
    Enter value for unifi/credential (hidden): ********
    Enter value for unifi/hostname: https://192.168.1.1:443
  ✓ Created singapore-unifi in vault SA - development

  Provisioning singapore-wifi...
    Generated password (password, 32 chars)
  ✓ Created singapore-wifi in vault SA - development

All credentials validated ✓
```

The confirmation prompt (`Proceed? [y/N]`) is skipped if `--yes` or `-y`
flag is passed.

## Test Spec

Manual verification (requires 1Password CLI and a test vault):

```bash
# Test password generation
source pcm   # or extract the function
_generate_password 16    # should output 16 random chars
_generate_password 64    # should output 64 random chars

# Test validate --fix in a project with missing credentials
# (Use a test vault you can safely create items in)
cd ~/spaces/rjayroach/technical/infra/unifi
PCM_SITE=testsite pcm validate --fix
# Should prompt for unifi credentials, generate wifi password

# Verify idempotency
PCM_SITE=testsite pcm validate
# Should show all ✓

# Clean up test items manually in 1Password
```

## Verification

- [ ] `_generate_password` produces random strings of specified length
- [ ] `_generate_value password length=16` produces 16-char string
- [ ] `_generate_value bogus` errors with "Unknown generate type"
- [ ] `pcm validate --fix` prompts for fields without `generate:`
- [ ] `pcm validate --fix` auto-generates for fields with `generate:`
- [ ] `pcm validate --fix` creates items in the correct vault with prefix
- [ ] Sensitive fields use hidden input (no echo)
- [ ] Confirmation prompt shown before creating (skippable with `-y`)
- [ ] Second run of `pcm validate` shows all ✓ (idempotent)
- [ ] Plugin wifi.yml has `generate:` spec
- [ ] Plugin unifi.yml has `type: api` (no generate)
