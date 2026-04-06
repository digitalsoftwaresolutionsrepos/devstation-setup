# Devstation Setup

Automated two-phase setup for a Linux devcontainer-based development environment. Provision a fresh Ubuntu/Debian server with Docker, Node.js, and devcontainer tooling, then interactively clone repos from GitHub and Bitbucket.

## Features

- **Two-phase setup** - Bootstrap dependencies, then configure repos
- **Multi-provider support** - Clone from GitHub and/or Bitbucket
- **Docker CE** with compose plugin and buildx for container management
- **@devcontainers/cli** for headless devcontainer operations (no VS Code required)
- **Management scripts** for rebuilding, starting, stopping, and cleaning up devcontainers
- **Multi-repo support** - Run multiple devcontainers simultaneously
- **SSH-based workflow** - Connect via MobaXterm, VS Code Remote SSH, or terminal

## Quick Start

### Phase 1: Bootstrap (Fresh Ubuntu/Debian Server)

```bash
curl -sSL https://raw.githubusercontent.com/digitalsoftwaresolutionsrepos/devstation-setup/master/bootstrap.sh | bash
```

This installs:
- Base packages (curl, git, git-lfs, build-essential, jq)
- Docker CE + Docker Compose plugin
- Node.js 20 LTS
- GitHub CLI (`gh`)
- `@devcontainers/cli`
- Management scripts symlinked to `~/`
- Shell customizations in `~/.bashrc`

**Important:** Log out and back in after bootstrap to activate Docker group membership.

### Phase 2: Configure Repos

```bash
~/devstation-setup/install.sh
```

The interactive installer will:
1. Check prerequisites are installed
2. Prompt to configure GitHub repos (optional)
   - Authenticate with `gh auth login` if needed
   - Discover repos with `.devcontainer/` directories
   - Interactive multi-select UI
3. Prompt to configure Bitbucket repos (optional)
   - Enter username, app password, and workspace
   - Discover repos with `.devcontainer/` directories
   - Interactive multi-select UI
4. Clone selected repos to `~/code/`
5. Generate `dexec-{repo}` shell aliases
6. Optionally build devcontainers

## Management Scripts

After installation, you'll have these scripts in your home directory:

| Script | Description |
|--------|-------------|
| `~/devcontainer-rebuild.sh [path]` | Build/rebuild devcontainer(s) |
| `~/devcontainer-open.sh [path]` | Start existing container(s) |
| `~/devcontainer-stop-all.sh` | Stop all running devcontainers |
| `~/devcontainer-start-all.sh` | Start all devcontainers |
| `~/devcontainer-start-all.sh --rebuild` | Rebuild all devcontainers |
| `~/devcontainer-stop.sh [path]` | Stop a single container |
| `~/devcontainer-cleanup.sh` | Clean up stopped containers/images |
| `~/build-base-image.sh` | Build `devstation-base:latest` image |
| `~/dexec [path]` | Shell into a container by repo path |

See [scripts/README.md](scripts/README.md) for detailed usage.

## Shell Aliases

The installer adds convenient aliases to `~/.bashrc`:

```bash
# Management aliases
dc-stop-all          # Stop all devcontainers
dc-start-all         # Start all devcontainers
dc-rebuild-all       # Rebuild all devcontainers
dc-cleanup           # Clean up unused containers

# Per-repo aliases (auto-generated)
dexec-myrepo         # Shell into myrepo's container
dexec-another-repo   # Shell into another-repo's container
```

## Daily Workflow

```bash
# Start all containers
dc-start-all

# Shell into a specific repo's container
dexec-myrepo
# or
~/dexec ~/code/MyRepo

# Stop everything at end of day
dc-stop-all
```

## Bitbucket Setup

To clone from Bitbucket, you'll need an API token:

> **Note:** App passwords deprecated Sep 2025, disabled Jun 2026. Use API tokens.

1. Go to https://bitbucket.org/account/settings/api-tokens/
2. Create new API token with **Repositories: Read** scope
3. Save the token securely
4. When prompted by `install.sh`, enter:
   - Your Bitbucket username
   - The API token
   - Your workspace name

See the [wiki](../../wiki/Bitbucket-Setup) for detailed instructions.

## Repository Structure

```
devstation-setup/
├── README.md                    # This file
├── bootstrap.sh                 # Phase 1: Install dependencies
├── install.sh                   # Phase 2: Configure repos
├── docs/
│   ├── VM-SETUP.md             # Manual VM setup guide
│   ├── SOFTWARE.md             # Software versions and details
│   ├── MOBAXTERM.md            # MobaXterm configuration
│   └── TROUBLESHOOTING.md      # Common issues and solutions
├── scripts/
│   ├── devcontainer-rebuild.sh
│   ├── devcontainer-open.sh
│   ├── devcontainer-stop-all.sh
│   ├── devcontainer-cleanup.sh
│   ├── devcontainer-start-all.sh
│   ├── dexec
│   └── README.md               # Script usage reference
├── CLAUDE.md                    # Agent instructions (patterns, anti-patterns)
├── config/
│   ├── bashrc-additions        # Custom .bashrc content
│   └── ssh-config-template     # SSH config template
├── templates/                   # Starter devcontainer configs
│   ├── dotnet/
│   ├── node/
│   └── python/
└── wiki/                        # GitHub wiki source files
    ├── Home.md                  # Wiki landing page
    ├── Quick-Start.md           # Step-by-step setup guide
    ├── Bootstrap-Script.md      # Phase 1 script details
    ├── Install-Script.md        # Phase 2 script details
    ├── Bitbucket-Setup.md       # App password creation guide
    ├── Troubleshooting.md       # Common issues and solutions
    └── _Sidebar.md              # Wiki navigation sidebar
```

### Wiki Files

The `wiki/` directory contains source files for the [GitHub Wiki](../../wiki). To publish:

```bash
git clone https://github.com/digitalsoftwaresolutionsrepos/devstation-setup.wiki.git /tmp/wiki
cp ~/devstation-setup/wiki/*.md /tmp/wiki/
cd /tmp/wiki && git add . && git commit -m "Update docs" && git push
```

## Documentation

- [Wiki Home](../../wiki) - Full documentation
- [Quick Start](../../wiki/Quick-Start) - Step-by-step setup guide
- [Bootstrap Script](../../wiki/Bootstrap-Script) - Phase 1 details
- [Install Script](../../wiki/Install-Script) - Phase 2 details
- [Bitbucket Setup](../../wiki/Bitbucket-Setup) - Bitbucket authentication
- [AgentWatch WebRTC](../../wiki/AgentWatch-WebRTC) - WebRTC port configuration
- [Troubleshooting](../../wiki/Troubleshooting) - Common issues and fixes

### Local Docs

- [VM-SETUP.md](docs/VM-SETUP.md) - Manual VM setup instructions
- [SOFTWARE.md](docs/SOFTWARE.md) - Detailed software list
- [MOBAXTERM.md](docs/MOBAXTERM.md) - MobaXterm SSH configuration
- [AGENTWATCH.md](docs/AGENTWATCH.md) - AgentWatch WebRTC port configuration

## Claude Code Authentication

Claude Code credentials are shared across all containers by bind-mounting `~/.claude/` from the host. The base Docker image (`devstation-base:latest`) bakes `{"hasCompletedOnboarding": true}` into `~/.claude.json` so the onboarding wizard is skipped.

### Setup

1. Authenticate once on the host: `claude` (complete the login flow)
2. All containers automatically pick up credentials via the bind mount
3. Settings, plugins, statusline, and MCP servers are shared across all containers

### Important

- **Do NOT use named volumes** for `~/.claude/` — they diverge from the host and settings/statusline won't sync
- **Do NOT set `ANTHROPIC_API_KEY`** in `.env` (even empty) — it triggers API billing mode instead of using your Max/Pro subscription
- **Do NOT set `CLAUDE_CODE_OAUTH_TOKEN`** — same problem, triggers API billing mode

## Base Image

All repos use `FROM devstation-base:latest`, a kitchen-sink image containing:

- .NET 9, 8, and 6 SDKs
- Node.js 22 + npm
- Python 3.12 + pip
- Bun runtime
- Go 1.23.5
- Rust (rustup + cargo)
- AI CLIs: claude, gemini, codex, codexaw
- Playwright Chromium
- Stripe CLI, AWS CLI, doctl
- gitui, broot, Docker CLI

Build it with: `~/build-base-image.sh` (supports `--no-cache`)

## Post-Create Philosophy

Container rebuilds are designed to be **fast (seconds, not minutes)**. Post-create scripts only handle container-level setup — never project-level work.

All workspaces are **bind-mounted** from the host (`~/code/REPO` → `/home/vscode/REPO`). This means `node_modules/`, `bin/`, `obj/`, `.nuget/packages/`, `venv/`, and all project artifacts **persist across rebuilds**. Dependencies only need to be installed once (the first time, manually by the developer).

**Do:**
- System tuning (inotify limits, /tmp permissions, XDG_RUNTIME_DIR)
- Start PostgreSQL (init cluster if needed, create roles/databases)
- Fix top-level cache dir ownership with `stat` check — **never recursive `chown -R`**
- Start AgentWatch daemon (if installed)
- Install AI CLIs only if not already present (`command -v` guard)
- Handle `--stop` (no-op exit) and `--quick` (minimal startup) flags

**Don't:**
- `dotnet restore` — obj/bin persist on host via bind mount
- `npm install` / `npm ci` — node_modules persist on host
- `pip install` — venv persists on host
- `cargo install` — cargo binaries persist on host
- `dotnet ef database update` — servers auto-apply migrations on startup
- `dotnet tool install` — tools persist in ~/.dotnet/tools
- Recursive `chown -R` on cache directories — these have tens of thousands of files

See `CLAUDE.md` for copy-paste-ready code patterns and anti-patterns.

## AgentWatch WebRTC

AgentWatch uses WebRTC to stream terminal sessions from devcontainers. Each repo needs three environment variables (`AGENT_WATCH_PORT_RANGE_START`, `AGENT_WATCH_PORT_RANGE_END`, `AGENT_WATCH_HOST_IP`) in `containerEnv` and a matching 1:1 UDP port mapping in `runArgs`. Every repo gets a unique, non-overlapping 50-port block starting at 30000.

See [docs/AGENTWATCH.md](docs/AGENTWATCH.md) for the full port allocation registry, configuration examples, and setup instructions for new repos.

## Bind Mounts

Every container bind-mounts these from the host for persistence:

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `~/.claude/` | `/home/vscode/.claude/` | Claude Code auth, settings, plugins |
| `~/.codex/` | `/home/vscode/.codex/` | Codex CLI config |
| `~/.config/gh/` | `/home/vscode/.config/gh/` | GitHub CLI auth (shared via `gh auth setup-git`) |
| `~/bin/` | `/home/vscode/bin/` | Custom scripts/shortcuts (first in PATH) |
| `~/code/REPO/` | `/home/vscode/REPO/` | Workspace (auto via workspaceMount) |

These must be declared in every `devcontainer.json` under `runArgs`, and the directories must be pre-created in `initializeCommand`:

```json
"initializeCommand": "bash -lc '...mkdir -p \"$HOME/.claude\" \"$HOME/.codex\" \"$HOME/.config/gh\" \"$HOME/bin\"...'"
```

### Repo Dockerfiles

All repo Dockerfiles should be a single line:
```dockerfile
FROM devstation-base:latest
```
The base image contains all tools. Only add repo-specific system packages if absolutely required.

## Devcontainer Templates

The `templates/` directory contains starter devcontainer configurations:

- **dotnet/** - .NET with PostgreSQL, EF Core, AI CLIs
- **node/** - Node.js with npm, AI CLIs
- **python/** - Python 3.12 with pip, AI CLIs

Copy a template to your project:
```bash
cp -r ~/devstation-setup/templates/dotnet/.devcontainer ./
```

## Requirements

- Ubuntu 20.04+ or Debian 11+
- sudo access
- Internet connection
- 4+ CPU cores (recommended)
- 16GB+ RAM (8GB minimum)
- 50GB+ disk space

## License

MIT
