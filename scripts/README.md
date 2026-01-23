# Devcontainer Management Scripts

Scripts for managing devcontainers across multiple repositories.

## Quick Reference

| Command | Description |
|---------|-------------|
| `~/devcontainer-rebuild.sh ~/code --fast` | Rebuild all repos, skip AI CLIs & Playwright |
| `~/devcontainer-rebuild.sh ~/code --force` | Force rebuild all repos from scratch |
| `~/devcontainer-open.sh ~/code` | Start all existing containers |
| `~/devcontainer-stop-all.sh` | Stop all running devcontainers |
| `~/devcontainer-cleanup.sh --all` | Remove all devcontainer resources |
| `~/dexec ~/code/RepoName` | Shell into a container by repo path |

---

## Scripts

### `~/devcontainer-rebuild.sh`

Rebuild and start devcontainer(s). Supports single repo or all repos in a directory.

```bash
# Single repo
~/devcontainer-rebuild.sh ~/code/AIGeneratedRepositoryCloner

# All repos in a directory
~/devcontainer-rebuild.sh ~/code

# With flags
~/devcontainer-rebuild.sh ~/code --force --prune --fast
```

**Flags:**
| Flag | Description |
|------|-------------|
| `--force` | Remove existing containers/images/volumes, rebuild with no Docker cache |
| `--prune` | Also run `docker image prune -f` after removal |
| `--skip-ai-clis` | Skip installing AI CLIs (Claude, Gemini, Codex) - saves ~5 min |
| `--skip-playwright` | Skip installing Playwright browser - saves ~2 min |
| `--fast` | Shortcut for `--skip-ai-clis --skip-playwright` |

**Multi-repo mode:**
- Automatically detected when path contains subdirectories with `.devcontainer/`
- Builds run in parallel
- Output is prefixed with `[RepoName]` for each repo
- Shows summary with attach instructions at the end

---

### `~/devcontainer-open.sh`

Start existing devcontainer(s) without rebuilding. Use this for daily startup.

```bash
# Single repo
~/devcontainer-open.sh ~/code/AIGeneratedRepositoryCloner

# All repos in a directory
~/devcontainer-open.sh ~/code
```

- Starts stopped containers
- Runs quick bootstrap (PostgreSQL, etc.) if available
- Shows attach instructions

---

### `~/devcontainer-stop-all.sh`

Stop all running devcontainers.

```bash
~/devcontainer-stop-all.sh
```

- Lists all running devcontainers
- Prompts for confirmation before stopping
- Identifies containers by `com.devcontainer.repo` label

---

### `~/devcontainer-cleanup.sh`

Clean up devcontainer resources (stopped containers, images, volumes).

```bash
# Remove stopped containers and unused images
~/devcontainer-cleanup.sh

# Also remove orphaned volumes
~/devcontainer-cleanup.sh --volumes

# Remove EVERYTHING (stops running containers too)
~/devcontainer-cleanup.sh --all
```

**Flags:**
| Flag | Description |
|------|-------------|
| `--volumes` | Also remove orphaned devcontainer volumes |
| `--all` | Stop running containers and remove all resources |

---

### `~/dexec`

Shell into a devcontainer by repo path (no need to know container ID).

```bash
# By repo path
~/dexec ~/code/AIGeneratedRepositoryCloner

# Or just the repo name if in ~/code
~/dexec AIGeneratedRepositoryCloner
```

- Finds container by label (stable across rebuilds)
- Opens bash shell as `vscode` user
- Works in MobaXterm "Execute Command" field

---

## Environment Variables

These can be set in the container or passed to rebuild:

| Variable | Default | Description |
|----------|---------|-------------|
| `SKIP_AI_CLIS` | `0` | Set to `1` to skip AI CLI installation |
| `SKIP_PLAYWRIGHT` | `0` | Set to `1` to skip Playwright installation |
| `SKIP_DEV_BOOTSTRAP` | `0` | Set to `1` to skip entire post-create script |
| `DEVCONTAINER_SKIP_QUICK` | `0` | Set to `1` to skip quick bootstrap on open |

---

## Container Identification

Containers are identified by a stable label based on the git remote URL:

```
com.devcontainer.repo=repo-<hash>
```

This means:
- Container IDs can change, but labels stay the same
- `dexec` always finds the right container
- Multiple repos can run simultaneously without conflicts

---

## Typical Workflows

### First time setup
```bash
# Build all repos (takes a while first time)
~/devcontainer-rebuild.sh ~/code

# Or fast build, install AI CLIs later
~/devcontainer-rebuild.sh ~/code --fast
```

### Daily startup
```bash
# Start all containers
~/devcontainer-open.sh ~/code

# Shell into one
~/dexec ~/code/AIGeneratedRepositoryCloner
```

### After pulling changes
```bash
# Rebuild specific repo
~/devcontainer-rebuild.sh ~/code/AIGeneratedRepositoryCloner
```

### Clean slate
```bash
# Stop everything, remove all resources
~/devcontainer-cleanup.sh --all

# Rebuild from scratch
~/devcontainer-rebuild.sh ~/code --force --prune
```

### MobaXterm Setup

In MobaXterm session settings, set "Execute Command" to:
```
/home/vscode/dexec /home/vscode/code/AIGeneratedRepositoryCloner
```

This will automatically shell into the container when connecting.
