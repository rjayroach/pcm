---
---

# Plan 02 — Validate Command

## Context — read these files first

- `CLAUDE.md` — project overview
- `pcm` — main script
- `lib/op.sh` — backend with new `_pcm_item_exists` and `_pcm_field_exists`
- `chorus/units/platform/01-backend-write-interface/log.md` — Plan 01 changes

## Overview

Implement `pcm validate` — a read-only check that reports the state of all
credentials for the current project. This plan does NOT create or generate
anything — it only checks and reports. Creation is Plan 03.

Separating check from action makes the command safe to run at any time and
lets us verify the detection logic before adding write operations.

## Implementation

### 1. Add `cmd_validate` to the pcm script

Insert before the `cmd_config` section. The command:

1. Reads all credentials from the merged config
2. For each credential, resolves the provider to a vault
3. For each credential, resolves the item name (applying prefix)
4. Checks if the item exists in the vault
5. If item exists, checks each field
6. Reports results with clear status indicators

```bash
cmd_validate_help() {
  cat <<'EOF'
pcm validate — Check that all credentials exist in the backend

Usage: pcm validate

Checks every credential defined in the current project's .pcm.yml
(and merged global config) against the backend. Reports:

  ✓  field exists
  ✗  field missing (item exists, manual fix needed)
  ✗  item not found (can be created with pcm validate --fix)

Does not create or modify anything. Use --fix to provision missing items.
EOF
}

cmd_validate() {
  local fix=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix) fix=1; shift ;;
      -*)
        _error "Unknown flag: $1"
        cmd_validate_help
        exit 1
        ;;
      *) break ;;
    esac
  done

  local creds
  creds=$(_cfg '.credentials | keys | .[]')

  if [[ -z "$creds" ]]; then
    echo "No credentials configured"
    return 0
  fi

  local all_ok=1

  while IFS= read -r cred_name; do
    [[ -z "$cred_name" ]] && continue

    local cred_provider
    cred_provider=$(_cfg ".credentials.${cred_name}.provider")
    if [[ -z "$cred_provider" ]]; then
      cred_provider=$(_cfg ".credentials.${cred_name}.vault")
    fi
    if [[ -z "$cred_provider" ]]; then
      cred_provider="workspace"
    fi

    local vault
    vault=$(_resolve_vault "$cred_provider" 2>/dev/null) || vault=""
    if [[ -z "$vault" ]]; then
      echo "✗ ${cred_name} — provider '${cred_provider}' not configured"
      all_ok=0
      continue
    fi

    _with_backend "$vault" >/dev/null

    # Resolve item name with prefix
    local prefix
    prefix=$(_resolve_prefix 2>/dev/null) || prefix=""
    local item_name
    if [[ -n "$prefix" ]]; then
      item_name="${prefix}${_PCM_SETTINGS_SEPARATOR}${cred_name}"
    else
      item_name="$cred_name"
    fi

    # Check if item exists
    if _pcm_item_exists "$vault" "$item_name"; then
      # Item exists — check each field
      local item_ok=1
      local field_keys
      field_keys=$(_cfg ".credentials.${cred_name}.fields | keys | .[]")

      while IFS= read -r field_name; do
        [[ -z "$field_name" ]] && continue
        if _pcm_field_exists "$vault" "$item_name" "$field_name"; then
          echo "  ✓ ${cred_name}/${field_name}"
        else
          echo "  ✗ ${cred_name}/${field_name} — missing (item exists, manual fix needed)"
          item_ok=0
          all_ok=0
        fi
      done <<< "$field_keys"

      if [[ $item_ok -eq 1 ]]; then
        # Reprint with a summary line (overwrite field lines for clean output)
        # Actually, simpler: just print item-level summary before fields
        true
      fi
    else
      echo "✗ ${cred_name} — item '${item_name}' not found in vault '${vault}'"
      all_ok=0

      # Show what fields would need to be created
      local field_keys
      field_keys=$(_cfg ".credentials.${cred_name}.fields | keys | .[]")
      while IFS= read -r field_name; do
        [[ -z "$field_name" ]] && continue
        local has_generate
        has_generate=$(_cfg ".credentials.${cred_name}.fields.${field_name}.generate")
        if [[ -n "$has_generate" ]]; then
          echo "    ${field_name} (will be generated)"
        else
          echo "    ${field_name} (will prompt)"
        fi
      done <<< "$field_keys"

      # If --fix is passed, delegate to the fix function (Plan 03)
      if [[ $fix -eq 1 ]]; then
        _validate_fix_item "$cred_name" "$vault" "$item_name"
      fi
    fi
  done <<< "$creds"

  if [[ $all_ok -eq 1 ]]; then
    echo ""
    echo "All credentials validated ✓"
  else
    echo ""
    echo "Some credentials are missing — run 'pcm validate --fix' to provision"
    return 1
  fi
}
```

Note: The `_validate_fix_item` function is a stub in this plan — it will be
implemented in Plan 03. For now, just define it as:

```bash
_validate_fix_item() {
  _error "Fix mode not yet implemented"
}
```

### 2. Output format

The output should be clean and scannable:

```
$ pcm validate

  ✓ gh/token
  ✓ aws/access-key-id
  ✓ aws/secret-access-key
✗ unifi — item 'singapore-unifi' not found in vault 'SA - development'
    credential (will prompt)
    hostname (will prompt)
✗ wifi — item 'singapore-wifi' not found in vault 'SA - development'
    password (will be generated)

Some credentials are missing — run 'pcm validate --fix' to provision
```

When all good:

```
$ pcm validate

  ✓ gh/token
  ✓ aws/access-key-id
  ✓ aws/secret-access-key
  ✓ unifi/credential
  ✓ unifi/hostname
  ✓ wifi/password

All credentials validated ✓
```

### 3. Add to dispatch table, help, and completions

Add `validate` to:
- Main dispatch table: `validate) cmd_validate "$@" ;;`
- `cmd_help`: `validate                  Check credentials exist (--fix to provision)`
- `lib/completions.zsh`: Add `validate` to commands list

### 4. Error handling

- If a provider is not configured (e.g., workspace vault not set), report
  it per-credential rather than hard-failing. This lets the user see the
  full picture.
- If `_resolve_prefix` fails (env var not set), this should hard-fail early
  with a clear message — handled by the prefix guard (Plan 04), but for now
  the existing `_resolve_prefix` already exits on unset vars.

## Test Spec

Manual verification:

```bash
# In a directory with .pcm.yml credentials configured
cd ~/spaces/rjayroach/technical/infra/unifi
PCM_SITE=singapore pcm validate
# Should show status for each credential/field

# In a directory with no credentials
cd /tmp
pcm validate
# Should show: No credentials configured

# Without required prefix var
cd ~/spaces/rjayroach/technical/infra/unifi
pcm validate
# Should error about PCM_SITE not being set
```

## Verification

- [ ] `pcm validate` reports ✓ for existing credentials
- [ ] `pcm validate` reports ✗ for missing items
- [ ] `pcm validate` reports ✗ for missing fields on existing items
- [ ] `pcm validate` shows "will be generated" for fields with `generate:`
- [ ] `pcm validate` shows "will prompt" for fields without `generate:`
- [ ] `pcm validate` exits 0 when all ok, exits 1 when something missing
- [ ] `pcm validate --fix` prints stub message (to be implemented in Plan 03)
- [ ] `pcm help` shows validate command
- [ ] Tab completion includes validate
