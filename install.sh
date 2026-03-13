#!/usr/bin/env bash
set -euo pipefail
#
# PCM Install Script
#
# WHAT THIS SCRIPT DOES:
#   1. Clones the pcm repo to ~/.local/share/pcm (or pulls if already present)
#   2. Symlinks ~/.local/bin/pcm to the repo's pcm script
#   3. Creates ~/.config/pcm/conf.d/ for global config fragments
#   4. Clones the plugin registry to ~/.cache/pcm/registry
#
# FILES CREATED:
#   ~/.local/share/pcm/              - git clone of rjayroach/pcm
#   ~/.local/bin/pcm                 - symlink -> ~/.local/share/pcm/pcm
#   ~/.config/pcm/conf.d/            - global config directory
#   ~/.cache/pcm/registry/           - plugin registry clone
#
# SHELL INTEGRATION:
#   Source pcm.zsh from your shell config to enable the ssh wrapper:
#     source ~/.local/share/pcm/pcm.zsh
#

PCM_REPO_URL=https://github.com/rjayroach/pcm.git
PCM_REGISTRY_URL=https://github.com/rjayroach/pcm-plugins.git
PCM_DATA_DIR="${HOME}/.local/share/pcm"
PCM_BIN_LINK="${HOME}/.local/bin/pcm"
PCM_CONFIG_DIR="${HOME}/.config/pcm"
PCM_CONF_D="${PCM_CONFIG_DIR}/conf.d"
PCM_REGISTRY_DIR="${HOME}/.cache/pcm/registry"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
 ____   ____ __  __
|  _ \ / ___|  \/  |
| |_) | |   | |\/| |
|  __/| |___| |  | |
|_|    \____|_|  |_|

EOF
echo -e "${CYAN}Personal Credentials Manager${NC}"


# Clone or update the repo
if [[ -d "$PCM_DATA_DIR/.git" ]]; then
  echo "Updating existing install..."
  git -C "$PCM_DATA_DIR" pull
else
  echo "Cloning pcm..."
  mkdir -p "$(dirname "$PCM_DATA_DIR")"
  git clone "$PCM_REPO_URL" "$PCM_DATA_DIR"
fi

# Ensure the pcm script is executable
chmod +x "$PCM_DATA_DIR/pcm"

# Symlink the binary
mkdir -p "$(dirname "$PCM_BIN_LINK")"
if [[ -L "$PCM_BIN_LINK" ]]; then
  rm "$PCM_BIN_LINK"
fi
ln -s "$PCM_DATA_DIR/pcm" "$PCM_BIN_LINK"
echo "Linked $PCM_BIN_LINK -> $PCM_DATA_DIR/pcm"

# Create global config
mkdir -p "$PCM_CONFIG_DIR"
mkdir -p "$PCM_CONF_D"
GLOBAL_CONFIG="${PCM_CONFIG_DIR}/pcm.yml"
if [[ ! -f "$GLOBAL_CONFIG" ]]; then
  echo ""
  echo "Setting up your PCM configuration..."
  echo ""

  # Detect system username as default for user provider
  local_user="$(whoami)"

  echo "PCM uses three providers to organize credentials:"
  echo "  user     — your personal credentials (GitHub tokens, SSH keys, etc.)"
  echo "  accounts — service account tokens (for vault-to-vault access)"
  echo "  workspace — project-specific credentials (set per-project via env var)"
  echo ""
  echo "Each provider maps to a vault in your password manager."
  echo ""

  # Prompt for user provider vault name
  read -rp "Vault name for the user provider [${local_user}]: " user_vault
  user_vault="${user_vault:-$local_user}"

  # Prompt for accounts provider vault name
  read -rp "Vault name for the accounts provider [Private]: " accounts_vault
  accounts_vault="${accounts_vault:-Private}"

  cat > "$GLOBAL_CONFIG" << YAML
# PCM global configuration
# See: pcm help

backend: op

providers:
  workspace:
  user: ${user_vault}
  accounts: ${accounts_vault}
YAML
  echo ""
  echo "Created $GLOBAL_CONFIG"
  echo "  user provider     -> ${user_vault}"
  echo "  accounts provider -> ${accounts_vault}"
  echo "  workspace provider is set per-project (via PCM_PROVIDER_WORKSPACE or mise)"
else
  echo "Global config already exists at $GLOBAL_CONFIG — skipping"
fi

# Clone or update the plugin registry
if [[ -d "$PCM_REGISTRY_DIR/.git" ]]; then
  echo "Updating plugin registry..."
  git -C "$PCM_REGISTRY_DIR" pull
else
  echo "Cloning plugin registry..."
  mkdir -p "$(dirname "$PCM_REGISTRY_DIR")"
  git clone "$PCM_REGISTRY_URL" "$PCM_REGISTRY_DIR"
fi

echo ""
echo -e "${GREEN}pcm installed successfully${NC}"
echo ""
echo "Next steps:"
echo "  1. Edit config if needed:   ~/.config/pcm/pcm.yml"
echo "  2. Browse plugins:          pcm plugins available"
echo "  3. Start a project:         pcm new <plugin> <name>"
echo "  4. Shell wrapper (for ssh): source ~/.local/share/pcm/pcm.zsh"
echo ""
echo "Run 'pcm help' to get started."
