#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Devstation Setup - Interactive Repo Configuration
# =============================================================================
# This script configures and clones repos from GitHub and Bitbucket.
# Run after bootstrap.sh has installed core dependencies.
#
# Prerequisites (installed by bootstrap.sh):
#   - Docker CE
#   - Node.js 20+
#   - GitHub CLI (gh)
#   - @devcontainers/cli
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="${HOME}/code"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# URL-encode a string (for embedding credentials in URLs)
urlencode() {
  jq -sRr @uri <<< "$1"
}

# =============================================================================
# Prerequisite Checks
# =============================================================================

check_prerequisites() {
  local missing=()

  if ! command -v docker &>/dev/null; then
    missing+=("docker")
  fi

  if ! command -v gh &>/dev/null; then
    missing+=("gh (GitHub CLI)")
  fi

  if ! command -v node &>/dev/null; then
    missing+=("node")
  fi

  if ! command -v devcontainer &>/dev/null; then
    missing+=("devcontainer CLI")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing prerequisites: ${missing[*]}"
    echo ""
    echo "Please run the bootstrap script first:"
    echo "  curl -sSL https://raw.githubusercontent.com/canuszczyk/devstation-setup/master/bootstrap.sh | bash"
    echo ""
    exit 1
  fi

  log_success "All prerequisites installed"
}

# =============================================================================
# GitHub Provider
# =============================================================================

check_gh_auth() {
  if gh auth status &>/dev/null; then
    log_success "GitHub CLI is authenticated"
    return 0
  fi
  return 1
}

prompt_gh_auth() {
  log_warn "GitHub CLI is not authenticated"
  echo ""
  echo "Please run: gh auth login"
  echo "Choose: GitHub.com > HTTPS > Authenticate with a web browser"
  echo ""
  read -rp "Press Enter after you've authenticated, or type 'skip' to skip GitHub setup: " response

  if [[ "$response" == "skip" ]]; then
    return 1
  fi

  if ! gh auth status &>/dev/null; then
    log_error "Still not authenticated. Skipping GitHub setup."
    return 1
  fi
  return 0
}

discover_github_repos() {
  local gh_target="$1"

  log_info "Fetching repos from $gh_target..."

  # Get all non-archived repos for the user/org
  local all_repos
  all_repos=$(gh repo list "$gh_target" --limit 100 --json name,isArchived --jq '.[] | select(.isArchived == false) | .name' 2>/dev/null || echo "")

  if [[ -z "$all_repos" ]]; then
    log_warn "No repos found for $gh_target"
    return
  fi

  local total
  total=$(echo "$all_repos" | wc -l)
  log_success "Found $total repos"

  printf '%s\n' "$all_repos"
}

clone_github_repos() {
  local gh_target="$1"
  shift
  local repos=("$@")

  if [[ ${#repos[@]} -eq 0 ]]; then
    return
  fi

  for repo in "${repos[@]}"; do
    local repo_path="$CODE_DIR/$repo"
    if [[ -d "$repo_path" ]]; then
      log_info "  $repo - already exists, skipping"
    else
      log_info "  Cloning $repo..."
      gh repo clone "$gh_target/$repo" "$repo_path" -- --depth=1
    fi
  done
}

# =============================================================================
# Bitbucket Provider
# =============================================================================

# Bitbucket credentials (set during authentication)
BB_USERNAME=""
BB_APP_PASSWORD=""
BB_WORKSPACE=""

prompt_bitbucket_auth() {
  echo ""
  echo "Bitbucket authentication requires:"
  echo "  - Your Bitbucket username"
  echo "  - An API token (create at: https://bitbucket.org/account/settings/api-tokens/)"
  echo "  - Your workspace name"
  echo ""
  echo "API token scopes needed: Repositories (Read)"
  echo ""
  echo "NOTE: App passwords deprecated Sep 2025, disabled Jun 2026. Use API tokens."
  echo ""

  read -rp "Bitbucket username: " BB_USERNAME
  if [[ -z "$BB_USERNAME" ]]; then
    log_warn "No username provided, skipping Bitbucket setup"
    return 1
  fi

  read -rsp "API token: " BB_APP_PASSWORD
  echo ""
  if [[ -z "$BB_APP_PASSWORD" ]]; then
    log_warn "No API token provided, skipping Bitbucket setup"
    return 1
  fi

  read -rp "Workspace name: " BB_WORKSPACE
  if [[ -z "$BB_WORKSPACE" ]]; then
    log_warn "No workspace provided, skipping Bitbucket setup"
    return 1
  fi

  # Test authentication
  log_info "Testing Bitbucket authentication..."
  local response
  response=$(curl -s -u "$BB_USERNAME:$BB_APP_PASSWORD" \
    "https://api.bitbucket.org/2.0/repositories/$BB_WORKSPACE?pagelen=1" 2>/dev/null)

  if echo "$response" | jq -e '.values' &>/dev/null; then
    log_success "Bitbucket authentication successful"
    return 0
  else
    log_error "Bitbucket authentication failed. Please check your credentials."
    return 1
  fi
}

discover_bitbucket_repos() {
  log_info "Fetching repos from $BB_WORKSPACE..."

  # Paginate through all repos, sorted by most recent activity
  local page_url="https://api.bitbucket.org/2.0/repositories/$BB_WORKSPACE?pagelen=100&sort=-updated_on"
  local all_repos=()

  while [[ -n "$page_url" ]]; do
    local response
    response=$(curl -s -u "$BB_USERNAME:$BB_APP_PASSWORD" "$page_url")

    # Extract repo slugs
    local page_repos
    mapfile -t page_repos < <(echo "$response" | jq -r '.values[]? | select(.is_private != null) | .slug' 2>/dev/null || true)
    all_repos+=("${page_repos[@]}")

    # Get next page URL (null if no more pages)
    page_url=$(echo "$response" | jq -r '.next // empty' 2>/dev/null || true)
  done

  if [[ ${#all_repos[@]} -eq 0 ]]; then
    log_warn "No repos found in workspace $BB_WORKSPACE"
    return
  fi

  log_success "Found ${#all_repos[@]} repos"

  printf '%s\n' "${all_repos[@]}"
}

clone_bitbucket_repos() {
  shift  # Skip workspace param (using global BB_WORKSPACE)
  local repos=("$@")

  if [[ ${#repos[@]} -eq 0 ]]; then
    return
  fi

  # URL-encode credentials to handle special characters (dots, @, etc.)
  local encoded_user encoded_token
  encoded_user=$(urlencode "$BB_USERNAME")
  encoded_token=$(urlencode "$BB_APP_PASSWORD")

  for repo in "${repos[@]}"; do
    local repo_path="$CODE_DIR/$repo"
    if [[ -d "$repo_path" ]]; then
      log_info "  $repo - already exists, skipping"
    else
      log_info "  Cloning $repo..."
      # Clone with embedded credentials (will be saved by git credential store)
      git clone --depth=1 \
        "https://${encoded_user}:${encoded_token}@bitbucket.org/${BB_WORKSPACE}/${repo}.git" \
        "$repo_path"
    fi
  done
}

# =============================================================================
# Interactive Selection UI
# =============================================================================

select_repos() {
  local provider="$1"
  local target="$2"
  shift 2
  local repos=("$@")
  local selected=()

  if [[ ${#repos[@]} -eq 0 ]]; then
    return
  fi

  local checked=()
  for ((i=0; i<${#repos[@]}; i++)); do
    checked[$i]=0
  done

  local done=0
  local first_display=1

  # Simple selection interface
  while [[ $done -eq 0 ]]; do
    # Add separator between iterations (but not before first display)
    if [[ $first_display -eq 0 ]]; then
      echo "" >&2
      echo "----------------------------------------" >&2
    fi
    first_display=0

    echo "" >&2
    echo "Select repos to clone from $provider ($target):" >&2
    echo "(Enter number to toggle, 'a' for all, 'n' for none, Enter to confirm)" >&2
    echo "" >&2

    for ((i=0; i<${#repos[@]}; i++)); do
      local marker="[ ]"
      if [[ ${checked[$i]} -eq 1 ]]; then
        marker="[x]"
      fi
      echo "  $((i+1)). $marker ${repos[$i]}" >&2
    done

    echo "" >&2
    read -rp "Selection (1-${#repos[@]}/a/n/Enter): " choice

    case "$choice" in
      "")
        done=1
        ;;
      a|A)
        for ((i=0; i<${#repos[@]}; i++)); do
          checked[$i]=1
        done
        ;;
      n|N)
        for ((i=0; i<${#repos[@]}; i++)); do
          checked[$i]=0
        done
        ;;
      [0-9]*)
        local idx=$((choice - 1))
        if [[ $idx -ge 0 && $idx -lt ${#repos[@]} ]]; then
          if [[ ${checked[$idx]} -eq 0 ]]; then
            checked[$idx]=1
          else
            checked[$idx]=0
          fi
        fi
        ;;
    esac
  done

  # Collect selected repos
  for ((i=0; i<${#repos[@]}; i++)); do
    if [[ ${checked[$i]} -eq 1 ]]; then
      selected+=("${repos[$i]}")
    fi
  done

  printf '%s\n' "${selected[@]}"
}

# =============================================================================
# Script and Config Installation
# =============================================================================

generate_repo_aliases() {
  local bashrc="$HOME/.bashrc"

  if [[ ! -d "$CODE_DIR" ]]; then
    return
  fi

  log_info "Generating repo-specific aliases..."

  local aliases=""
  for repo_path in "$CODE_DIR"/*/; do
    if [[ -d "${repo_path}.devcontainer" ]]; then
      local name
      name=$(basename "$repo_path")
      local alias_name
      # Convert to lowercase and replace non-alphanumeric with dashes
      alias_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
      aliases+="alias dexec-${alias_name}='dexec ~/code/${name}'\n"
    fi
  done

  if [[ -n "$aliases" ]]; then
    # Remove old generated aliases section if it exists
    sed -i '/^# === GENERATED REPO ALIASES ===/,/^# === GENERATED REPO ALIASES END ===/d' "$bashrc" 2>/dev/null || true

    # Add new aliases
    {
      echo ""
      echo "# === GENERATED REPO ALIASES ==="
      echo -e "$aliases"
      echo "# === GENERATED REPO ALIASES END ==="
    } >> "$bashrc"

    log_success "Generated dexec aliases for repos in ~/code"
  fi
}

# =============================================================================
# Optional: Initial Build
# =============================================================================

prompt_initial_build() {
  echo ""
  read -rp "Build devcontainers now? This can take a while. (y/N): " choice

  case "$choice" in
    y|Y)
      log_info "Starting devcontainer builds..."
      if [[ -x "$HOME/devcontainer-rebuild.sh" ]]; then
        "$HOME/devcontainer-rebuild.sh" "$CODE_DIR" --fast
      else
        log_warn "devcontainer-rebuild.sh not found"
      fi
      ;;
    *)
      echo ""
      echo "You can build later with:"
      echo "  ~/devcontainer-rebuild.sh ~/code"
      echo ""
      ;;
  esac
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo ""
  echo "=============================================="
  echo "  Devstation Setup - Repo Configuration"
  echo "=============================================="
  echo ""

  # Step 1: Check prerequisites
  check_prerequisites
  mkdir -p "$CODE_DIR"

  # Track if any repos were cloned
  local repos_cloned=0

  # ===================
  # GitHub Setup
  # ===================
  echo ""
  echo "--- GitHub Repository Setup ---"
  read -rp "Configure GitHub repos? (y/N): " configure_github

  if [[ "$configure_github" =~ ^[Yy]$ ]]; then
    if check_gh_auth || prompt_gh_auth; then
      read -rp "Enter GitHub username or organization: " gh_target

      if [[ -n "$gh_target" ]]; then
        # Discover repos
        mapfile -t discovered_repos < <(discover_github_repos "$gh_target")

        if [[ ${#discovered_repos[@]} -gt 0 ]]; then
          # Select repos
          mapfile -t selected_repos < <(select_repos "GitHub" "$gh_target" "${discovered_repos[@]}")

          if [[ ${#selected_repos[@]} -gt 0 ]]; then
            log_info "Cloning ${#selected_repos[@]} repos to $CODE_DIR..."
            clone_github_repos "$gh_target" "${selected_repos[@]}"
            repos_cloned=1
            log_success "GitHub repos cloned"
          fi
        fi
      fi
    fi
  fi

  # ===================
  # Bitbucket Setup
  # ===================
  echo ""
  echo "--- Bitbucket Repository Setup ---"
  read -rp "Configure Bitbucket repos? (y/N): " configure_bitbucket

  if [[ "$configure_bitbucket" =~ ^[Yy]$ ]]; then
    if prompt_bitbucket_auth; then
      # Discover repos
      mapfile -t discovered_repos < <(discover_bitbucket_repos)

      if [[ ${#discovered_repos[@]} -gt 0 ]]; then
        # Select repos
        mapfile -t selected_repos < <(select_repos "Bitbucket" "$BB_WORKSPACE" "${discovered_repos[@]}")

        if [[ ${#selected_repos[@]} -gt 0 ]]; then
          log_info "Cloning ${#selected_repos[@]} repos to $CODE_DIR..."
          clone_bitbucket_repos "$BB_WORKSPACE" "${selected_repos[@]}"
          repos_cloned=1
          log_success "Bitbucket repos cloned"
        fi
      fi
    fi
  fi

  # ===================
  # Generate Aliases
  # ===================
  if [[ $repos_cloned -eq 1 ]]; then
    echo ""
    echo "--- Generating Aliases ---"
    generate_repo_aliases
  fi

  # ===================
  # Optional Build
  # ===================
  if [[ $repos_cloned -eq 1 ]]; then
    prompt_initial_build
  fi

  # Done
  echo ""
  echo "=============================================="
  echo "  Setup Complete!"
  echo "=============================================="
  echo ""
  echo "Next steps:"
  echo "  1. Run: source ~/.bashrc"
  echo "  2. Build containers: ~/devcontainer-rebuild.sh ~/code"
  echo "  3. Shell into a container: ~/dexec ~/code/MyRepo"
  echo ""
  echo "See ~/devstation-setup/docs/ for more documentation."
  echo ""
}

main "$@"
