#!/usr/bin/env bash
set -euo pipefail

# Post-create command for .NET devcontainer
# Philosophy: Rebuilds must be FAST (seconds). No project-level work.
# Workspace is bind-mounted from host — node_modules, bin, obj all persist.
# Base image (devstation-base:latest) has all tools pre-installed.

log() { printf "\n\033[1;36m[setup]\033[0m %s\n" "$*"; }

SUDO_BIN=""
if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  SUDO_BIN="sudo"
fi

# --- System tuning (best-effort) ---
raise_inotify_limits() {
  if [[ -n "$SUDO_BIN" ]] \
     && [ -w /proc/sys/fs/inotify/max_user_watches ] \
     && [ -w /proc/sys/fs/inotify/max_user_instances ] \
     && [ -w /proc/sys/fs/inotify/max_queued_events ]; then
    $SUDO_BIN sysctl -w fs.inotify.max_user_watches=1048576  >/dev/null 2>&1 || true
    $SUDO_BIN sysctl -w fs.inotify.max_user_instances=2048   >/dev/null 2>&1 || true
    $SUDO_BIN sysctl -w fs.inotify.max_queued_events=32768   >/dev/null 2>&1 || true
  fi
}

prepare_runtime_dirs() {
  if [[ -n "$SUDO_BIN" ]]; then
    $SUDO_BIN chmod 1777 /tmp || true
    local ruid; ruid="$(id -u)"
    $SUDO_BIN mkdir -p "/run/user/${ruid}" || true
    $SUDO_BIN chown "${ruid}:$(id -g)" "/run/user/${ruid}" || true
  fi
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  mkdir -p "${XDG_RUNTIME_DIR}" 2>/dev/null || true
  chmod 700 "${XDG_RUNTIME_DIR}" 2>/dev/null || true
}

# --- Fix cache directory ownership (top-level only, never recursive) ---
fix_cache_ownership() {
  if [[ -n "$SUDO_BIN" ]]; then
    local myuid; myuid="$(id -u):$(id -g)"
    for p in /home/vscode/.nuget /home/vscode/.npm /home/vscode/.npm-global /home/vscode/.cache /home/vscode/.agentwatch /home/vscode/.agent-watch-hooks; do
      if [ -d "$p" ] && [ "$(stat -c '%u:%g' "$p" 2>/dev/null)" != "$myuid" ]; then
        $SUDO_BIN chown "$myuid" "$p" 2>/dev/null || true
      fi
    done
  fi
  mkdir -p "$HOME/.config/gitui" 2>/dev/null || true
  if [ "$(stat -c '%u:%g' "$HOME/.config" 2>/dev/null)" != "$(id -u):$(id -g)" ]; then
    $SUDO_BIN chown "$(id -u):$(id -g)" "$HOME/.config" 2>/dev/null || true
  fi
}

# --- GitHub CLI auth bootstrap ---
bootstrap_gh_cli() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    export GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
    if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
      printf '%s' "$GITHUB_TOKEN" | gh auth login --with-token >/dev/null 2>&1 || true
    fi
  fi
}

# --- PostgreSQL setup ---
setup_postgres() {
  if ! command -v pg_ctl >/dev/null 2>&1; then
    log "PostgreSQL not available; skipping."
    return
  fi

  local pgdata="${PGDATA:-/workspaces/$(basename "$PWD")/.devcontainer/pgdata}"

  if [[ ! -f "$pgdata/PG_VERSION" ]]; then
    log "Initializing PostgreSQL..."
    mkdir -p "$pgdata"
    initdb -D "$pgdata" --auth=trust --encoding=UTF8
  fi

  if ! pg_isready -q 2>/dev/null; then
    log "Starting PostgreSQL..."
    pg_ctl -D "$pgdata" -l "$pgdata/logfile" start -w -t 30 || true
  fi

  for i in {1..15}; do
    pg_isready -q 2>/dev/null && break
    sleep 1
  done
}

# --- AI CLIs (skip if already installed) ---
install_ai_clis() {
  if [[ "${SKIP_AI_CLIS:-0}" == "1" ]]; then
    log "Skipping AI CLI installation (SKIP_AI_CLIS=1)"
    return 0
  fi

  log "Ensuring AI CLIs… Set SKIP_AI_CLIS=1 to skip"

  if ! command -v claude >/dev/null 2>&1; then
    log "Installing Claude CLI…"
    timeout 120 npm install -g @anthropic-ai/claude-code 2>&1 || log "Warning: Claude CLI install failed (non-fatal)."
  fi

  if ! command -v codexaw >/dev/null 2>&1; then
    log "Installing Codexaw CLI…"
    local bin_dir="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}/bin"
    if timeout 120 npm install -g https://github.com/digitalsoftwaresolutionsrepos/codex/releases/latest/download/codexaw.tgz; then
      [ -x "$bin_dir/codex" ] && mv "$bin_dir/codex" "$bin_dir/codexaw" 2>/dev/null || true
    else
      log "Warning: Codexaw install failed (non-fatal)."
    fi
  fi

  if ! command -v codex >/dev/null 2>&1; then
    log "Installing Codex CLI…"
    timeout 120 npm install -g @openai/codex || log "Warning: Codex install failed (non-fatal)."
  fi
}

# --- Wait for systemd (if running as PID 1) ---
wait_for_systemd() {
  if [ -d /run/systemd/system ]; then
    log "Waiting for systemd to finish booting..."
    for i in $(seq 1 30); do
      if systemctl is-system-running --wait 2>/dev/null | grep -qE "running|degraded"; then
        log "systemd is ready."
        return 0
      fi
      sleep 1
    done
    log "Warning: systemd did not reach running state within 30s (continuing anyway)."
  fi
}

# --- AgentWatch daemon ---
start_agentwatch() {
  log "Starting AgentWatch daemon (if installed)..."
  local aw_dir="${PWD}/.agentwatch"
  local aw_supervisor="${aw_dir}/bin/agentwatch-supervisor"
  local aw_daemon="${aw_dir}/bin/agentwatch-daemon"
  local aw_config="${aw_dir}/worker-config.json"

  if [ -x "$aw_supervisor" ] && [ -f "$aw_config" ]; then
    if ! pgrep -f "agentwatch-supervisor" > /dev/null 2>&1; then
      nohup "$aw_supervisor" --config "$aw_config" > /dev/null 2>&1 &
      sleep 1
      pgrep -f "agentwatch-supervisor" > /dev/null 2>&1 && log "agentwatch-supervisor started" || log "Warning: agentwatch-supervisor failed to start"
    else
      log "agentwatch-supervisor already running"
    fi
  elif [ -x "$aw_daemon" ] && [ -f "$aw_config" ]; then
    if ! pgrep -f "agentwatch-daemon" > /dev/null 2>&1; then
      nohup "$aw_daemon" --config "$aw_config" > /dev/null 2>&1 &
      sleep 1
      pgrep -f "agentwatch-daemon" > /dev/null 2>&1 && log "agentwatch-daemon started" || log "Warning: agentwatch-daemon failed to start"
    else
      log "agentwatch-daemon already running"
    fi
  else
    log "AgentWatch not installed (skipping)"
  fi
}

# --- Main ---
main() {
  case "${1:-}" in
    --stop) exit 0 ;;
    --quick)
      wait_for_systemd
      setup_postgres
      install_ai_clis
      start_agentwatch
      log "Done (quick)."
      exit 0
      ;;
  esac

  wait_for_systemd
  raise_inotify_limits
  prepare_runtime_dirs
  fix_cache_ownership
  bootstrap_gh_cli
  setup_postgres
  install_ai_clis
  start_agentwatch

  log "Done."
}

main "$@"
