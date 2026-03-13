#compdef pcm

# Helper: collect vault names from config
_pcm_vault_names() {
  local -a names
  if command -v pcm &>/dev/null; then
    local line
    while IFS= read -r line; do
      local name
      name=$(echo "$line" | jq -r '.name // empty' 2>/dev/null)
      [[ -n "$name" ]] && names+=("$name")
    done < <(command pcm vault list 2>/dev/null | jq -c '.[]' 2>/dev/null)
  fi
  if (( ${#names} )); then
    _describe -t vaults 'vault' names
  else
    _message 'vault name'
  fi
}

# Helper: collect credential names from all config sources
_pcm_credential_names() {
  local -a creds
  if command -v pcm &>/dev/null; then
    local line
    while IFS= read -r line; do
      # pcm credential list outputs: "name  (provider: ...)" or "  field -> ENV"
      [[ "$line" == \ \ * ]] && continue
      local name="${line%%  *}"
      [[ -n "$name" ]] && creds+=("$name")
    done < <(command pcm credential list 2>/dev/null)
  fi
  if (( ${#creds} )); then
    _describe -t credentials 'credential' creds
  else
    _message 'credential name'
  fi
}

# Helper: collect plugin names from registry
_pcm_plugin_names() {
  local -a plugins
  local registry_dir="${HOME}/.cache/pcm/registry/plugins"
  if [[ -d "$registry_dir" ]]; then
    for d in "${registry_dir}"/*/; do
      [[ -f "${d}plugin.yml" ]] || continue
      plugins+=("$(basename "$d")")
    done
  fi
  if (( ${#plugins} )); then
    _describe -t plugins 'plugin' plugins
  else
    _message 'plugin name'
  fi
}

_pcm() {
  local -a commands
  commands=(
    'credential:Credential operations'
    'vault:Vault operations'
    'plugin:Plugin operations'
    'cache:Local cache management'
    'config:Show effective configuration'
    'update:Update pcm and plugin registry'
    'help:Show help'
  )

  _arguments -C \
    '(- *)--debug[Enable debug output]' \
    '1:command:->command' \
    '*::arg:->args'

  case "$state" in
    command)
      _describe -t commands 'pcm command' commands
      ;;
    args)
      case "$words[1]" in
        credential) _pcm_credential ;;
        vault)      _pcm_vault ;;
        plugin)     _pcm_plugin ;;
        cache)      _pcm_cache ;;
      esac
      ;;
  esac
}

_pcm_credential() {
  local -a cred_cmds
  cred_cmds=(
    'list:List configured credentials'
    'show:Show config details for a credential'
    'get:Fetch field values from backend'
    'validate:Check credentials exist'
  )

  _arguments -C \
    '1:subcommand:->subcmd' \
    '*::arg:->args'

  case "$state" in
    subcmd)
      _describe -t commands 'credential subcommand' cred_cmds
      ;;
    args)
      case "$words[1]" in
        show) _arguments '1:credential:_pcm_credential_names' ;;
        get)  _arguments '1:credential:_pcm_credential_names' ;;
        validate) _arguments '--fix[Provision missing items]' '-y[Skip confirmation]' '--yes[Skip confirmation]' ;;
      esac
      ;;
  esac
}

_pcm_vault() {
  local -a vault_cmds
  vault_cmds=(
    'list:List vaults in the backend'
    'show:Show details for a vault'
    'create:Create vault and service account'
  )

  _arguments -C \
    '1:subcommand:->subcmd' \
    '*::arg:->args'

  case "$state" in
    subcmd)
      _describe -t commands 'vault subcommand' vault_cmds
      ;;
    args)
      case "$words[1]" in
        show)   _arguments '1:vault:_pcm_vault_names' ;;
        create) _arguments '1:name:' ;;
      esac
      ;;
  esac
}

_pcm_plugin() {
  local -a plugin_cmds
  plugin_cmds=(
    'list:List available plugins'
    'show:Show plugin details'
    'add:Apply a plugin to the current directory'
  )

  _arguments -C \
    '1:subcommand:->subcmd' \
    '*::arg:->args'

  case "$state" in
    subcmd)
      _describe -t commands 'plugin subcommand' plugin_cmds
      ;;
    args)
      case "$words[1]" in
        list) _arguments '--installed[Show installed plugins]' ;;
        show) _arguments '1:plugin:_pcm_plugin_names' ;;
        add)  _arguments '1:plugin:_pcm_plugin_names' ;;
      esac
      ;;
  esac
}

_pcm_cache() {
  local -a cache_cmds
  cache_cmds=(
    'list:List cached SA tokens'
    'show:Show cached SA token'
    'clear:Clear cached SA token'
  )

  _arguments -C \
    '1:subcommand:->subcmd' \
    '*::arg:->args'

  case "$state" in
    subcmd)
      _describe -t commands 'cache subcommand' cache_cmds
      ;;
    args)
      case "$words[1]" in
        show)  _arguments '1:vault:_pcm_vault_names' ;;
        clear) _arguments '1:vault:_pcm_vault_names' ;;
      esac
      ;;
  esac
}

compdef _pcm pcm
