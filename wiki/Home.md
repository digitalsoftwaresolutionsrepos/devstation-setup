# Devstation Setup

Devstation Setup is a two-phase provisioning system for setting up development servers with devcontainers. It supports cloning repositories from both GitHub and Bitbucket.

## Overview

| Phase | Script | Purpose |
|-------|--------|---------|
| 1 | `bootstrap.sh` | Install core dependencies (Docker, Node.js, CLI tools) |
| 2 | `install.sh` | Configure and clone repos from GitHub/Bitbucket |

## Quick Start

```bash
# Phase 1: Bootstrap (run on fresh Ubuntu/Debian server)
curl -sSL https://raw.githubusercontent.com/digitalsoftwaresolutionsrepos/devstation-setup/master/bootstrap.sh | bash

# Log out and back in (for Docker group membership)
exit

# Phase 2: Configure repos
~/devstation-setup/install.sh
```

## What Gets Installed

### Phase 1 (bootstrap.sh)
- Base packages: curl, git, git-lfs, build-essential, jq
- Docker CE + Docker Compose plugin
- Node.js 20 LTS
- GitHub CLI (`gh`)
- `@devcontainers/cli`
- Management scripts symlinked to `~/`
- Shell customizations in `~/.bashrc`

### Phase 2 (install.sh)
- GitHub authentication and repo discovery
- Bitbucket authentication and repo discovery
- Clone selected repos to `~/code/`
- Generate `dexec-{repo}` shell aliases
- Optional: Build devcontainers

## Navigation

- [[Quick Start]] - Step-by-step setup guide
- [[Bootstrap Script]] - Phase 1 details
- [[Install Script]] - Phase 2 details
- [[Bitbucket Setup]] - Bitbucket-specific instructions
- [[AgentWatch WebRTC|AgentWatch-WebRTC]] - WebRTC port configuration for containers
- [[Troubleshooting]] - Common issues and solutions

## Requirements

- Ubuntu 20.04+ or Debian 11+
- sudo access
- Internet connection
