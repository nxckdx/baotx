#!/usr/bin/env bash
set -eo pipefail

# BaoTx Installation Script
# This script installs baotx and optionally configures your shell.

REPO_URL="https://github.com/nxckdx/baotx"
RAW_URL="https://raw.githubusercontent.com/nxckdx/baotx/main/baotx"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo -e "${GREEN}"
echo "  ____              _______      "
echo " |  _ \            |__   __|     "
echo " | |_) | __ _  ___   | |_  __  "
echo " |  _ < / _\` |/ _ \  | \ \/ /  "
echo " | |_) | (_| | (_) | | |>  <   "
echo " |____/ \__,_|\___/  |_/_/\_\  "
echo -e "${NC}"
echo "Welcome to the BaoTx installer!"
echo "--------------------------------"

# 0. Check for existing installation
OVERWRITE=false
if command -v baotx >/dev/null 2>&1; then
    EXISTING_PATH=$(command -v baotx)
    warn "BaoTx is already installed at $EXISTING_PATH"
    read -p "Do you want to overwrite it? (y/n): " overwrite_confirm
    if [[ "$overwrite_confirm" =~ ^[Yy] ]]; then
        OVERWRITE=true
        INSTALL_DIR=$(dirname "$EXISTING_PATH")
    else
        log "Installation aborted."
        exit 0
    fi
fi

# 1. Check Dependencies
log "Checking dependencies..."
for cmd in curl jq yq fzf; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        warn "Required tool '$cmd' is not installed. Please install it after this script."
    else
        log "  [✓] $cmd found"
    fi
done

# 2. Determine Install Location
if [ "$OVERWRITE" = false ]; then
    INSTALL_DIR="/usr/local/bin"
    if [ ! -w "$INSTALL_DIR" ]; then
        INSTALL_DIR="$HOME/.local/bin"
        mkdir -p "$INSTALL_DIR"
    fi

    read -p "Install baotx to [$INSTALL_DIR]? (y/n): " confirm_dir
    if [[ "$confirm_dir" =~ ^[Nn] ]]; then
        read -p "Enter custom directory: " INSTALL_DIR
        mkdir -p "$INSTALL_DIR"
    fi
fi

# 3. Download baotx
log "Downloading baotx to $INSTALL_DIR/baotx..."
if [ -f "baotx" ]; then
    cp baotx "$INSTALL_DIR/baotx"
else
    curl -sSL "$RAW_URL" -o "$INSTALL_DIR/baotx"
fi
chmod +x "$INSTALL_DIR/baotx"

# 4. Initialize Config
CONFIG_FILE="${BAOTX_CONFIG:-$HOME/.baoconfig.yaml}"
if [ ! -f "$CONFIG_FILE" ]; then
    read -p "Create initial config at $CONFIG_FILE? (y/n): " init_cfg
    if [[ "$init_cfg" =~ ^[Yy] ]]; then
        "$INSTALL_DIR/baotx" init
    fi
fi

# 5. Shell Integration
MARKER_START="# >>> baotx initialize >>>"
MARKER_END="# <<< baotx initialize <<<"

WRAPPER_CODE=$(cat << EOF

$MARKER_START
# !! Contents within this block are managed by baotx !!
baotx() {
    local out
    out=\$(command baotx "\$@")
    local ret=\$?
    if [[ "\$1" == "completion" ]]; then
        echo "\$out"
    elif [[ -n "\$out" ]]; then
        eval "\$out"
    fi
    return \$ret
}
baotx load 2>/dev/null
source <(baotx completion zsh 2>/dev/null || baotx completion bash 2>/dev/null)
$MARKER_END
EOF
)

SHELL_NAME=$(basename "$SHELL")
RC_FILE=""

case "$SHELL_NAME" in
    zsh) RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *) warn "Unsupported shell: $SHELL_NAME. Manual integration required." ;;
esac

if [ -n "$RC_FILE" ]; then
    echo -e "\n${YELLOW}Shell Integration:${NC}"
    
    if grep -qF "$MARKER_START" "$RC_FILE" 2>/dev/null; then
        log "BaoTx integration already exists in $RC_FILE. Skipping."
    else
        # Fallback check for the function name to avoid double definitions if markers are missing
        if grep -q "baotx()" "$RC_FILE" 2>/dev/null; then
             log "A 'baotx()' function was detected in $RC_FILE, but markers are missing."
             log "Skipping automatic update to avoid conflicts."
        else
            echo "BaoTx needs a wrapper function to set environment variables in your current shell."
            read -p "Automatically append wrapper to $RC_FILE? (y/n): " confirm_rc
            if [[ "$confirm_rc" =~ ^[Yy] ]]; then
                echo "$WRAPPER_CODE" >> "$RC_FILE"
                log "Successfully added wrapper to $RC_FILE."
            else
                echo -e "\nSkipping automatic update. Please add the following to your shell config (e.g. $RC_FILE or your chezmoi template):"
                echo -e "${YELLOW}------------------------------------------------------------${NC}"
                echo "$WRAPPER_CODE"
                echo -e "${YELLOW}------------------------------------------------------------${NC}"
            fi
        fi
    fi
fi

log "Installation complete! Please restart your shell or run: source $RC_FILE"
