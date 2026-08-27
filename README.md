# BaoTx

BaoTx is a lightweight context and login manager for **OpenBao** and **HashiCorp Vault**. It allows you to quickly switch between different clusters, handles interactive logins, and manages your environment variables (`VAULT_ADDR`, `VAULT_TOKEN`, etc.) automatically.

## Motivation

The core idea of **BaoTx** is heavily inspired by how `kubectl` manages multiple clusters via `kubeconfig`. Just as you switch between Kubernetes contexts, BaoTx allows you to treat OpenBao/Vault clusters as named contexts, switching between them seamlessly while automatically handling the necessary environment variables and authentication tokens.

## Prerequisites

BaoTx relies on the following tools:
- `fzf` (for interactive cluster selection)
- `jq` (for JSON processing)
- `yq` (for YAML configuration management) — see note below, **there are two incompatible tools named `yq`**
- `curl` (for health checks)
- `bao` or `vault` CLI
- **Optional (Secure Storage):** `secret-tool` (Linux), `security` (macOS), `gpg`, or `age`

> [!WARNING]
> There are two unrelated CLI tools called `yq`:
> - [**mikefarah/yq**](https://github.com/mikefarah/yq) (Go) — **this is the one BaoTx needs.** `yq --version` prints something like `yq (https://github.com/mikefarah/yq/) version v4.x.x`.
> - [**kislyuk/yq**](https://github.com/kislyuk/yq) (Python, a thin wrapper around `jq`) — this is what `pip install yq` gives you, and it does **not** support the `eval-all`/`ireduce` syntax or `-i` semantics BaoTx uses. BaoTx will refuse to run if it detects this one.
>
> On most package managers the Go version is what you get by default (e.g. `brew install yq`, or `yq-go` on nixpkgs — see the Nix section below), but if `yq` was installed via `pip`/`pipx`, it's almost certainly the wrong one. Uninstall it and install mikefarah/yq instead (e.g. via a release binary, `go install`, or your OS package manager).

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
> For production systems and reproducible builds, it is recommended to replace `refs/heads/main.tar.gz` with a specific tag or commit archive, for example: `https://github.com/nxckdx/baotx/archive/refs/tags/1.6.0.tar.gz`. Check the [Releases page](https://github.com/nxckdx/baotx/releases) for the exact tag — releases up to v1.5.0 are tagged `baotx-vX.Y.Z`, later releases use the plain `X.Y.Z` format (no `v` prefix).

#### Keyring Support on NixOS (`token_storage: "keyring"`)

The package already ships `secret-tool` (from `libsecret`) on `$PATH`, but `secret-tool` is just a client — it needs a running [Secret Service](https://specifications.freedesktop.org/secret-service/latest/) provider (e.g. `gnome-keyring`) to actually store anything. Unlike a full desktop distro, plain NixOS does not run one by default, so `keyring` storage will silently fail (or fall back to plain text) unless you enable it.

The flake exposes a NixOS module that takes care of this:

```nix
{
  inputs.baotx.url = "github:nxckdx/baotx";

  # in your system flake outputs:
  imports = [ inputs.baotx.nixosModules.default ];
  programs.baotx.enable = true;
}
```

This installs the package and enables `services.gnome.gnome-keyring`. You still need to enable PAM integration for your login manager so the keyring unlocks automatically at login — the PAM service name depends on your setup (e.g. `login`, `gdm`, `sddm`, `lightdm`):

```nix
security.pam.services.login.enableGnomeKeyring = true;
```

Without that last step, `secret-tool` will prompt you to unlock the keyring on first use each session instead of unlocking transparently at login.

> [!NOTE]
> `baotx update` is automatically disabled when BaoTx is running from `/nix/store` (i.e. installed via any of the methods above), since the Nix store is read-only. Update via `nix flake update` (flakes) or by bumping your nixpkgs/channel revision (tarball) instead.


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
| `baotx status` | Show current cluster, address, and TTL. Use `--format=env` for .env output, `--format=json` for machine-readable output, `--policies` to see policy details, or `--all` for all clusters. |
| `baotx update` | Check for updates and install the latest version from GitHub. Disabled automatically on Nix/NixOS installs (see [Keyring Support on NixOS](#keyring-support-on-nixos-token_storage-keyring) section). |
| `baotx clear` | Unset all environment variables and clear context. |
| `baotx help` | Show detailed help message. |

## Machine-Readable Status (`--format=json`)

`baotx status --format=json` prints one JSON object (or, with `--all`, an array of them) instead of the formatted text output, for scripting or monitoring:

```bash
baotx status --format=json | jq -r '.expires_in_seconds'
baotx status --format=json --all | jq -r '.[] | select(.expired) | .cluster'
```

Each object looks like this:

```json
{
  "cluster": "prod",
  "current": true,
  "address": "https://bao.example.com",
  "namespace": "admin",
  "logged_in": true,
  "expires_at": "2026-08-27T15:23:33+02:00",
  "expires_in_seconds": 3421,
  "expired": false,
  "policies": ["default", "admins"]
}
```

`policies` is only populated for a single cluster (the default, or `--all --policies`) since it requires one extra lookup per cluster — otherwise it's `null`, same as `expires_at`/`expires_in_seconds`/`expired` when the cluster isn't logged in. Calling `baotx status --format=json` with no current cluster and no `--all` prints `null`.

> [!NOTE]
> If you use the shell integration from `baotx init`, `baotx status --format=json` (unlike plain `baotx status`) bypasses the wrapper function's `eval` and streams straight to stdout, so piping it into `jq` works as expected.

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
    username: "john.doe" # optional username for userpass/ldap (prompts interactively if omitted)
    namespace: "admin" # optional active namespace
  dev:
    address: "https://self-signed.example.com"
    login: "userpass"
    insecure: true     # skip TLS certificate verification (or tls_skip_verify: true)
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
    # GNU date (-d) and BSD/macOS date (-j -f, strptime %z wants "+HHMM") are incompatible.
    if date --version >/dev/null 2>&1; then
        exp_epoch=$(date -d "$exp" +%s 2>/dev/null)
    else
        exp_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$(echo "$exp" | sed -E 's/([+-][0-9]{2}):([0-9]{2})$/\1\2/')" +%s 2>/dev/null)
    fi
    diff=$(( exp_epoch - $(date +%s) ))
    
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
