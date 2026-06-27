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
   baotx init config
   ```
   This creates a template at `~/.baoconfig.yaml`. Edit this file to add your clusters.

### NixOS / Nix Package Manager

If you are using NixOS or the Nix package manager, you can install and use BaoTx in two ways:

#### Option 1: Via Flakes (Recommended)

You can run it directly without installing:
```bash
nix run github:nxckdx/baotx -- help
```

Or add it to your system configuration. Add the input to your system's `flake.nix`:
```nix
inputs.baotx.url = "github:nxckdx/baotx";
```

And then include the package in your system packages:
```nix
environment.systemPackages = [
  inputs.baotx.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

#### Option 2: Via Tarball (Traditional Nix)

If you do not use Flakes, you can fetch and build the package directly in your `configuration.nix` by pointing to the repository's source tarball:
```nix
let
  baotx = import (builtins.fetchTarball {
    url = "https://github.com/nxckdx/baotx/archive/refs/heads/main.tar.gz";
  }) {};
in
{
  environment.systemPackages = [
    baotx
  ];
}
```
> [!NOTE]
> For production systems and reproducible builds, it is recommended to replace `refs/heads/main.tar.gz` with a specific tag or commit archive, for example: `https://github.com/nxckdx/baotx/archive/refs/tags/v1.4.2.tar.gz`.


## Shell Integration (Mandatory)

Since a standalone binary/script cannot modify the environment variables of your current shell, you need to add a small initialization line to your `~/.zshrc` (or `~/.bashrc`). This captures the output of `baotx` and evaluates it to set your variables.

Add the following to your `~/.zshrc` (or `~/.bashrc`):

```bash
# For ZSH
eval "$(baotx init zsh)"

# For Bash
eval "$(baotx init bash)"
```

## Usage

| Command | Description |
| :--- | :--- |
| `baotx select` | Open `fzf` to select a cluster from your config. |
| `baotx select <name>` | Switch directly to a specific cluster. |
| `baotx select -` | Switch back to the previous cluster. |
| `baotx exec <name> -- <cmd>` | Run a single command in a specific cluster context. |
| `baotx ns` | Select a namespace for the current cluster via `fzf`. |
| `baotx ns <name>` | Switch directly to a specific namespace. |
| `baotx ns -` | Switch back to the previous namespace for this cluster. |
| `baotx login` | Force a new interactive login for the current cluster. |
| `baotx login <name> [method]` | Force login for a specific cluster (optionally with a specific method). |
| `baotx renew` | Renew the current token lease. |
| `baotx status` | Show current cluster, address, and TTL. Use `--format=env` for .env output, `--policies` to see policy details, or `--all` for all clusters. |
| `baotx update` | Check for updates and install the latest version from GitHub. |
| `baotx clear` | Unset all environment variables and clear context. |
| `baotx help` | Show detailed help message. |

## Hook-Scripts

BaoTx supports pre- and post-command hooks. If you want to automate tasks (like connecting to a VPN before selecting a cluster or refreshing a local cache after login), you can place executable scripts in the data directory: `~/.local/share/baotx/`.

**Naming Convention:**
- `pre_<command>.sh`: Executed before the command (Global).
- `post_<command>.sh`: Executed after the command (Global).
- `<cluster>/pre_<command>.sh`: Executed before the command only for a specific cluster.
- `<cluster>/post_<command>.sh`: Executed after the command only for a specific cluster.

If both a global and a cluster-specific hook exist, **both** will be executed (cluster-specific first). If a `pre`-hook exits with a non-zero status, BaoTx will abort the command.

**Example:**
To run a script before `baotx select` only for the `prod` cluster, create `~/.local/share/baotx/prod/pre_select.sh`:
```bash
#!/bin/bash
echo "Checking production access rights..."
```

## Configuration

By default, the configuration is stored in `~/.baoconfig.yaml`.

### Cluster-specific Environment Variables

You can define custom environment variables that are automatically exported when you switch to a specific cluster. These variables are also automatically unset when you switch to another cluster or clear your context.

Example:
```yaml
clusters:
  prod:
    address: "https://bao.example.com"
    env:
      VAULT_SKIP_VERIFY: "true"
      KUBECONFIG: "~/.kube/prod-config"
```

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
