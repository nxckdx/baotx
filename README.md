# BaoTx

BaoTx is a lightweight context and login manager for **OpenBao** and **HashiCorp Vault**. It allows you to quickly switch between different clusters, handles interactive logins, and manages your environment variables (`VAULT_ADDR`, `VAULT_TOKEN`, etc.) automatically.

## Motivation

The core idea of **BaoTx** is heavily inspired by how `kubectl` manages multiple clusters via `kubeconfig`. Just as you switch between Kubernetes contexts, BaoTx allows you to treat OpenBao/Vault clusters as named contexts, switching between them seamlessly while automatically handling the necessary environment variables and authentication tokens.

## Prerequisites

BaoTx relies on the following tools:
- `fzf` (for interactive cluster selection)
- `jq` (for JSON processing)
- `yq` (for YAML configuration management)
- `curl` (for health checks)
- `bao` or `vault` CLI
- **Optional (Secure Storage):** `secret-tool` (Linux), `security` (macOS), `gpg`, or `age`

## Installation

### The Quick Way (Interactive Installer)

Run the following command in your terminal. It will check dependencies, install the script, and guide you through the shell integration:

```bash
curl -sSL https://raw.githubusercontent.com/nxckdx/baotx/main/install.sh | bash
```

### The Manual Way

1. Download the `baotx` script to a directory in your `$PATH` (e.g., `/usr/local/bin` or `~/bin`):
   ```bash
   chmod +x baotx
   ```

2. Initialize your configuration:
   ```bash
   baotx init
   ```
   This creates a template at `~/.baoconfig.yaml`. Edit this file to add your clusters.

## Shell Integration (Mandatory)

Since a standalone binary/script cannot modify the environment variables of your current shell, you need to add a small function to your `~/.zshrc` (or `~/.bashrc`). This function captures the output of `baotx` and evaluates it to set your variables.

Add the following to your `~/.zshrc`:

```bash
# >>> baotx initialize >>>
# !! Contents within this block are managed by baotx !!
baotx() {
    local out
    # For 'exec' and 'completion', we run the command directly without capturing output.
    # This ensures interactivity and prevents issues with large output.
    if [[ "$1" == "exec" || "$1" == "completion" ]]; then
        command baotx "$@"
        return $?
    fi
    
    out=$(command baotx "$@")
    local ret=$?
    if [[ -n "$out" ]]; then
        if [[ "$*" == *"--format=env"* ]]; then
            echo "$out"
        fi
        eval "$out"
    fi
    return $ret
}
baotx load 2>/dev/null
source <(command baotx completion zsh 2>/dev/null || command baotx completion bash 2>/dev/null)
# <<< baotx initialize <<<
```

## Usage

| Command | Description |
| :--- | :--- |
| `baotx select` | Open `fzf` to select a cluster from your config. |
| `baotx select <name>` | Switch directly to a specific cluster. |
| `baotx exec <name> -- <cmd>` | Run a single command in a specific cluster context. |
| `baotx ns` | Select a namespace for the current cluster. |
| `baotx login` | Force a new interactive login for the current cluster. |
| `baotx login <name> [method]` | Force login for a specific cluster (optionally with a specific method). |
| `baotx status` | Show the current cluster, address, and token TTL. Use `--format=env` to export variables. |
| `baotx update` | Check for updates and install the latest version from GitHub. |
| `baotx clear` | Unset all environment variables and clear context. |
| `baotx help` | Show detailed help message. |

## Configuration

By default, the configuration is stored in `~/.baoconfig.yaml`.

### Token Storage Options

BaoTx supports multiple backends for storing your `VAULT_TOKEN`. You can configure this globally in your `~/.baoconfig.yaml`:

| Backend | Description | Required Config |
| :--- | :--- | :--- |
| `keyring` | (Default) Uses system keychain (`secret-tool` or macOS Keychain). | None |
| `gpg` | Encrypts tokens using GPG. Stored in `~/.local/share/baotx/`. | `storage_key: "KEY_ID"` |
| `age` | Encrypts tokens using `age`. Stored in `~/.local/share/baotx/`. | `storage_key: "PUB_KEY"`, `storage_identity: "PATH"` |
| `plain` | Stores tokens in plain text in `~/.baoconfig.yaml`. | None |

Example for GPG:
```yaml
token_storage: "gpg"
storage_key: "user@example.com"
```

Example for Age:
```yaml
token_storage: "age"
storage_key: "age1..."
storage_identity: "~/.ssh/id_ed25519" # optional
```

### Custom Configuration Path

You can override the default configuration path by setting the `BAOTX_CONFIG` environment variable. BaoTx supports **multiple configuration files** (similar to `KUBECONFIG`) by separating paths with a colon:

```bash
export BAOTX_CONFIG="$HOME/.baoconfig.yaml:$HOME/projects/work/.baotx.yaml"
```

**Key rules for multi-file configs:**
- **Precedence:** If multiple files contain a cluster with the same name, the definition in the **first** file takes precedence.
- **Write Operations:** Any commands that modify the configuration (like `baotx select`, `baotx login`, or `baotx ns`) will always write their changes to the **first** file in the list.
- **Merging:** BaoTx transparently merges all clusters and aliases from all files for use in `fzf` selection and autocompletion.

### Example Config

```yaml
cli_tool: "bao" # or "vault"
token_storage: "keyring"
clusters:
  prod:
    address: "https://bao.example.com"
    login: 
      - "oidc"      # The first method is the default
      - "userpass"  # Alternative method
    namespace: "admin" # optional active namespace
  dev:
    address: "http://127.0.0.1:8200"
    login: "token"
current-cluster: "prod"
```

## Starship Integration

If you use [Starship](https://starship.rs/), you can add a custom module to display your current BaoTx context, namespace, and token TTL in your prompt.

Add the following to your `~/.config/starship.toml`:

```toml
[custom.baotx]
command = """
cluster=$BAOTX_CLUSTER
if [ -z "$cluster" ]; then exit 0; fi

LOCK_CLOSED=""
LOCK_OPEN=""
WARN_ICON=""

if [ -n "$BAO_NAMESPACE" ]; then
    DISPLAY_NAME="${BAO_NAMESPACE}@${cluster}"
else
    DISPLAY_NAME="$cluster"
fi

# Respect BAOTX_CONFIG if set
CONFIG="${BAOTX_CONFIG:-$HOME/.baoconfig.yaml}"
exp=$(yq -r ".clusters.\"$cluster\".expire_token" "$CONFIG")

if [ "$exp" != "null" ] && [ -n "$exp" ]; then
    diff=$(( $(date -d "$exp" +%s) - $(date +%s) ))
    
    if [ $diff -le 0 ]; then
        # TOKEN EXPIRED
        echo "$LOCK_CLOSED $WARN_ICON $DISPLAY_NAME EXPIRED"
    else
        hours=$((diff / 3600))
        mins=$(( (diff % 3600) / 60 ))
        
        if [ $hours -gt 0 ]; then
            echo "$LOCK_OPEN $DISPLAY_NAME (${hours}h ${mins}m)"
        else
            echo "$LOCK_OPEN $DISPLAY_NAME (${mins}m)"
        fi
    fi
else
    echo "$LOCK_CLOSED $DISPLAY_NAME"
fi
"""
when = 'test -n "$BAOTX_CLUSTER"'
shell = ["bash", "--noprofile", "--norc"]
format = "[$output]($style) "
style = "bold yellow"
```

## Future Ideas & Contributing

Contributions are welcome! If you have an idea or want to tackle one of the points below, feel free to open a Pull Request.

Some ideas for future versions:

- **Context & Namespace History:** Support for switching back to the previous context or namespace (e.g., `baotx select -`).
- **Hook-Scripts:** Support for pre- and post-switch scripts to automate tasks like connecting to a VPN.
