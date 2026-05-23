#!/usr/bin/env bash
set -eo pipefail

# BaoTx Installation Script
# This script installs baotx and optionally configures your shell.

REPO_URL="https://github.com/nxckdx/baotx"
RELEASE_URL="https://github.com/nxckdx/baotx/releases/latest/download/baotx"

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

# Keyring check
if command -v secret-tool >/dev/null 2>&1 || command -v security >/dev/null 2>&1; then
    log "  [✓] Keyring tool found"
else
    warn "No keyring tool (secret-tool or security) found. Tokens will be stored in plain text."
fi

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
    # If the script is run from within the repo, use the local file
    cp baotx "$INSTALL_DIR/baotx"
else
    # Otherwise, download the latest release
    curl -sSL "$RELEASE_URL" -o "$INSTALL_DIR/baotx"
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
SHELL_NAME=$(basename "$SHELL")
RC_FILE=""

case "$SHELL_NAME" in
    zsh) RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *) warn "Unsupported shell: $SHELL_NAME. Manual integration required." ;;
esac

INTEGRATION_LINE="eval \"\$(baotx init $SHELL_NAME)\""

if [ -n "$RC_FILE" ]; then
    echo -e "\n${YELLOW}Shell Integration:${NC}"
    
    # Check for legacy markers first to help users clean up
    MARKER_START="# >>> baotx initialize >>>"
    MARKER_END="# <<< baotx initialize <<<"
    
    if grep -qF "$MARKER_START" "$RC_FILE" 2>/dev/null; then
        warn "BaoTx integration in $RC_FILE uses outdated markers."
        read -p "Do you want to update it to the new simplified version? (y/n): " update_confirm
        if [[ "$update_confirm" =~ ^[Yy] ]]; then
            TMP_RC=$(mktemp)
            sed "/$MARKER_START/,/$MARKER_END/d" "$RC_FILE" > "$TMP_RC"
            echo -e "\n$INTEGRATION_LINE" >> "$TMP_RC"
            cat "$TMP_RC" > "$RC_FILE"
            rm "$TMP_RC"
            log "Successfully updated integration in $RC_FILE."
        fi
    elif grep -qF "$INTEGRATION_LINE" "$RC_FILE" 2>/dev/null; then
        log "BaoTx integration in $RC_FILE is already up to date."
    else
        # Fallback check for the legacy function name without markers
        if grep -q "baotx()" "$RC_FILE" 2>/dev/null; then
             log "A legacy 'baotx()' function was detected in $RC_FILE."
             warn "Please manually replace your old baotx() function with: $INTEGRATION_LINE"
        else
            echo "BaoTx needs a shell integration to set environment variables in your current shell."
            read -p "Automatically append integration to $RC_FILE? (y/n): " confirm_rc
            if [[ "$confirm_rc" =~ ^[Yy] ]]; then
                echo -e "\n$INTEGRATION_LINE" >> "$RC_FILE"
                log "Successfully added integration to $RC_FILE."
            else
                echo -e "\nSkipping automatic update. Please add the following to your shell config (e.g. $RC_FILE):"
                echo -e "${YELLOW}------------------------------------------------------------${NC}"
                echo "$INTEGRATION_LINE"
                echo -e "${YELLOW}------------------------------------------------------------${NC}"
            fi
        fi
    fi
fi

log "Installation complete! Please restart your shell or run: source $RC_FILE"
