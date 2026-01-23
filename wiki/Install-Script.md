# Install Script

The `install.sh` script is Phase 2 of the devstation setup process. It configures and clones repositories from GitHub and/or Bitbucket.

## Prerequisites

Before running `install.sh`, you must complete Phase 1 by running `bootstrap.sh`. The script checks for:

- Docker
- GitHub CLI (`gh`)
- Node.js
- Devcontainer CLI

If any are missing, you'll see:

```
[ERROR] Missing prerequisites: docker gh (GitHub CLI)

Please run the bootstrap script first:
  curl -sSL https://raw.githubusercontent.com/canuszczyk/devstation-setup/master/bootstrap.sh | bash
```

## Usage

```bash
~/devstation-setup/install.sh
```

The script is fully interactive - no command-line arguments needed.

## Workflow

### 1. Prerequisite Check

Verifies all required tools are installed.

```
[OK] All prerequisites installed
```

### 2. GitHub Setup (Optional)

```
--- GitHub Repository Setup ---
Configure GitHub repos? (y/N):
```

If you choose `y`:

#### Authentication

If not already authenticated:
```
[WARN] GitHub CLI is not authenticated

Please run: gh auth login
Choose: GitHub.com > HTTPS > Authenticate with a web browser

Press Enter after you've authenticated, or type 'skip' to skip GitHub setup:
```

#### Organization/User Selection

```
Enter GitHub username or organization: mycompany
```

#### Repository Discovery

The script scans all non-archived repos for `.devcontainer/` directories:

```
[INFO] Searching for repos with .devcontainer/ in mycompany...
  Checking repo 15/42: backend-api
[OK] Found 8 repos with devcontainer configs
```

#### Interactive Selection

```
Select repos to clone from GitHub (mycompany):
(Use number to toggle, 'a' for all, 'n' for none, Enter to confirm)

  1. [ ] frontend-app
  2. [ ] backend-api
  3. [x] mobile-app
  4. [ ] infrastructure

Selection (1-4/a/n/Enter):
```

Commands:
- `1-N` - Toggle individual repos
- `a` - Select all
- `n` - Select none
- `Enter` - Confirm and proceed

#### Cloning

```
[INFO] Cloning 3 repos to /home/user/code...
[INFO]   Cloning frontend-app...
[INFO]   Cloning backend-api...
[INFO]   mobile-app - already exists, skipping
[OK] GitHub repos cloned
```

### 3. Bitbucket Setup (Optional)

```
--- Bitbucket Repository Setup ---
Configure Bitbucket repos? (y/N):
```

If you choose `y`:

#### Authentication

```
Bitbucket authentication requires:
  - Your Bitbucket username
  - An API token (create at: https://bitbucket.org/account/settings/api-tokens/)
  - Your workspace name

API token scopes needed: Repositories (Read)

NOTE: App passwords deprecated Sep 2025, disabled Jun 2026. Use API tokens.

Bitbucket username: jsmith
API token: ****
Workspace name: mycompany

[INFO] Testing Bitbucket authentication...
[OK] Bitbucket authentication successful
```

See [[Bitbucket Setup]] for details on creating API tokens.

#### Repository Discovery

```
[INFO] Searching for repos with .devcontainer/ in mycompany...
  Checking repo 23/45: legacy-service
[OK] Found 5 repos with devcontainer configs
```

#### Interactive Selection

Same interface as GitHub - toggle repos, then confirm.

#### Cloning

Repos are cloned with embedded credentials:

```bash
git clone https://user:apppassword@bitbucket.org/workspace/repo.git
```

The git credential store (configured by bootstrap.sh) saves these for future operations.

### 4. Alias Generation

For each cloned repo with a `.devcontainer/` directory:

```
[INFO] Generating repo-specific aliases...
[OK] Generated dexec aliases for repos in ~/code
```

Aliases are added to `~/.bashrc`:

```bash
# === GENERATED REPO ALIASES ===
alias dexec-frontend-app='dexec ~/code/frontend-app'
alias dexec-backend-api='dexec ~/code/backend-api'
# === GENERATED REPO ALIASES END ===
```

### 5. Optional Build

```
Build devcontainers now? This can take a while. (y/N):
```

If `y`, runs:
```bash
~/devcontainer-rebuild.sh ~/code --fast
```

The `--fast` flag skips AI CLI and Playwright installation for faster builds.

## Exit Message

```
==============================================
  Setup Complete!
==============================================

Next steps:
  1. Run: source ~/.bashrc
  2. Build containers: ~/devcontainer-rebuild.sh ~/code
  3. Shell into a container: ~/dexec ~/code/MyRepo

See ~/devstation-setup/docs/ for more documentation.
```

## Re-running

The script can be run multiple times:
- Skips repos that already exist in `~/code/`
- Regenerates aliases (replaces existing alias block)
- You can add repos from additional GitHub orgs or Bitbucket workspaces

## Directory Structure

After running:

```
~/
├── code/
│   ├── repo1/
│   │   └── .devcontainer/
│   ├── repo2/
│   │   └── .devcontainer/
│   └── repo3/
│       └── .devcontainer/
├── devstation-setup/
│   ├── bootstrap.sh
│   ├── install.sh
│   └── scripts/
├── dexec -> devstation-setup/scripts/dexec
├── devcontainer-rebuild.sh -> devstation-setup/scripts/...
└── .bashrc (with aliases)
```
