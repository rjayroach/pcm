# pcm backend: 1Password (op)
#
# Requires: op CLI (1Password CLI v2.18.0+)
# Auth: 1Password desktop app (local) or OP_SERVICE_ACCOUNT_TOKEN (remote/CI)
#
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
#   _pcm_list_vaults                                  List all vaults (JSON)
#   _pcm_remote_env <vault> <creds_vault>            Output env exports for SSH
#   _pcm_type_to_category <pcm_type>                 Map generic type to native
#
# PCM generic types → 1Password categories:
#   secret  → password         Single secret value (password, token, passphrase)
#   api     → api_credential   API credentials (key + endpoint/hostname)
#   login   → login            Username + password pair
#   note    → secure_note      Freeform secure text

# Redirect stderr to /dev/null unless PCM_DEBUG is set
_pcm_stderr() {
  if [[ -n "${PCM_DEBUG:-}" ]]; then
    cat >&2
  else
    cat >/dev/null
  fi
}

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

_pcm_list_vaults() {
  op vault list --format json 2> >(_pcm_stderr)
}

_pcm_read() {
  local vault="$1" ref="$2"
  op read "op://${vault}/${ref}" 2> >(_pcm_stderr)
}

_pcm_list() {
  local vault="$1"
  op item list --vault "$vault" --format json 2> >(_pcm_stderr)
}

_pcm_item_exists() {
  local vault="$1" item="$2"
  op item get "$item" --vault "$vault" --format json >/dev/null 2>&1
}

_pcm_field_exists() {
  local vault="$1" item="$2" field="$3"
  local value
  value=$(op read "op://${vault}/${item}/${field}" 2>/dev/null) || return 1
  [[ -n "$value" ]]
}

_pcm_vault_exists() {
  local name="$1"
  op vault get "$name" --format json >/dev/null 2> >(_pcm_stderr)
}

_pcm_vault_info() {
  local name="$1"
  op vault get "$name" --format json 2> >(_pcm_stderr)
}

_pcm_create_vault() {
  local name="$1"
  op vault create "$name" --format json 2> >(_pcm_stderr)
}

_pcm_create_sa() {
  local name="$1" vault="$2" permissions="${3:-read_items}"
  op service-account create "${name}-sa" \
    --vault "${vault}:${permissions}" \
    --format json 2> >(_pcm_stderr) | jq -r '.token'
}

_pcm_create_item() {
  local vault="$1" title="$2" pcm_type="$3"
  shift 3

  local category
  category=$(_pcm_type_to_category "$pcm_type") || return 1

  _debug "Creating item: ${title} (type: ${pcm_type} -> category: ${category}) in vault ${vault}"
  op item create --vault="$vault" --title="$title" --category="$category" "$@" 2> >(_pcm_stderr)
}

_pcm_sa_token() {
  local vault="$1" credentials_vault="$2"
  op read "op://${credentials_vault}/${vault}-sa-token/password" 2> >(_pcm_stderr)
}

# Return the env exports needed for a remote host to use this backend.
_pcm_remote_env() {
  local vault="$1" credentials_vault="$2"
  local token
  token=$(_pcm_sa_token "$vault" "$credentials_vault") || return 1
  if [[ -z "$token" ]]; then
    return 1
  fi
  echo "export OP_SERVICE_ACCOUNT_TOKEN='${token}'"
}
