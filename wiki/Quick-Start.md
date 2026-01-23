# Quick Start Guide

This guide walks you through setting up a fresh Ubuntu/Debian server as a devcontainer development station.

## Prerequisites

- Fresh Ubuntu 20.04+ or Debian 11+ server
- User account with sudo access
- Internet connection

## Step 1: Run Bootstrap Script

On your fresh server, run the bootstrap script:

```bash
curl -sSL https://raw.githubusercontent.com/canuszczyk/devstation-setup/master/bootstrap.sh | bash
```

This installs all dependencies and takes 5-10 minutes depending on your connection speed.

**What happens:**
1. Validates your OS (Ubuntu/Debian only)
2. Installs base packages (curl, git, build-essential, etc.)
3. Installs Docker CE with Compose plugin
4. Installs Node.js 20 LTS
5. Installs GitHub CLI
6. Installs devcontainer CLI
7. Clones devstation-setup repo to `~/devstation-setup`
8. Symlinks management scripts to `~/`
9. Adds shell customizations to `~/.bashrc`

## Step 2: Log Out and Back In

After bootstrap completes, log out and back in to activate Docker group membership:

```bash
exit
# SSH back in or start a new terminal session
```

Verify Docker works without sudo:

```bash
docker ps
```

## Step 3: Run Install Script

Now configure your repositories:

```bash
~/devstation-setup/install.sh
```

The script will interactively guide you through:

### GitHub Setup (optional)

```
--- GitHub Repository Setup ---
Configure GitHub repos? (y/N): y
```

If you choose yes:
1. If not authenticated, you'll be prompted to run `gh auth login`
2. Enter your GitHub username or organization name
3. Script discovers repos with `.devcontainer/` directories
4. Use the interactive selector to choose repos to clone

### Bitbucket Setup (optional)

```
--- Bitbucket Repository Setup ---
Configure Bitbucket repos? (y/N): y
```

If you choose yes:
1. Enter your Bitbucket username
2. Enter your API token (see [[Bitbucket Setup]])
3. Enter your workspace name
4. Script discovers repos with `.devcontainer/` directories
5. Use the interactive selector to choose repos to clone

### Build Devcontainers (optional)

```
Build devcontainers now? This can take a while. (y/N):
```

Choose `y` to build all containers immediately, or `n` to build later.

## Step 4: Start Using Devcontainers

Reload your shell to get the new aliases:

```bash
source ~/.bashrc
```

### Build containers (if you skipped earlier)

```bash
~/devcontainer-rebuild.sh ~/code
```

### Shell into a container

```bash
# Using the dexec script
~/dexec ~/code/MyRepo

# Or using generated aliases
dexec-myrepo
```

### Other useful commands

```bash
# Stop all devcontainers
dc-stop-all

# Start all devcontainers
dc-start-all

# Clean up unused containers/images
dc-cleanup
```

## Next Steps

- See [[Bootstrap Script]] for bootstrap.sh details
- See [[Install Script]] for install.sh details
- See [[Bitbucket Setup]] for Bitbucket app password creation
- See [[Troubleshooting]] if you encounter issues
