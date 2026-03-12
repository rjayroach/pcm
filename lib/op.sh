# pcm backend: 1Password (op)
#
# Requires: op CLI (1Password CLI v2.18.0+)
# Auth: 1Password desktop app (local) or OP_SERVICE_ACCOUNT_TOKEN (remote/CI)

# Redirect stderr to /dev/null unless PCM_DEBUG is set
_pcm_stderr() {
  if [[ -n "${PCM_DEBUG:-}" ]]; then
    cat >&2
  else
    cat >/dev/null
  fi
}

_pcm_read() {
  local vault="$1" ref="$2"
  op read "op://${vault}/${ref}" 2> >(_pcm_stderr)
}

_pcm_list() {
  local vault="$1"
  op item list --vault "$vault" --format json 2> >(_pcm_stderr)
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
  local vault="$1" title="$2" category="$3"
  shift 3
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
