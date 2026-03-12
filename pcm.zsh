# pcm.zsh — shell wrapper for pcm
#
# Wraps the pcm script to handle commands that need shell context
# (e.g. ssh, which must run in the current shell).
# All other commands delegate to the pcm binary.

if ! command -v pcm >/dev/null 2>&1; then
  return
fi

pcm() {
  local debug_flag=""
  if [[ "${1:-}" == "--debug" ]]; then
    debug_flag="--debug"
    shift
  fi

  case "${1:-}" in
    ssh)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Usage: pcm [--debug] ssh <host> [ssh-args...]" >&2
        return 1
      fi

      local vault remote_env

      [[ -n "$debug_flag" ]] && echo "[pcm ssh] Resolving vault..." >&2
      vault=$(command pcm $debug_flag vault show)
      if [[ $? -ne 0 || -z "$vault" ]]; then
        echo "pcm ssh: failed to resolve vault (is PCM_ACTIVE_VAULT set?)" >&2
        return 1
      fi
      [[ -n "$debug_flag" ]] && echo "[pcm ssh] Vault: $vault" >&2

      [[ -n "$debug_flag" ]] && echo "[pcm ssh] Fetching remote env..." >&2
      remote_env=$(command pcm $debug_flag remote-env)
      if [[ $? -ne 0 || -z "$remote_env" ]]; then
        echo "pcm ssh: failed to fetch remote env for vault '$vault'" >&2
        return 1
      fi
      [[ -n "$debug_flag" ]] && echo "[pcm ssh] Remote env: $remote_env" >&2

      local remote_cmd="
        ${remote_env}
        export PCM_ACTIVE_VAULT='${vault}'
        exec \$SHELL -l
      "
      [[ -n "$debug_flag" ]] && echo "[pcm ssh] Remote command: $remote_cmd" >&2

      ssh -t "$@" "$remote_cmd"
      ;;
    *)
      command pcm $debug_flag "$@"
      ;;
  esac
}
