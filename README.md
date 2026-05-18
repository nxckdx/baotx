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

## Installation

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
# BaoTx Wrapper
baotx() {
    local out
    # Capture stdout for eval, let stderr through for UI/messages
    out=$(command baotx "$@")
    local ret=$?
    
    # Don't eval if the command is 'completion' or if there is no output
    if [[ "$1" == "completion" ]]; then
        echo "$out"
    elif [[ -n "$out" ]]; then
        eval "$out"
    fi
    return $ret
}

# Optional: Load the last active context on shell startup
eval "$(baotx load 2>/dev/null)"

# Optional: Add Auto-Completion
source <(baotx completion zsh)
```

## Usage

| Command | Description |
| :--- | :--- |
| `baotx select` | Open `fzf` to select a cluster from your config. |
| `baotx select <name>` | Switch directly to a specific cluster. |
| `baotx login` | Force a new interactive login for the current cluster. |
| `baotx status` | Show the current cluster, address, and token TTL. |
| `baotx clear` | Unset all environment variables and clear context. |
| `baotx help` | Show detailed help message. |

## Configuration

The configuration is stored in `~/.baoconfig.yaml`. Example:

```yaml
cli_tool: "bao" # or "vault"
clusters:
  prod:
    address: "https://bao.example.com"
    login: "oidc" # login method
  dev:
    address: "http://127.0.0.1:8200"
    login: "token"
current-cluster: "prod"
```
