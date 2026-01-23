FROM node:20-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Base tooling
RUN apt-get update && apt-get install -y \
    sudo nano curl gnupg wget ca-certificates \
    procps locales iproute2 \
    python3 python3-pip \
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
    apt-get clean && rm -rf /var/lib/apt/lists/*

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
ENV LANG=C.UTF-8 LANGUAGE=en_US:en LC_ALL=C.UTF-8

ENV PATH="${PATH}:/home/${USERNAME}/.npm-global/bin"

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

# Set up user-local npm prefix
RUN mkdir -p /home/${USERNAME}/.npm-global \
    && npm config set prefix "/home/${USERNAME}/.npm-global"

WORKDIR /app

EXPOSE 3000
SHELL ["/bin/bash", "-lc"]
CMD ["/bin/bash"]
