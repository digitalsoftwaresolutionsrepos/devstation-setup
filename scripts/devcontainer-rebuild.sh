#!/usr/bin/env bash
set -euo pipefail

# devcontainer-rebuild.sh
# Rebuild + start a devcontainer for a repo (auto-detects repo root).
# Does NOT launch VS Code.
#
# Usage:
#   devcontainer-rebuild.sh [--force] [--prune] <path>
#   devcontainer-rebuild.sh [--force] [--prune]            # defaults to "."
#
# If <path> is a directory containing multiple repos (subdirs with .devcontainer),
# all repos will be built in parallel with the same flags.
#
# Flags:
#   --force  : remove existing container(s), images, and volumes + rebuild with no Docker cache
#   --prune  : additionally run "docker image prune -f" after removing labeled images (more aggressive)

INPUT_PATH="."
FORCE=0
PRUNE=0
SKIP_AI_CLIS=0
SKIP_PLAYWRIGHT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --prune) PRUNE=1; shift ;;
    --skip-ai-clis) SKIP_AI_CLIS=1; shift ;;
    --skip-playwright) SKIP_PLAYWRIGHT=1; shift ;;
    --fast) SKIP_AI_CLIS=1; SKIP_PLAYWRIGHT=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--force] [--prune] [--skip-ai-clis] [--skip-playwright] [--fast] [path]"
      echo ""
      echo "If path contains multiple repos (subdirs with .devcontainer), all will be built."
      echo ""
      echo "Flags:"
      echo "  --force          Remove containers/images/volumes and rebuild with no cache"
      echo "  --prune          Additionally prune dangling images after removal"
      echo "  --skip-ai-clis   Skip installing AI CLIs (claude, codex)"
      echo "  --skip-playwright Skip installing Playwright browser"
      echo "  --fast           Skip both AI CLIs and Playwright (fastest rebuild)"
      exit 0
      ;;
    *)
      INPUT_PATH="$1"
      shift
      ;;
  esac
done

INPUT_PATH="$(cd "$INPUT_PATH" && pwd)"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

find_repo_root() {
  local p="$1"

  # 1) If in a git repo, use git root
  if git -C "$p" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$p" rev-parse --show-toplevel
    return 0
  fi

  # 2) Walk up looking for .devcontainer/devcontainer.json
  local cur="$p"
  while true; do
    if [ -f "$cur/.devcontainer/devcontainer.json" ]; then
      echo "$cur"
      return 0
    fi
    if [ "$cur" = "/" ]; then
      break
    fi
    cur="$(dirname "$cur")"
  done

  echo ""
  return 1
}

calc_id_label() {
  local root="$1"

  local key="${DEVCONTAINER_ID_LABEL_KEY:-com.devcontainer.repo}"
  local remote=""
  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    remote="$(git -C "$root" config --get remote.origin.url || true)"
  fi

  local basis=""
  if [ -n "$remote" ]; then
    basis="$remote"
    basis="${basis#ssh://}"
    basis="${basis#https://}"
    basis="${basis#http://}"
    basis="${basis%.git}"
    basis="${basis%/}"
  else
    basis="$(basename "$root")"
  fi

  local hash=""
  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$basis" | sha256sum | awk '{print $1}' | cut -c1-16)"
  elif command -v shasum >/dev/null 2>&1; then
    hash="$(printf '%s' "$basis" | shasum -a 256 | awk '{print $1}' | cut -c1-16)"
  else
    hash="$(printf '%s' "$basis" | cksum | awk '{print $1}')"
  fi

  local val="${DEVCONTAINER_ID_LABEL_PREFIX:-repo}-${hash}"
  echo "${key}=${val}"
}

remove_labeled_containers_and_images() {
  local id_label="$1"
  local repo_root="$2"
  local key="${id_label%%=*}"
  local val="${id_label#*=}"

  # Containers (running or stopped)
  mapfile -t cids < <(docker ps -aq --filter "label=$key=$val" || true)
  if (( ${#cids[@]} > 0 )); then
    echo "Removing existing container(s) for label $id_label:"
    printf '  %s\n' "${cids[@]}"
    docker rm -f "${cids[@]}" >/dev/null 2>&1 || true
  fi

  # Images built for this devcontainer label (best-effort)
  mapfile -t iids < <(docker images -q --filter "label=$key=$val" || true)
  if (( ${#iids[@]} > 0 )); then
    echo "Removing existing image(s) for label $id_label:"
    printf '  %s\n' "${iids[@]}"
    docker rmi -f "${iids[@]}" >/dev/null 2>&1 || true
  fi

  # Remove associated Docker volumes (nuget, npm cache, etc.) to ensure clean rebuild
  local folder_basename
  folder_basename="$(basename "$repo_root")"
  local volume_prefix="${folder_basename}-"
  mapfile -t vols < <(docker volume ls -q --filter "name=${volume_prefix}" 2>/dev/null || true)
  if (( ${#vols[@]} > 0 )); then
    echo "Removing associated Docker volume(s) for prefix '$volume_prefix':"
    printf '  %s\n' "${vols[@]}"
    docker volume rm "${vols[@]}" >/dev/null 2>&1 || true
  fi

  if [[ "$PRUNE" == "1" ]]; then
    echo "Pruning dangling images (docker image prune -f)..."
    docker image prune -f >/dev/null 2>&1 || true
  fi
}

# Verify that required tools are available in the container
# Returns: "OK" on success, "MISSING: tool1 tool2" on failure
verify_container() {
  local cid="$1"
  local skip_ai="${2:-0}"

  local verify_cmd='
    # Ensure common install locations are in PATH
    export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
    MISSING=()
    for cmd in node npm gitui; do
      command -v "$cmd" >/dev/null 2>&1 || MISSING+=("$cmd")
    done
    if [[ "'"$skip_ai"'" != "1" ]]; then
      for cmd in claude codex; do
        command -v "$cmd" >/dev/null 2>&1 || MISSING+=("$cmd")
      done
    fi
    if (( ${#MISSING[@]} > 0 )); then
      echo "MISSING: ${MISSING[*]}"
      exit 1
    fi
    echo "OK"
  '
  docker exec "$cid" bash -c "$verify_cmd" 2>/dev/null
}

# Build a single repo - used for both single and multi-repo modes
# Sets BUILD_VERIFY_RESULT to "OK" or "MISSING: ..." after build
build_single_repo() {
  local repo_root="$1"
  local force="$2"
  local prune="$3"
  local prefix="${4:-}"  # Optional prefix for output (e.g., "[RepoName] ")

  local id_label
  id_label="$(calc_id_label "$repo_root")"

  echo "${prefix}Repo root: $repo_root"
  echo "${prefix}Using id-label: $id_label"

  if [[ "$force" == "1" ]]; then
    echo "${prefix}FORCE=1: removing labeled containers + images + volumes and rebuilding with --build-no-cache"
    # Temporarily set PRUNE for the removal function
    PRUNE="$prune" remove_labeled_containers_and_images "$id_label" "$repo_root"
  fi

  echo "${prefix}Starting devcontainer up..."
  if [[ "$force" == "1" ]]; then
    devcontainer up \
      --workspace-folder "$repo_root" \
      --id-label "$id_label" \
      --remove-existing-container \
      --build-no-cache
  else
    devcontainer up \
      --workspace-folder "$repo_root" \
      --id-label "$id_label" \
      --remove-existing-container
  fi

  echo "${prefix}Devcontainer is up."

  # Verify container has required tools
  local key="${id_label%%=*}"
  local val="${id_label#*=}"
  local cid
  cid="$(docker ps -aq --filter "label=$key=$val" | head -n 1 || true)"

  if [ -n "${cid:-}" ]; then
    echo "${prefix}Verifying container tools..."
    BUILD_VERIFY_RESULT="$(verify_container "$cid" "${SKIP_AI_CLIS:-0}")"
    if [[ "$BUILD_VERIFY_RESULT" == "OK" ]]; then
      echo "${prefix}Verification: all tools present"
      # Fix git dubious ownership warning for mounted workspaces (both root and vscode)
      docker exec "$cid" git config --global --add safe.directory '*' 2>/dev/null || true
      docker exec -u vscode "$cid" git config --global --add safe.directory '*' 2>/dev/null || true
      # Copy git credentials from host into container (not bind-mounted to avoid write conflicts)
      if [[ -f "$HOME/.git-credentials" ]]; then
        docker cp "$HOME/.git-credentials" "$cid:/home/vscode/.git-credentials" 2>/dev/null || true
        docker exec "$cid" chown vscode:vscode /home/vscode/.git-credentials 2>/dev/null || true
        docker exec "$cid" chmod 600 /home/vscode/.git-credentials 2>/dev/null || true
      fi
      # Configure credential helper for both root and vscode users
      docker exec "$cid" git config --global credential.helper store 2>/dev/null || true
      docker exec -u vscode "$cid" git config --global credential.helper store 2>/dev/null || true
      echo "${prefix}Git credentials configured"
      # Configure gh CLI for git authentication
      docker exec "$cid" gh auth setup-git 2>/dev/null || true
      echo "${prefix}GitHub CLI configured for git"
    else
      echo "${prefix}Verification FAILED: $BUILD_VERIFY_RESULT"
      return 1
    fi
  else
    BUILD_VERIFY_RESULT="MISSING: container not found"
    echo "${prefix}Verification FAILED: could not find container"
    return 1
  fi
}

# Find all repos with devcontainers in a directory
find_repos_in_dir() {
  local dir="$1"
  local repos=()

  for subdir in "$dir"/*/; do
    if [[ -d "$subdir" && -f "${subdir}.devcontainer/devcontainer.json" ]]; then
      repos+=("${subdir%/}")
    fi
  done

  printf '%s\n' "${repos[@]}"
}

# Check if path is itself a repo or a parent of multiple repos
is_multi_repo_dir() {
  local dir="$1"

  # If this directory itself has a devcontainer, it's a single repo
  if [[ -f "$dir/.devcontainer/devcontainer.json" ]]; then
    return 1
  fi

  # If this directory is inside a git repo, it's a single repo
  if git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    return 1
  fi

  # Check if any subdirectories have devcontainers
  for subdir in "$dir"/*/; do
    if [[ -d "$subdir" && -f "${subdir}.devcontainer/devcontainer.json" ]]; then
      return 0
    fi
  done

  return 1
}

# Format seconds into human-readable duration (e.g. "2m 34s")
format_duration() {
  local secs="$1"
  if (( secs >= 3600 )); then
    printf '%dh %dm %ds' $((secs / 3600)) $(( (secs % 3600) / 60 )) $((secs % 60))
  elif (( secs >= 60 )); then
    printf '%dm %ds' $((secs / 60)) $((secs % 60))
  else
    printf '%ds' "$secs"
  fi
}

main() {
  require devcontainer
  require docker
  require git

  # Check if we're in multi-repo mode
  if is_multi_repo_dir "$INPUT_PATH"; then
    echo "=== Multi-repo mode ==="
    echo "Building all devcontainers in: $INPUT_PATH"
    echo "Flags: FORCE=$FORCE PRUNE=$PRUNE SKIP_AI_CLIS=$SKIP_AI_CLIS SKIP_PLAYWRIGHT=$SKIP_PLAYWRIGHT"
    echo ""

    mapfile -t repos < <(find_repos_in_dir "$INPUT_PATH")

    if (( ${#repos[@]} == 0 )); then
      echo "No repos with devcontainers found in: $INPUT_PATH"
      exit 1
    fi

    echo "Found ${#repos[@]} repo(s):"
    for repo in "${repos[@]}"; do
      echo "  - $(basename "$repo")"
    done
    echo ""

    # Build all repos in parallel
    # Each build runs as a background process with output going to a log file
    local log_dir="/tmp/devcontainer-build-logs"
    mkdir -p "$log_dir"
    local total_start=$SECONDS

    # Associative arrays for tracking PIDs and repo info
    declare -A pids=()       # pids[name]=pid
    declare -A repo_paths=() # repo_paths[name]=path

    # Clean up any stale status files from previous runs
    rm -f "$log_dir"/*.status "$log_dir"/*.duration 2>/dev/null

    # Ordered list of repo names (preserves discovery order)
    local -a repo_names=()

    for repo in "${repos[@]}"; do
      local name
      name="$(basename "$repo")"
      local logfile="$log_dir/${name}.log"

      repo_paths["$name"]="$repo"
      repo_names+=("$name")

      # Launch build in background subshell
      # Each build gets its own TMPDIR to avoid devcontainer CLI race conditions
      # (parallel builds share /tmp/devcontainercli-vscode/ and race on updateUID.Dockerfile)
      (
        per_build_tmp="/tmp/devcontainer-build-${name}"
        mkdir -p "$per_build_tmp"
        export TMPDIR="$per_build_tmp"
        export SKIP_AI_CLIS="$SKIP_AI_CLIS"
        export SKIP_PLAYWRIGHT="$SKIP_PLAYWRIGHT"
        export BUILD_VERIFY_RESULT=""
        local start=$SECONDS
        if build_single_repo "$repo" "$FORCE" "$PRUNE" "[$name] " > "$logfile" 2>&1; then
          echo "$((SECONDS - start))" > "$log_dir/${name}.duration"
          echo "ok" > "$log_dir/${name}.status"
        else
          echo "$((SECONDS - start))" > "$log_dir/${name}.duration"
          echo "FAILED" > "$log_dir/${name}.status"
        fi
      ) &
      pids["$name"]=$!
    done

    local total=${#repo_names[@]}

    # Print initial status table - one line per repo
    for name in "${repo_names[@]}"; do
      printf "  %-38s %-44s %s\n" "$name" "starting..." "0s"
    done

    # Poll loop: update each line in-place using ANSI cursor movement
    local finished=0
    local failed=0
    declare -A reported=()

    while (( finished < total )); do
      for i in "${!repo_names[@]}"; do
        local name="${repo_names[$i]}"
        [[ -n "${reported[$name]:-}" ]] && continue
        if [[ -f "$log_dir/${name}.status" ]]; then
          local status
          status="$(cat "$log_dir/${name}.status")"
          local dur="0"
          [[ -f "$log_dir/${name}.duration" ]] && dur="$(cat "$log_dir/${name}.duration")"
          # Move cursor up to this repo's line and overwrite it
          local lines_up=$(( total - i ))
          printf "\033[%dA\r" "$lines_up"
          if [[ "$status" == "ok" ]]; then
            printf "  %-38s %-44s %s\033[K\n" "$name" "successful" "$(format_duration "$dur")"
          else
            printf "  %-38s %-44s %s\033[K\n" "$name" "FAILED" "$(format_duration "$dur")"
            failed=$((failed + 1))
          fi
          # Move cursor back down to bottom
          if (( lines_up > 1 )); then
            printf "\033[%dB" $(( lines_up - 1 ))
          fi
          reported["$name"]=1
          finished=$((finished + 1))
        fi
      done

      if (( finished < total )); then
        # Update running repos with current phase + elapsed time
        for i in "${!repo_names[@]}"; do
          local name="${repo_names[$i]}"
          [[ -n "${reported[$name]:-}" ]] && continue
          local elapsed=$((SECONDS - total_start))
          local logfile="$log_dir/${name}.log"
          # Determine current phase from log content
          local phase="starting..."
          if [[ -f "$logfile" ]]; then
            if grep -q "Verification: all tools present" "$logfile" 2>/dev/null; then
              phase="configuring git..."
            elif grep -q "Verifying container tools" "$logfile" 2>/dev/null; then
              phase="verifying tools..."
            elif grep -q "Devcontainer is up" "$logfile" 2>/dev/null; then
              phase="verifying tools..."
            elif grep -q "postStartCommand" "$logfile" 2>/dev/null; then
              phase="post-start command..."
            elif grep -q "postCreateCommand\|Post-Create" "$logfile" 2>/dev/null; then
              # Try to get a specific post-create step
              local pc_line
              pc_line="$(grep -E '(Installing|Restoring|Setting up|Starting|Fixing|Waiting)' "$logfile" 2>/dev/null | tail -1 | sed 's/^\[.*\] //' | cut -c1-42)" || true
              if [[ -n "$pc_line" ]]; then
                phase="$pc_line"
              else
                phase="post-create command..."
              fi
            elif grep -q "docker buildx build\|building with" "$logfile" 2>/dev/null; then
              # Try to get the docker build step
              local build_step
              build_step="$(grep -oE '\[[0-9]+/[0-9]+\] [A-Z]+' "$logfile" 2>/dev/null | tail -1)" || true
              if [[ -n "$build_step" ]]; then
                phase="docker build $build_step"
              else
                phase="docker build..."
              fi
            elif grep -q "Starting devcontainer up" "$logfile" 2>/dev/null; then
              phase="devcontainer up..."
            elif grep -q "removing\|Removing" "$logfile" 2>/dev/null; then
              phase="removing old containers..."
            elif grep -q "Repo root:" "$logfile" 2>/dev/null; then
              phase="initializing..."
            fi
          fi
          local lines_up=$(( total - i ))
          printf "\033[%dA\r" "$lines_up"
          printf "  %-38s %-44s %s\033[K\n" "$name" "$phase" "$(format_duration "$elapsed")"
          if (( lines_up > 1 )); then
            printf "\033[%dB" $(( lines_up - 1 ))
          fi
        done
        sleep 3
      fi
    done

    # Wait for all background processes to fully exit (|| true to avoid set -e)
    wait 2>/dev/null || true

    # Clean up per-build temp directories
    for name in "${repo_names[@]}"; do
      rm -rf "/tmp/devcontainer-build-${name}" 2>/dev/null || true
    done

    echo ""
    echo "=== Build Summary ==="
    echo ""

    local succeeded=$(( total - failed ))
    for name in "${repo_names[@]}"; do
      local status="ok"
      [[ -f "$log_dir/${name}.status" ]] && status="$(cat "$log_dir/${name}.status")"
      local dur="0"
      [[ -f "$log_dir/${name}.duration" ]] && dur="$(cat "$log_dir/${name}.duration")"
      if [[ "$status" == "ok" ]]; then
        printf "  %-40s %s\n" "$name" "$(format_duration "$dur")"
      else
        printf "  %-40s %s  FAILED\n" "$name" "$(format_duration "$dur")"
      fi
    done

    echo ""
    echo "Results: ${succeeded} succeeded, ${failed} failed"
    echo "Total time: $(format_duration "$((SECONDS - total_start))")"
    echo "Build logs: $log_dir/"
    echo ""

    if (( failed > 0 )); then
      exit 1
    fi

    # Show attach instructions for successful builds
    echo "=== Attach Instructions ==="
    echo ""
    for name in "${repo_names[@]}"; do
      local status="ok"
      [[ -f "$log_dir/${name}.status" ]] && status="$(cat "$log_dir/${name}.status")"
      if [[ "$status" == "ok" ]]; then
        echo "$name:"
        echo "  dexec ${repo_paths[$name]}"
        echo ""
      fi
    done
  else
    # Single repo mode (original behavior)
    local repo_root
    repo_root="$(find_repo_root "$INPUT_PATH")" || true
    if [ -z "${repo_root:-}" ]; then
      echo "Could not determine repo root from: $INPUT_PATH"
      echo "Expected either:"
      echo "  - to be inside a git repo, or"
      echo "  - to find .devcontainer/devcontainer.json by walking upward"
      echo "  - or a directory containing multiple repos with devcontainers"
      exit 2
    fi

    if [ ! -f "$repo_root/.devcontainer/devcontainer.json" ]; then
      echo "No devcontainer found at: $repo_root/.devcontainer/devcontainer.json"
      exit 3
    fi

    export SKIP_AI_CLIS="$SKIP_AI_CLIS"
    export SKIP_PLAYWRIGHT="$SKIP_PLAYWRIGHT"
    export BUILD_VERIFY_RESULT=""

    local total_start=$SECONDS
    if ! build_single_repo "$repo_root" "$FORCE" "$PRUNE"; then
      echo ""
      echo "=== Build Summary ==="
      echo "  $(basename "$repo_root")  $(format_duration "$((SECONDS - total_start))")  FAILED"
      exit 1
    fi

    # Print attach instructions
    local id_label
    id_label="$(calc_id_label "$repo_root")"
    local key="${id_label%%=*}"
    local val="${id_label#*=}"
    local cid
    cid="$(docker ps -aq --filter "label=$key=$val" | head -n 1 || true)"

    echo ""
    echo "=== Build Summary ==="
    echo "  $(basename "$repo_root")  $(format_duration "$((SECONDS - total_start))")"
    echo ""

    if [ -n "${cid:-}" ]; then
      echo "Container: $cid"
      echo "Attach:"
      echo "  dexec $repo_root"
    fi
  fi
}

main "$@"
