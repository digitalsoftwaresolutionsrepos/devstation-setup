# Troubleshooting

Common issues and solutions for devstation setup.

## Bootstrap Script Issues

### "Unsupported OS" Error

```
[ERROR] Unsupported OS: fedora
[ERROR] This bootstrap script requires Ubuntu or Debian.
```

**Solution:** The bootstrap script only supports Ubuntu and Debian. For other distributions, manually install the dependencies or adapt the script.

### Docker Permission Denied

```
Got permission denied while trying to connect to the Docker daemon socket
```

**Cause:** Your user isn't in the docker group, or you haven't logged out/in since bootstrap.

**Solution:**
```bash
# Option 1: Log out and back in
exit
# SSH back in

# Option 2: Activate group without logout
newgrp docker

# Verify
docker ps
```

### GPG Key Errors

```
GPG error: https://download.docker.com/linux/ubuntu ... NO_PUBKEY
```

**Solution:**
```bash
# Remove old keys and re-run bootstrap
sudo rm -f /etc/apt/keyrings/docker.gpg
sudo rm -f /usr/share/keyrings/githubcli-archive-keyring.gpg
~/devstation-setup/bootstrap.sh
```

### Node.js Installation Fails

```
E: Unable to locate package nodejs
```

**Solution:**
```bash
# Remove NodeSource list and retry
sudo rm /etc/apt/sources.list.d/nodesource.list
~/devstation-setup/bootstrap.sh
```

### "npm: command not found" After Bootstrap

**Cause:** npm is included with Node.js but PATH may not be updated.

**Solution:**
```bash
source ~/.bashrc
# or
hash -r
```

## Install Script Issues

### Prerequisites Missing

```
[ERROR] Missing prerequisites: docker gh (GitHub CLI)
```

**Solution:** Run the bootstrap script first:
```bash
curl -sSL https://raw.githubusercontent.com/canuszczyk/devstation-setup/master/bootstrap.sh | bash
# Log out and back in
~/devstation-setup/install.sh
```

### GitHub CLI Not Authenticated

```
[WARN] GitHub CLI is not authenticated
```

**Solution:**
```bash
gh auth login
# Choose: GitHub.com > HTTPS > Login with a web browser
# Follow the prompts
```

### No Repos Found (GitHub)

```
[WARN] No repos found for myorg
```

**Possible causes:**
1. Organization name misspelled
2. No access to the organization
3. Private org requires SSO authentication

**Solution:**
```bash
# Check your access
gh repo list myorg --limit 5

# If SSO required
gh auth refresh -h github.com -s read:org
```

### No Devcontainer Repos Found

```
[WARN] No repos with .devcontainer/ found
```

**Cause:** Repos exist but none have `.devcontainer/` directories.

**Solution:**
- Verify at least one repo has a `.devcontainer/devcontainer.json`
- Check the default branch (script only checks default branch)

### Bitbucket Authentication Failed

```
[ERROR] Bitbucket authentication failed. Please check your credentials.
```

**Solutions:**
1. Verify username (Bitbucket username, not email)
2. Verify API token was copied correctly
3. Verify workspace name matches URL exactly
4. Check API token has "Repositories: Read" scope
5. **If using old app password:** Create an API token instead (app passwords deprecated Sep 2025)

See [[Bitbucket Setup]] for detailed instructions.

### Clone Fails with 403

```
fatal: unable to access '...': The requested URL returned error: 403
```

**Cause:** Insufficient permissions or wrong credentials.

**Solution:**
```bash
# For GitHub - re-authenticate
gh auth logout
gh auth login

# For Bitbucket - check API token scopes
# Ensure "Repositories: Read" scope is enabled
```

## Devcontainer Issues

### Container Won't Start

```
No running container found for: /home/user/code/myrepo
```

**Solution:**
```bash
# Build/rebuild the container
~/devcontainer-rebuild.sh ~/code/myrepo

# Check Docker logs
docker logs $(docker ps -lq)
```

### "devcontainer: command not found"

```
devcontainer: command not found
```

**Solution:**
```bash
# Reinstall devcontainer CLI
sudo npm install -g @devcontainers/cli

# Verify
devcontainer --version
```

### Build Fails with Cache Issues

**Solution:**
```bash
# Force rebuild with no cache
~/devcontainer-rebuild.sh ~/code/myrepo --force
```

### Container Tools Missing

```
Verification FAILED: MISSING: dotnet node
```

**Cause:** devcontainer.json postCreateCommand failed or tools not in PATH.

**Solution:**
```bash
# Check container logs
docker logs $(docker ps -lq)

# Rebuild with force
~/devcontainer-rebuild.sh ~/code/myrepo --force
```

## Shell Integration Issues

### Aliases Not Working

```
dexec-myrepo: command not found
```

**Solution:**
```bash
# Reload bashrc
source ~/.bashrc

# Or regenerate aliases by re-running install.sh
~/devstation-setup/install.sh
```

### dexec Function Not Found

```
dexec: command not found
```

**Solution:**
```bash
# Check if bashrc additions are present
grep "DEVSTATION CUSTOMIZATIONS" ~/.bashrc

# If missing, re-run bootstrap
~/devstation-setup/bootstrap.sh
source ~/.bashrc
```

## Credential Issues

### Git Asks for Password Every Time

**Cause:** Credential helper not configured.

**Solution:**
```bash
git config --global credential.helper store
```

### Wrong Credentials Stored

```bash
# View stored credentials
cat ~/.git-credentials

# Remove and re-authenticate
rm ~/.git-credentials

# For GitHub
gh auth logout
gh auth login

# For Bitbucket - re-run install.sh
~/devstation-setup/install.sh
```

## Getting Help

If you encounter an issue not covered here:

1. Check the [GitHub Issues](https://github.com/canuszczyk/devstation-setup/issues)
2. Search for similar problems
3. Open a new issue with:
   - OS version (`cat /etc/os-release`)
   - Error message (full output)
   - Steps to reproduce
