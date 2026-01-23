#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Devstation Bootstrap Script
# =============================================================================
# This script installs core dependencies on a fresh Ubuntu/Debian server.
# Run via: curl -sSL https://raw.githubusercontent.com/canuszczyk/devstation-setup/master/bootstrap.sh | bash
#
# After running this script, run ~/devstation-setup/install.sh to configure repos.
# =============================================================================

DEVSTATION_REPO="https://github.com/canuszczyk/devstation-setup.git"
DEVSTATION_DIR="$HOME/devstation-setup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# OS Detection and Validation
# =============================================================================

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-$ID $VERSION_ID}"
  else
    log_error "Cannot detect OS (no /etc/os-release)"
    exit 1
  fi
}

validate_os() {
  detect_os
  log_info "Detected OS: $OS_NAME"

  case "$OS_ID" in
    ubuntu|debian)
      log_success "Supported OS detected"
      ;;
    *)
      log_error "Unsupported OS: $OS_ID"
      log_error "This bootstrap script requires Ubuntu or Debian."
      exit 1
      ;;
  esac
}

# =============================================================================
# Package Installation
# =============================================================================

install_base_packages() {
  log_info "Installing base packages..."

  sudo apt-get update
  sudo apt-get install -y \
    curl wget ca-certificates gnupg lsb-release \
    git git-lfs \
    build-essential gcc g++ make \
    jq unzip

  git lfs install --system 2>/dev/null || true
  log_success "Base packages installed"
}

install_docker() {
  if command -v docker &>/dev/null; then
    log_info "Docker already installed: $(docker --version)"
    return 0
  fi

  log_info "Installing Docker CE..."

  # Add Docker's official GPG key
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Add the repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Add current user to docker group
  sudo usermod -aG docker "$USER"
  log_warn "Added $USER to docker group. You may need to log out and back in for this to take effect."

  log_success "Docker installed: $(docker --version)"
}

install_nodejs() {
  if command -v node &>/dev/null; then
    local node_ver
    node_ver=$(node --version)
    local major_ver="${node_ver%%.*}"
    major_ver="${major_ver#v}"

    if [[ "$major_ver" -ge 18 ]]; then
      log_info "Node.js already installed: $node_ver"
      return 0
    fi
  fi

  log_info "Installing Node.js 20 LTS..."

  # NodeSource setup
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs

  log_success "Node.js installed: $(node --version)"
}

install_gh_cli() {
  if command -v gh &>/dev/null; then
    log_info "GitHub CLI already installed: $(gh --version | head -1)"
    return 0
  fi

  log_info "Installing GitHub CLI..."

  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y gh

  log_success "GitHub CLI installed: $(gh --version | head -1)"
}

install_devcontainer_cli() {
  if command -v devcontainer &>/dev/null; then
    log_info "@devcontainers/cli already installed: $(devcontainer --version)"
    return 0
  fi

  log_info "Installing @devcontainers/cli..."
  sudo npm install -g @devcontainers/cli

  log_success "@devcontainers/cli installed: $(devcontainer --version)"
}

install_claude_code() {
  if command -v claude &>/dev/null; then
    log_info "Claude Code already installed: $(claude --version 2>/dev/null | head -1)"
    return 0
  fi

  log_info "Installing Claude Code CLI..."
  sudo npm install -g @anthropic-ai/claude-code

  log_success "Claude Code CLI installed"
}

install_claude_md() {
  local target="$HOME/CLAUDE.md"

  if [[ -f "$target" ]]; then
    log_info "~/CLAUDE.md already exists, updating..."
  fi

  log_info "Installing ~/CLAUDE.md..."
  cat > "$target" << 'CLAUDE_EOF'
# Devstation Host Environment

You are running on a headless Ubuntu/Debian server configured by devstation-setup.

## CRITICAL: You Are on the HOST, Not Inside a Container

This CLAUDE.md is at ~/CLAUDE.md on the HOST machine. Repos are in ~/code/ but their devcontainers run in Docker. To work on code:

1. **Start the container**: `~/devcontainer-rebuild.sh ~/code/REPO_NAME`
2. **Enter the container**: `dexec ~/code/REPO_NAME` or `dexec-REPO_NAME`
3. **Run Claude inside**: Once in the container, run `claude` there

DO NOT edit code in ~/code/* directly from the host - always enter the devcontainer first.

## Directory Structure

```
~/                          # You are here (host home)
├── CLAUDE.md               # This file (host-only context)
├── devstation-setup/       # Bootstrap scripts and templates
│   ├── bootstrap.sh        # Phase 1: Install dependencies
│   ├── install.sh          # Phase 2: Clone repos interactively
│   ├── scripts/            # Helper scripts (symlinked to ~/)
│   └── templates/          # Devcontainer templates (node, python, dotnet)
├── code/                   # Cloned repositories
│   ├── repo-a/             # Each repo has .devcontainer/
│   ├── repo-b/
│   └── ...
├── devcontainer-rebuild.sh # Symlink -> devstation-setup/scripts/
├── devcontainer-open.sh    # Symlink
├── devcontainer-stop-all.sh
├── devcontainer-cleanup.sh
└── dexec                   # Symlink - exec into containers
```

## Devcontainer Commands (Run from Host)

| Command | Purpose |
|---------|---------|
| `~/devcontainer-rebuild.sh ~/code/REPO` | Build and start container |
| `~/devcontainer-rebuild.sh ~/code` | Rebuild ALL repos in ~/code |
| `~/devcontainer-open.sh ~/code/REPO` | Start stopped container |
| `~/devcontainer-stop-all.sh` | Stop all devcontainers |
| `~/devcontainer-cleanup.sh` | Remove stopped containers, prune images |
| `dexec ~/code/REPO` | Shell into running container |
| `dexec-REPONAME` | Alias for dexec (generated by install.sh) |

## Container Lifecycle

```
Host: ~/code/my-repo/          Container: /workspaces/my-repo/
        │                                      │
        │ devcontainer up                      │
        ├─────────────────────────────────────►│
        │ (bind-mount)                         │
        │                                      │
        │ dexec ~/code/my-repo                 │
        ├─────────────────────────────────────►│ bash shell
        │                                      │ (work here!)
```

## Setting Up a New Repo

1. Clone: `cd ~/code && git clone URL`
2. Add devcontainer config:
   - Copy template: `cp -r ~/devstation-setup/templates/node/.devcontainer ~/code/REPO/`
   - Or use existing .devcontainer in the repo
3. Build: `~/devcontainer-rebuild.sh ~/code/REPO`
4. Enter: `dexec ~/code/REPO`

## Template Options

| Template | Base | Features |
|----------|------|----------|
| `templates/node/` | node:20-bookworm | npm cache volume, port 3000 |
| `templates/python/` | python:3.12-bookworm | pip cache volume, port 8000 |
| `templates/dotnet/` | dotnet/sdk:9.0 | PostgreSQL, npm+nuget caches, ports 5000,5432 |

## Common Host Tasks

**Re-run repo discovery:** `~/devstation-setup/install.sh`
**Check running containers:** `docker ps`
**View container logs:** `docker logs CONTAINER_ID`
**Clean up Docker:** `docker system prune -af`
**Rebuild all containers:** `~/devcontainer-rebuild.sh ~/code --force`

## Inside Containers

Once you `dexec` into a container:
- Working directory: `/workspaces/REPO_NAME`
- User: `vscode` (has sudo)
- Tools: git, gh, node/python/dotnet (per template), gitui, broot
- The container has its own CLAUDE.md (if the repo has one)
- API keys: Set in `~/code/REPO/.devcontainer/.env` (git-ignored)
CLAUDE_EOF

  log_success "~/CLAUDE.md installed"
}

install_gitui() {
  if command -v gitui &>/dev/null; then
    log_info "gitui already installed: $(gitui --version)"
    return 0
  fi

  log_info "Installing gitui..."

  local gitui_version="0.26.3"
  local tmp_dir
  tmp_dir=$(mktemp -d)

  curl -sSL "https://github.com/extrawurst/gitui/releases/download/v${gitui_version}/gitui-linux-x86_64.tar.gz" \
    -o "$tmp_dir/gitui.tar.gz"
  tar -xzf "$tmp_dir/gitui.tar.gz" -C "$tmp_dir"
  sudo mv "$tmp_dir/gitui" /usr/local/bin/gitui
  sudo chmod +x /usr/local/bin/gitui

  rm -rf "$tmp_dir"

  log_success "gitui installed: $(gitui --version)"
}

# =============================================================================
# Clone Devstation Setup Repository
# =============================================================================

clone_devstation_repo() {
  if [[ -d "$DEVSTATION_DIR" ]]; then
    log_info "Devstation-setup repo already exists at $DEVSTATION_DIR"
    log_info "Pulling latest changes..."
    git -C "$DEVSTATION_DIR" pull --ff-only || log_warn "Could not pull latest changes"
    return 0
  fi

  log_info "Cloning devstation-setup repository..."
  git clone "$DEVSTATION_REPO" "$DEVSTATION_DIR"
  log_success "Cloned devstation-setup to $DEVSTATION_DIR"
}

# =============================================================================
# Install Scripts and Shell Integration
# =============================================================================

install_scripts() {
  log_info "Installing management scripts to ~/ (as symlinks)"

  local scripts=(
    "devcontainer-rebuild.sh"
    "devcontainer-open.sh"
    "devcontainer-stop-all.sh"
    "devcontainer-cleanup.sh"
    "devcontainer-start-all.sh"
    "dexec"
  )

  for script in "${scripts[@]}"; do
    if [[ -f "$DEVSTATION_DIR/scripts/$script" ]]; then
      # Remove existing file/symlink and create new symlink
      rm -f "$HOME/$script"
      ln -s "$DEVSTATION_DIR/scripts/$script" "$HOME/$script"
      log_success "  Linked ~/$script -> $DEVSTATION_DIR/scripts/$script"
    else
      log_warn "  Script not found: $script"
    fi
  done
}

install_bashrc_additions() {
  local bashrc="$HOME/.bashrc"
  local marker="# === DEVSTATION CUSTOMIZATIONS ==="

  if grep -q "$marker" "$bashrc" 2>/dev/null; then
    log_info "Bashrc customizations already present"
    return
  fi

  log_info "Adding customizations to ~/.bashrc..."

  {
    echo ""
    echo "$marker"
    cat "$DEVSTATION_DIR/config/bashrc-additions"
    echo "$marker END"
  } >> "$bashrc"

  log_success "Bashrc customizations added"
}

setup_git_credential_store() {
  log_info "Configuring git credential store..."
  git config --global credential.helper store
  log_success "Git credential helper set to 'store' (~/.git-credentials)"
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo ""
  echo "=============================================="
  echo "  Devstation Bootstrap"
  echo "=============================================="
  echo ""
  echo "This script will install:"
  echo "  - Base packages (curl, git, build-essential, etc.)"
  echo "  - Docker CE + Docker Compose plugin"
  echo "  - Node.js 20 LTS"
  echo "  - GitHub CLI (gh)"
  echo "  - @devcontainers/cli"
  echo "  - Claude Code CLI"
  echo "  - gitui (terminal UI for git)"
  echo ""

  # Step 1: Validate OS
  validate_os

  # Step 2: Install packages
  echo ""
  echo "--- Installing Dependencies ---"
  install_base_packages
  install_docker
  install_nodejs
  install_gh_cli
  install_devcontainer_cli
  install_claude_code
  install_claude_md
  install_gitui

  # Step 3: Clone devstation-setup repo
  echo ""
  echo "--- Setting Up Devstation Repository ---"
  clone_devstation_repo

  # Step 4: Install scripts and shell integration
  echo ""
  echo "--- Installing Scripts and Configuration ---"
  install_scripts
  install_bashrc_additions
  setup_git_credential_store

  # Done
  echo ""
  echo "=============================================="
  echo "  Bootstrap Complete!"
  echo "=============================================="
  echo ""
  echo "Next steps:"
  echo "  1. Log out and back in (for docker group membership)"
  echo "  2. Run: source ~/.bashrc"
  echo "  3. Run: ~/devstation-setup/install.sh"
  echo ""
  echo "The install.sh script will help you:"
  echo "  - Authenticate with GitHub and/or Bitbucket"
  echo "  - Discover and clone repos with devcontainers"
  echo "  - Build devcontainers"
  echo ""
}

main "$@"
