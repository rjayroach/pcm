# pcm.zsh — shell wrapper for pcm
#
# Wraps the pcm script to handle commands that need shell context
# (e.g. ssh, which must run in the current shell).
# All other commands delegate to the pcm binary.

if ! command -v pcm >/dev/null 2>&1; then
  return
fi

pcm() {
  case "${1:-}" in
    ssh)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Usage: pcm ssh <host> [ssh-args...]" >&2
        return 1
      fi

      local vault token

      vault=$(command pcm vault) || return 1
      token=$(command pcm token) || return 1

      ssh -t "$@" "
        export OP_SERVICE_ACCOUNT_TOKEN='${token}'
        export PCM_VAULT='${vault}'
        exec \$SHELL -l
      "
      ;;
    *)
      command pcm "$@"
      ;;
  esac
}
