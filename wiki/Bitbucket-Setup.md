# Bitbucket Setup

This guide explains how to configure Bitbucket access for the devstation install script.

> **IMPORTANT: App Passwords Deprecated**
>
> As of September 9, 2025, Bitbucket app passwords can no longer be created.
> Use **API tokens with scopes** instead. Existing app passwords will be
> disabled on June 9, 2026. Migrate any integrations before then.

## Overview

Unlike GitHub (which has its own CLI), Bitbucket access uses:
- **API Tokens** for authentication (replaces app passwords)
- **REST API** for repository discovery
- **HTTPS with embedded credentials** for cloning

## Creating an API Token

### Step 1: Open API Token Settings

1. Log in to [bitbucket.org](https://bitbucket.org)
2. Click your avatar (bottom-left) → **Personal settings**
3. Under **Access management**, click **API tokens**
4. Or go directly to: https://bitbucket.org/account/settings/api-tokens/

### Step 2: Create New API Token

1. Click **Create token**
2. Enter a name (e.g., "devstation-setup")
3. Select scopes:

| Scope | Required | Purpose |
|-------|----------|---------|
| **Repositories: Read** | Yes | List repos, check for .devcontainer |
| Repositories: Write | No | Only needed if pushing changes |
| Account: Read | No | Not needed |

4. Click **Create**
5. **Copy the token immediately** - it won't be shown again!

### Step 3: Store Securely

Save the API token somewhere secure (password manager, encrypted notes). You'll need it when running `install.sh`.

## Finding Your Workspace Name

Your workspace name is in your Bitbucket URLs:

```
https://bitbucket.org/WORKSPACE_NAME/repo-name
                      ^^^^^^^^^^^^^^
```

To find it:
1. Go to any repository in your organization
2. Look at the URL
3. The workspace is the first path segment after `bitbucket.org`

Common patterns:
- Personal account: Usually your username
- Team/Organization: The organization's slug (lowercase, no spaces)

## Using with install.sh

When prompted during `install.sh`:

```
--- Bitbucket Repository Setup ---
Configure Bitbucket repos? (y/N): y

Bitbucket authentication requires:
  - Your Bitbucket username
  - An API token (create at: https://bitbucket.org/account/settings/api-tokens/)
  - Your workspace name

API token scopes needed: Repositories (Read)

NOTE: App passwords deprecated Sep 2025, disabled Jun 2026. Use API tokens.

Bitbucket username: jsmith
API token: [paste your API token - hidden]
Workspace name: mycompany

[INFO] Testing Bitbucket authentication...
[OK] Bitbucket authentication successful
```

## How Credentials Are Stored

### During Install

Credentials are embedded in the clone URL:
```bash
git clone https://jsmith:API_TOKEN@bitbucket.org/mycompany/repo.git
```

### After Install

The bootstrap script configures git credential store:
```bash
git config --global credential.helper store
```

After the first successful clone, credentials are saved to `~/.git-credentials`:
```
https://jsmith:API_TOKEN@bitbucket.org
```

Future git operations (pull, fetch) will use these stored credentials automatically.

### Security Considerations

The credential store saves passwords in **plain text**. This is acceptable for:
- Development VMs
- Personal workstations
- Ephemeral cloud instances

**Not recommended for:**
- Shared systems
- Production servers
- Systems with multiple users

For enhanced security, consider:
- Using SSH keys instead (requires manual setup)
- Encrypting your home directory
- Using a credential manager like `git-credential-libsecret`

## Multiple Workspaces

To clone from multiple Bitbucket workspaces, run `install.sh` multiple times:

```bash
# First run - workspace A
~/devstation-setup/install.sh
# Choose Bitbucket, enter workspace-a credentials

# Second run - workspace B
~/devstation-setup/install.sh
# Choose Bitbucket, enter workspace-b credentials
```

Existing repos are skipped, and aliases are regenerated to include all repos.

## Troubleshooting

### Authentication Failed

```
[ERROR] Bitbucket authentication failed. Please check your credentials.
```

Verify:
1. Username is correct (your Bitbucket username, not email)
2. API token was copied correctly (no extra spaces)
3. Workspace name is correct (case-sensitive)
4. API token has "Repositories: Read" scope

### No Repos Found

```
[WARN] No repos found in workspace mycompany
```

Check:
1. Workspace name is spelled correctly
2. Your account has access to repos in that workspace
3. The workspace has at least one repository

### No Devcontainer Repos Found

```
[WARN] No repos with .devcontainer/ found
```

This means repos exist but none have a `.devcontainer/` directory on the default branch.

### Rate Limiting

Bitbucket API has rate limits. If you hit them:
1. Wait a few minutes
2. Re-run `install.sh`

### Credential Issues After Install

If git operations fail after install:

```bash
# Check stored credentials
cat ~/.git-credentials

# Remove and re-authenticate
git config --global --unset credential.helper
rm ~/.git-credentials
git config --global credential.helper store

# Re-run install.sh for the affected workspace
~/devstation-setup/install.sh
```

## API Token vs SSH Keys

| Feature | API Token | SSH Key |
|---------|-----------|---------|
| Setup complexity | Simple | More steps |
| Storage | Plain text file | Encrypted key file |
| Multiple accounts | One token per workspace | One key for all |
| Rotation | Easy to regenerate | Requires key replacement |
| 2FA compatible | Yes | Yes |
| Scoped permissions | Yes | No (full access) |

API tokens are recommended for devstation because:
- Simpler automated setup
- Works well with git credential store
- Easy to revoke/regenerate
- Scoped permissions (read-only possible)
