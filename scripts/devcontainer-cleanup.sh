#!/usr/bin/env bash
set -euo pipefail

# devcontainer-cleanup.sh
# Clean up stopped devcontainers, dangling images, and optionally volumes
# Usage: devcontainer-cleanup.sh [--volumes] [--all]
#   --volumes  Also remove orphaned devcontainer volumes
#   --all      Remove ALL devcontainer resources (containers, images, volumes)

CLEAN_VOLUMES=0
CLEAN_ALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --volumes) CLEAN_VOLUMES=1; shift ;;
    --all) CLEAN_ALL=1; CLEAN_VOLUMES=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--volumes] [--all]"
      echo "  --volumes  Also remove orphaned devcontainer volumes"
      echo "  --all      Remove ALL devcontainer resources (stops running containers too)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Devcontainer Cleanup ==="
echo

# If --all, stop running containers first
if [[ "$CLEAN_ALL" == "1" ]]; then
  echo "Stopping running devcontainers..."
  mapfile -t running < <(docker ps -q --filter "label=com.devcontainer.repo" 2>/dev/null || true)
  if (( ${#running[@]} > 0 )); then
    docker stop "${running[@]}" >/dev/null 2>&1 || true
    echo "  Stopped ${#running[@]} container(s)"
  else
    echo "  No running containers"
  fi
  echo
fi

# Remove stopped devcontainers
echo "Removing stopped devcontainers..."
mapfile -t stopped < <(docker ps -aq --filter "label=com.devcontainer.repo" --filter "status=exited" 2>/dev/null || true)
if (( ${#stopped[@]} > 0 )); then
  docker rm "${stopped[@]}" >/dev/null 2>&1 || true
  echo "  Removed ${#stopped[@]} stopped container(s)"
else
  echo "  No stopped containers"
fi
echo

# Remove devcontainer images (vsc-* images)
echo "Removing unused devcontainer images..."
mapfile -t images < <(docker images --filter "reference=vsc-*" -q 2>/dev/null || true)
if (( ${#images[@]} > 0 )); then
  # Only remove images not used by running containers
  for img in "${images[@]}"; do
    if ! docker ps -q --filter "ancestor=$img" | grep -q .; then
      docker rmi "$img" >/dev/null 2>&1 || true
      echo "  Removed image: $img"
    fi
  done
else
  echo "  No unused images"
fi
echo

# Prune dangling images
echo "Pruning dangling images..."
pruned=$(docker image prune -f 2>/dev/null | grep "Total reclaimed space" || echo "  Nothing to prune")
echo "  $pruned"
echo

# Remove volumes if requested
if [[ "$CLEAN_VOLUMES" == "1" ]]; then
  echo "Removing devcontainer volumes..."
  # Common volume name patterns from devcontainer configs
  patterns=(
    "npm-cache"
    "nuget-packages"
    "playwright-browsers"
    "claude-code-config"
  )

  for pattern in "${patterns[@]}"; do
    mapfile -t vols < <(docker volume ls -q --filter "name=$pattern" 2>/dev/null || true)
    for vol in "${vols[@]}"; do
      # Check if volume is in use
      if ! docker ps -q --filter "volume=$vol" | grep -q .; then
        docker volume rm "$vol" >/dev/null 2>&1 || true
        echo "  Removed volume: $vol"
      else
        echo "  Skipped (in use): $vol"
      fi
    done
  done

  # Also clean repo-specific volumes (AIGeneratedX-*)
  mapfile -t repo_vols < <(docker volume ls -q --filter "name=AIGenerated" 2>/dev/null || true)
  mapfile -t codex_vols < <(docker volume ls -q --filter "name=codex-" 2>/dev/null || true)
  all_vols=("${repo_vols[@]}" "${codex_vols[@]}")

  for vol in "${all_vols[@]}"; do
    if ! docker ps -q --filter "volume=$vol" | grep -q .; then
      docker volume rm "$vol" >/dev/null 2>&1 || true
      echo "  Removed volume: $vol"
    fi
  done
  echo
fi

# Prune build cache (always safe — just means next build is slower)
echo "Pruning Docker build cache..."
pruned_build=$(docker builder prune -af 2>/dev/null | grep "Total reclaimed space" || echo "  Nothing to prune")
echo "  $pruned_build"
echo

# Summary
echo "=== Cleanup Complete ==="
echo
echo "Remaining devcontainers:"
docker ps -a --filter "label=com.devcontainer.repo" --format "table {{.ID}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "  None"
