# pcm backend: 1Password (op)
#
# Requires: op CLI (1Password CLI v2.18.0+)
# Auth: 1Password desktop app (local) or OP_SERVICE_ACCOUNT_TOKEN (remote/CI)

_pcm_read() {
  local vault="$1" ref="$2"
  op read "op://${vault}/${ref}" 2>/dev/null
}

_pcm_list() {
  local vault="$1"
  op item list --vault "$vault" --format json 2>/dev/null
}

_pcm_create_vault() {
  local name="$1"
  op vault create "$name" --format json 2>/dev/null
}

_pcm_create_sa() {
  local name="$1" vault="$2"
  op service-account create "${name}-sa" \
    --vault "${vault}:read_items" \
    --format json 2>/dev/null | jq -r '.token'
}

_pcm_create_item() {
  local vault="$1" title="$2" category="$3"
  shift 3
  op item create --vault="$vault" --title="$title" --category="$category" "$@" 2>/dev/null
}

_pcm_sa_token() {
  local vault="$1" credentials_vault="$2"
  op read "op://${credentials_vault}/${vault}-sa-token/credential" 2>/dev/null
}

# Return the env exports needed for a remote host to use this backend.
# Called by `pcm remote-env` — the output is injected into the SSH command.
_pcm_remote_env() {
  local vault="$1" credentials_vault="$2"
  local token
  token=$(_pcm_sa_token "$vault" "$credentials_vault") || return 1
  if [[ -z "$token" ]]; then
    return 1
  fi
  echo "export OP_SERVICE_ACCOUNT_TOKEN='${token}'"
}
