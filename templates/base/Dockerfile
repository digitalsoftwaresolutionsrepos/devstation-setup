# =============================================================================
# devstation-base: Kitchen-sink base image for all devcontainers
# =============================================================================
# Built once, cached locally. Each repo's Dockerfile becomes:
#   FROM devstation-base:latest
#
# Base: .NET 9 SDK (RepositoryCloner needs it); .NET 6 + 8 SDKs installed alongside.
# Union of tools from: AgentWatch, Gradewave, DeploymentInfra, codex, RepositoryCloner
# =============================================================================

FROM mcr.microsoft.com/dotnet/sdk:9.0

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# [1] System packages (union of all 5 repos)
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [1/21] Installing system packages…" && \
    apt-get update && apt-get install -y \
    sudo nano screen locate lsof curl gnupg wget ca-certificates apt-transport-https \
    software-properties-common procps locales iproute2 \
    python3 python3-pip python3-venv \
    postgresql postgresql-contrib postgresql-client \
    openssh-client git git-lfs unzip zip jq gettext gettext-base \
    pkg-config libssl-dev zstd && \
    git lfs install --system && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "✓ [1/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [2] GitHub CLI (gh)
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [2/21] Installing GitHub CLI…" && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list >/dev/null && \
    apt-get update && apt-get install -y gh && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "✓ [2/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [3] Docker CLI + Compose plugin (DeploymentInfra)
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [3/21] Installing Docker CLI + Compose…" && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    . /etc/os-release && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "✓ [3/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [4] Playwright/Chrome system deps + Google Chrome
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [4/21] Installing Playwright/Chrome deps + Google Chrome…" && \
    apt-get update && apt-get install -y \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libgbm1 libasound2 libpango-1.0-0 libcairo2 && \
    curl -fsSL -o /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get install -y /tmp/chrome.deb && \
    rm /tmp/chrome.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "✓ [4/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [5] .NET 6 + 8 SDKs (goldrushcitykiosk, httpsasmodule, abstractcorenugetpackages need 6.0;
#     AgentWatch, Gradewave, DeploymentInfra, codex need 8.0; base image provides 9.0)
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [5/21] Installing .NET 6 + 8 SDKs…" && \
    curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh --channel 6.0 --install-dir /usr/share/dotnet && \
    /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet && \
    rm /tmp/dotnet-install.sh && \
    echo "✓ [5/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [6] Node.js 22.11.0 (official binary)
# ---------------------------------------------------------------------------
ARG NODE_VERSION=22.11.0
RUN _start=$SECONDS && echo "▶ [6/21] Installing Node.js ${NODE_VERSION}…" && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz && \
    mkdir -p /usr/local/lib/nodejs && \
    tar -xJf /tmp/node.tar.xz -C /usr/local/lib/nodejs && \
    rm /tmp/node.tar.xz && \
    ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/node /usr/local/bin/node && \
    ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/npm /usr/local/bin/npm && \
    ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/npx /usr/local/bin/npx && \
    echo "✓ [6/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [7] Bun 1.1.34 (AgentWatch, codex)
# ---------------------------------------------------------------------------
ARG BUN_VERSION=1.1.34
RUN _start=$SECONDS && echo "▶ [7/21] Installing Bun ${BUN_VERSION}…" && \
    curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local/bun bash -s "bun-v${BUN_VERSION}" && \
    ln -sf /usr/local/bun/bin/bun /usr/local/bin/bun && \
    chown -R root:root /usr/local/bun && \
    echo "✓ [7/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [8] Go 1.23.5 (AgentWatch, DeploymentInfra)
# ---------------------------------------------------------------------------
ARG GO_VERSION=1.23.5
RUN _start=$SECONDS && echo "▶ [8/21] Installing Go ${GO_VERSION}…" && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xzf - && \
    echo "✓ [8/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [9] Global npm: cross-env, pnpm
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [9/21] Installing global npm packages (cross-env, pnpm)…" && \
    npm install -g cross-env pnpm && \
    echo "✓ [9/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [10] Stripe CLI v1.32.0 (AgentWatch, RepositoryCloner)
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [10/21] Installing Stripe CLI…" && \
    curl -L https://github.com/stripe/stripe-cli/releases/download/v1.32.0/stripe_1.32.0_linux_x86_64.tar.gz -o /tmp/stripe.tar.gz && \
    tar -xzf /tmp/stripe.tar.gz -C /tmp && \
    mv /tmp/stripe /usr/local/bin/stripe && \
    rm /tmp/stripe.tar.gz && \
    echo "✓ [10/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [11] AWS CLI v2 (Gradewave, DeploymentInfra)
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [11/21] Installing AWS CLI v2…" && \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws && \
    echo "✓ [11/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [12] doctl v1.147.0 (DeploymentInfra)
# ---------------------------------------------------------------------------
ARG DOCTL_VERSION=1.147.0
RUN _start=$SECONDS && echo "▶ [12/21] Installing doctl ${DOCTL_VERSION}…" && \
    curl -fsSL -o /tmp/doctl.tgz "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz" && \
    tar -xzf /tmp/doctl.tgz -C /tmp && \
    mv /tmp/doctl /usr/local/bin/doctl && \
    chmod +x /usr/local/bin/doctl && \
    rm -f /tmp/doctl.tgz && \
    echo "✓ [12/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [12b] Terraform (DeploymentInfra, general IaC)
# ---------------------------------------------------------------------------
ARG TERRAFORM_VERSION=1.12.1
RUN _start=$SECONDS && echo "▶ [12b] Installing Terraform ${TERRAFORM_VERSION}…" && \
    curl -fsSL -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
    unzip -q /tmp/terraform.zip -d /tmp && \
    mv /tmp/terraform /usr/local/bin/terraform && \
    chmod +x /usr/local/bin/terraform && \
    rm -f /tmp/terraform.zip && \
    echo "✓ [12b] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [13] SSH: GitHub host key
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [13/21] Adding GitHub SSH host key…" && \
    ssh-keyscan -H github.com >> /etc/ssh/ssh_known_hosts 2>/dev/null || true && \
    echo "✓ [13/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [14] PostgreSQL path symlinks
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [14/21] Setting up PostgreSQL path symlinks…" && \
    bash -lc 'if [ -d /usr/lib/postgresql ]; then \
      PG_VER=$(ls /usr/lib/postgresql | sort -V | tail -1); \
      ln -sf /usr/lib/postgresql/${PG_VER}/bin/* /usr/local/bin/; \
      printf "export PATH=/usr/lib/postgresql/%s/bin:\$PATH\n" "$PG_VER" > /etc/profile.d/pg-path.sh; \
    fi' && \
    echo "✓ [14/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [15] gitui (latest from GitHub)
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [15/21] Installing gitui…" && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64) GITUI_FILE="gitui-linux-x86_64.tar.gz" ;; \
      aarch64) GITUI_FILE="gitui-linux-aarch64.tar.gz" ;; \
      *) echo "Unsupported arch: $ARCH"; exit 1 ;; \
    esac && \
    LATEST_URL=$(curl -sL https://api.github.com/repos/extrawurst/gitui/releases/latest \
      | grep "browser_download_url.*${GITUI_FILE}" \
      | cut -d '"' -f 4) && \
    curl -sL "$LATEST_URL" | tar xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/gitui && \
    echo "✓ [15/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [16] broot
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [16/21] Installing broot…" && \
    curl -sL "https://dystroy.org/broot/download/x86_64-linux/broot" -o /usr/local/bin/broot && \
    chmod +x /usr/local/bin/broot && \
    echo "✓ [16/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [17] vi -> nano symlink
# ---------------------------------------------------------------------------
RUN echo "▶ [17/21] Symlinking vi to nano…" && \
    ln -sf /usr/bin/nano /usr/local/bin/vi && \
    echo "✓ [17/21] done"

# ---------------------------------------------------------------------------
# [18] User setup: vscode UID 1000, sudo, docker group, /run/user/1000
# ---------------------------------------------------------------------------
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN _start=$SECONDS && echo "▶ [18/21] Creating user ${USERNAME} (UID ${USER_UID})…" && \
    groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME && \
    groupadd -f docker && \
    usermod -aG docker $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    mkdir -p /run/user/${USER_UID} && \
    chown ${USERNAME}:${USERNAME} /run/user/${USER_UID} && \
    chmod 700 /run/user/${USER_UID} && \
    echo "✓ [18/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [18.5] systemd: configure for container use
# ---------------------------------------------------------------------------
RUN systemctl mask -- \
      systemd-resolved.service \
      systemd-networkd.service \
      systemd-networkd-wait-online.service \
      systemd-timesyncd.service \
      systemd-logind.service \
      systemd-remount-fs.service \
      systemd-tmpfiles-setup.service \
      getty.target \
      console-getty.service \
      sys-kernel-config.mount \
      sys-kernel-debug.mount \
      sys-kernel-tracing.mount \
      dev-hugepages.mount \
      dev-mqueue.mount && \
    mkdir -p /etc/systemd/journald.conf.d && \
    printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=64M\nForwardToConsole=no\n' \
      > /etc/systemd/journald.conf.d/container.conf

# ---------------------------------------------------------------------------
# [19] ENV: PATH, NPM_CONFIG_CACHE/PREFIX, DOTNET_ROOT, LANG, etc.
# ---------------------------------------------------------------------------
ENV NPM_CONFIG_CACHE=/home/${USERNAME}/.npm
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global
ENV CODEXAW_PREFIX=/home/${USERNAME}/.npm-global-codexaw
ENV DOTNET_ROOT=/usr/share/dotnet
ENV NODE_VERSION=22.11.0
ENV NODE_HOME=/usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64
ENV BUN_INSTALL=/usr/local/bun
ENV XDG_RUNTIME_DIR=/run/user/${USER_UID}
ENV LANG=C.UTF-8 LANGUAGE=en_US:en LC_ALL=C.UTF-8
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV NODE_PATH=/home/${USERNAME}/.npm-global/lib/node_modules

# Unified PATH: bun, node, dotnet, go, cargo, user npm, dotnet tools, claude
ENV PATH="/home/${USERNAME}/bin:/home/${USERNAME}/.local/bin:/home/${USERNAME}/.cargo/bin:${BUN_INSTALL}/bin:${NODE_HOME}/bin:${DOTNET_ROOT}:/usr/local/go/bin:/usr/local/bin:${PATH}:/home/${USERNAME}/.dotnet/tools:/home/${USERNAME}/.npm-global/bin:${CODEXAW_PREFIX}/bin:/home/${USERNAME}/.claude/local/bin"

# ---------------------------------------------------------------------------
# [20] (as vscode) Rust toolchain + clippy + rustfmt + aarch64 target (codex)
# ---------------------------------------------------------------------------
USER $USERNAME

RUN _start=$SECONDS && echo "▶ [20/21] Installing Rust toolchain…" && \
    curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal && \
    ~/.cargo/bin/rustup component add clippy rustfmt && \
    ~/.cargo/bin/rustup target add aarch64-unknown-linux-musl && \
    echo "✓ [20/21] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [21] (as vscode) npm prefix config, state directories
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [21/22] Configuring user directories…" && \
    mkdir -p ~/.npm-global/bin ~/.npm ~/.npm-global-codexaw ~/.cache/ms-playwright \
             ~/.codex/sessions ~/.claude ~/.gemini ~/.config && \
    npm config set prefix "$HOME/.npm-global" && \
    echo "✓ [21/22] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [22] (as vscode) Pre-install AI CLIs (claude, codex)
# ---------------------------------------------------------------------------
RUN echo '{"hasCompletedOnboarding": true}' > /home/${USERNAME}/.claude.json && \
    echo "✓ [22/23] Baked hasCompletedOnboarding into .claude.json"

# ---------------------------------------------------------------------------
# [23] (as vscode) Pre-install AI CLIs (claude, gemini, codex, codexaw)
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [23/23] Installing AI CLIs (claude, gemini, codex, codexaw)…" && \
    curl -fsSL https://claude.ai/install.sh | bash && \
    npm install -g @openai/codex @google/gemini-cli && \
    NPM_CONFIG_PREFIX=${CODEXAW_PREFIX} npm install -g https://github.com/digitalsoftwaresolutionsrepos/codex/releases/latest/download/codexaw.tgz && \
    if [ -x "${CODEXAW_PREFIX}/bin/codex" ]; then mv "${CODEXAW_PREFIX}/bin/codex" "${CODEXAW_PREFIX}/bin/codexaw"; fi && \
    echo "✓ [23/24] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# [24] (as vscode) Pre-install Playwright Chromium browser
# ---------------------------------------------------------------------------
RUN _start=$SECONDS && echo "▶ [24/24] Installing Playwright Chromium…" && \
    npx -y playwright install chromium && \
    echo "✓ [24/24] done in $((SECONDS - _start))s"

# ---------------------------------------------------------------------------
# Final config (no EXPOSE — each repo sets ports via devcontainer.json)
# ---------------------------------------------------------------------------
WORKDIR /app
SHELL ["/bin/bash", "-lc"]
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
