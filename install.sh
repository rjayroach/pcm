#!/usr/bin/env bash
set -euo pipefail
#
# PCM Install Script
#
# WHAT THIS SCRIPT DOES:
#   1. Clones the pcm repo to ~/.local/share/pcm (or pulls if already present)
#   2. Symlinks ~/.local/bin/pcm to the repo's pcm script
#   3. Copies default vaults.yml to ~/.config/pcm/ (only on first install)
#
# FILES CREATED:
#   ~/.local/share/pcm/              - git clone of rjayroach/pcm
#   ~/.local/bin/pcm                 - symlink -> ~/.local/share/pcm/pcm
#   ~/.config/pcm/vaults.yml         - vault configuration (first install only)
#
# SHELL INTEGRATION:
#   Source pcm.zsh from your shell config to enable the ssh wrapper:
#     source ~/.local/share/pcm/pcm.zsh
#

PCM_REPO_URL=https://github.com/rjayroach/pcm.git
PCM_DATA_DIR="${HOME}/.local/share/pcm"
PCM_BIN_LINK="${HOME}/.local/bin/pcm"
PCM_CONFIG_DIR="${HOME}/.config/pcm"
PCM_VAULTS_FILE="${PCM_CONFIG_DIR}/vaults.yml"

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

# Copy default vaults config (only if not present)
if [[ ! -f "$PCM_VAULTS_FILE" ]]; then
  mkdir -p "$PCM_CONFIG_DIR"
  cp "$PCM_DATA_DIR/vaults.yml" "$PCM_VAULTS_FILE"
  echo "Created $PCM_VAULTS_FILE"
else
  echo "Vaults config already exists at $PCM_VAULTS_FILE — skipping"
fi

echo ""
echo -e "${GREEN}pcm installed successfully${NC}"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.config/pcm/vaults.yml to configure your vaults"
echo "  2. Source the shell wrapper:  source ~/.local/share/pcm/pcm.zsh"
echo ""
echo "Run 'pcm help' to get started."
