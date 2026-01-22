#!/bin/bash
set -e

# Install gitui - Rust-based terminal git UI
# Fetches the latest release from GitHub and installs to /usr/local/bin
#
# This script can be run standalone or the logic is inlined in Dockerfiles
# for devcontainer builds where COPY context may not include this directory.

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) GITUI_FILE="gitui-linux-x86_64.tar.gz" ;;
  aarch64) GITUI_FILE="gitui-linux-aarch64.tar.gz" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

LATEST_URL=$(curl -sL https://api.github.com/repos/extrawurst/gitui/releases/latest \
  | grep "browser_download_url.*${GITUI_FILE}" \
  | cut -d '"' -f 4)

curl -sL "$LATEST_URL" | tar xz -C /usr/local/bin
chmod +x /usr/local/bin/gitui
echo "gitui installed: $(gitui --version)"
