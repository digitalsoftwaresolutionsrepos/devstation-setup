FROM mcr.microsoft.com/dotnet/sdk:9.0

ENV DEBIAN_FRONTEND=noninteractive

# Base tooling: sudo, editors, network tools, Python, Postgres, gh, etc.
RUN apt-get update && apt-get install -y \
    sudo nano curl gnupg wget ca-certificates apt-transport-https \
    software-properties-common procps locales iproute2 \
    python3 python3-pip python3-venv \
    postgresql postgresql-contrib postgresql-client \
    openssh-client git git-lfs unzip && \
    git lfs install --system && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list >/dev/null && \
    apt-get update && apt-get install -y gh && \
    ssh-keyscan -H github.com >> /etc/ssh/ssh_known_hosts 2>/dev/null || true && \
    bash -lc 'if [ -d /usr/lib/postgresql ]; then \
      PG_VER=$(ls /usr/lib/postgresql | sort -V | tail -1); \
      ln -sf /usr/lib/postgresql/${PG_VER}/bin/* /usr/local/bin/; \
      printf "export PATH=/usr/lib/postgresql/%s/bin:\$PATH\n" "$PG_VER" > /etc/profile.d/pg-path.sh; \
    fi' && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js (for frontend tooling if needed)
ARG NODE_VERSION=20.11.0
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz \
    && mkdir -p /usr/local/lib/nodejs \
    && tar -xJf /tmp/node.tar.xz -C /usr/local/lib/nodejs \
    && rm /tmp/node.tar.xz \
    && ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/node /usr/local/bin/node \
    && ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/npm /usr/local/bin/npm \
    && ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/npx /usr/local/bin/npx

# User setup
ARG USERNAME=vscode
ARG USER_UID=1001
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /run/user/$USER_UID && \
    chown $USERNAME:$USERNAME /run/user/$USER_UID && \
    chmod 700 /run/user/$USER_UID

# Core env
ENV NPM_CONFIG_CACHE=/home/${USERNAME}/.npm
ENV DOTNET_ROOT=/usr/share/dotnet
ENV NODE_VERSION=20.11.0
ENV NODE_HOME=/usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64
ENV LANG=C.UTF-8 LANGUAGE=en_US:en LC_ALL=C.UTF-8
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ENV PATH="${NODE_HOME}/bin:${DOTNET_ROOT}:${PATH}:/home/${USERNAME}/.dotnet/tools"

# Install gitui (terminal git UI)
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64) GITUI_FILE="gitui-linux-x86_64.tar.gz" ;; \
      aarch64) GITUI_FILE="gitui-linux-aarch64.tar.gz" ;; \
      *) echo "Unsupported arch: $ARCH"; exit 1 ;; \
    esac && \
    LATEST_URL=$(curl -sL https://api.github.com/repos/extrawurst/gitui/releases/latest \
      | grep "browser_download_url.*${GITUI_FILE}" \
      | cut -d '"' -f 4) && \
    curl -sL "$LATEST_URL" | tar xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/gitui

# Symlink vi to nano (for tools like gitui that expect vi)
RUN ln -sf /usr/bin/nano /usr/local/bin/vi

USER $USERNAME
WORKDIR /app

EXPOSE 5000 5432
SHELL ["/bin/bash", "-lc"]
CMD ["/bin/bash"]
