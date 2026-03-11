# cop.zsh — shell wrapper for cop
#
# Wraps the cop script to handle commands that need shell context
# (e.g. ssh, which must run in the current shell).
# All other commands delegate to the cop binary.

if ! command -v cop >/dev/null 2>&1; then
  return
fi

cop() {
  case "${1:-}" in
    ssh)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Usage: cop ssh <host> [ssh-args...]" >&2
        return 1
      fi

      local vault token

      vault=$(command cop vault) || return 1
      token=$(command cop token) || return 1

      ssh -t "$@" "
        export OP_SERVICE_ACCOUNT_TOKEN='${token}'
        export COP_VAULT='${vault}'
        exec \$SHELL -l
      "
      ;;
    *)
      command cop "$@"
      ;;
  esac
}
