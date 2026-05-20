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
baotx load 2>/dev/null

# Optional: Add Auto-Completion
source <(baotx completion zsh)
```

## Usage

| Command | Description |
| :--- | :--- |
| `baotx select` | Open `fzf` to select a cluster from your config. |
| `baotx select <name>` | Switch directly to a specific cluster. |
| `baotx ns` | Select a namespace for the current cluster. |
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
    namespace: "admin" # optional active namespace
  dev:
    address: "http://127.0.0.1:8200"
    login: "token"
current-cluster: "prod"
```

## Future Ideas & Contributing

Contributions are welcome! If you have an idea or want to tackle one of the points below, feel free to open a Pull Request.

Some ideas for future versions:
- **Optional Subshell Mode:** Implement a command (e.g., `baotx shell`) that starts a new shell session with the context already loaded, avoiding the need for `eval` in the parent shell for temporary tasks.
- **Config Encryption:** Optionally encrypt the `~/.baoconfig.yaml` to better protect stored tokens.
- **Multiple Profiles:** Support different login profiles/roles for the same cluster.
