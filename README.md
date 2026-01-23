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
curl -sSL https://raw.githubusercontent.com/canuszczyk/devstation-setup/master/bootstrap.sh | bash
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
| `~/devcontainer-cleanup.sh` | Clean up stopped containers/images |
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
git clone https://github.com/canuszczyk/devstation-setup.wiki.git /tmp/wiki
cp ~/devstation-setup/wiki/*.md /tmp/wiki/
cd /tmp/wiki && git add . && git commit -m "Update docs" && git push
```

## Documentation

- [Wiki Home](../../wiki) - Full documentation
- [Quick Start](../../wiki/Quick-Start) - Step-by-step setup guide
- [Bootstrap Script](../../wiki/Bootstrap-Script) - Phase 1 details
- [Install Script](../../wiki/Install-Script) - Phase 2 details
- [Bitbucket Setup](../../wiki/Bitbucket-Setup) - Bitbucket authentication
- [Troubleshooting](../../wiki/Troubleshooting) - Common issues and fixes

### Local Docs

- [VM-SETUP.md](docs/VM-SETUP.md) - Manual VM setup instructions
- [SOFTWARE.md](docs/SOFTWARE.md) - Detailed software list
- [MOBAXTERM.md](docs/MOBAXTERM.md) - MobaXterm SSH configuration

## Devcontainer Templates

The `templates/` directory contains starter devcontainer configurations:

- **dotnet/** - .NET 9 with PostgreSQL, EF Core, AI CLIs
- **node/** - Node.js 20 with npm, Playwright, AI CLIs
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
