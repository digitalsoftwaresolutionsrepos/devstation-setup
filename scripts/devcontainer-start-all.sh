#!/usr/bin/env bash
set -euo pipefail

# devcontainer-start-all.sh
# Start/rebuild devcontainers for all repos in ~/code/
# Usage: devcontainer-start-all.sh [--rebuild]

REBUILD=0
if [[ "${1:-}" == "--rebuild" ]]; then
  REBUILD=1
fi

CODE_DIR="${HOME}/code"
REPOS=()
for d in "$CODE_DIR"/*/; do
  [ -d "$d/.devcontainer" ] && REPOS+=("$(basename "$d")")
done

echo "Starting devcontainers for repos in $CODE_DIR"
echo "Mode: $([ "$REBUILD" == "1" ] && echo "rebuild" || echo "open existing")"
echo

for repo in "${REPOS[@]}"; do
  repo_path="$CODE_DIR/$repo"

  if [[ ! -d "$repo_path/.devcontainer" ]]; then
    echo "[$repo] Skipping - no .devcontainer found"
    continue
  fi

  echo "[$repo] Starting..."

  if [[ "$REBUILD" == "1" ]]; then
    # Use rebuild script (builds if needed, starts container)
    ~/devcontainer-rebuild.sh "$repo_path" 2>&1 | sed "s/^/  [$repo] /" &
  else
    # Use open script (just starts existing container)
    ~/devcontainer-open.sh "$repo_path" 2>&1 | sed "s/^/  [$repo] /" &
  fi
done

echo
echo "Waiting for all containers to start..."
wait

echo
echo "All done. Running containers:"
docker ps --filter "label=com.devcontainer.repo" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}"
