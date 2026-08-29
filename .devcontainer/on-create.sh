#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "Starting on-create script..."

# Ensure USERNAME is available
USERNAME="${USERNAME:-$(whoami)}" # If USERNAME is not set, use the output of whoami
USER_HOME="/home/$USERNAME"

# Flutter configuration
# Guarded: these flags shift between SDK releases and must not abort container creation.
echo "Configuring Flutter..."
dart --disable-analytics || true
flutter --disable-analytics || true

# Install Oh My Zsh
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    # CHSH=no and RUNZSH=no prevent the installer from trying to change the shell or run zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
else
    echo "Oh My Zsh is already installed."
fi

# Install the Powerlevel10k theme for Oh My Zsh
P10K_DIR="$USER_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
    echo "Powerlevel10k theme is already installed."
fi

# Clone your dotfiles
DOTFILES_REPO_URL="https://github.com/jmcjm/dotfiles-devcontainers.git"
DOTFILES_DIR="$USER_HOME/dotfiles-devcontainers"
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles from $DOTFILES_REPO_URL..."
    git clone "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
else
    echo "Dotfiles directory already exists. Pulling latest changes..."
    (cd "$DOTFILES_DIR" && git pull)
fi

# Create symbolic links for configuration files
echo "Configuring Zsh, Oh My Zsh, and nano..."

# Link for .zshrc
# Oh My Zsh creates a .zshrc file. We will replace it with a symlink to your file.
if [ -f "$USER_HOME/.zshrc" ] && ! [ -L "$USER_HOME/.zshrc" ]; then
    echo "Backing up existing .zshrc to .zshrc.pre-dotfiles"
    mv "$USER_HOME/.zshrc" "$USER_HOME/.zshrc.pre-dotfiles"
fi
# Remove if an incorrect symlink exists
if [ -L "$USER_HOME/.zshrc" ] && [ "$(readlink $USER_HOME/.zshrc)" != "$DOTFILES_DIR/zshrc" ]; then
    rm "$USER_HOME/.zshrc"
fi
# Create the symbolic link
if [ ! -L "$USER_HOME/.zshrc" ]; then
    echo "Creating symbolic link for .zshrc..."
    ln -sf "$DOTFILES_DIR/zshrc" "$USER_HOME/.zshrc"
else
    echo ".zshrc symbolic link already exists."
fi

# Link for .p10k.zsh
if [ -f "$USER_HOME/.p10k.zsh" ] && ! [ -L "$USER_HOME/.p10k.zsh" ]; then
    echo "Backing up existing .p10k.zsh to .p10k.zsh.pre-dotfiles"
    mv "$USER_HOME/.p10k.zsh" "$USER_HOME/.p10k.zsh.pre-dotfiles"
fi
if [ -L "$USER_HOME/.p10k.zsh" ] && [ "$(readlink $USER_HOME/.p10k.zsh)" != "$DOTFILES_DIR/p10k.zsh" ]; then
    rm "$USER_HOME/.p10k.zsh"
fi
if [ ! -L "$USER_HOME/.p10k.zsh" ]; then
    echo "Creating symbolic link for .p10k.zsh..."
    ln -sf "$DOTFILES_DIR/p10k.zsh" "$USER_HOME/.p10k.zsh"
else
    echo ".p10k.zsh symbolic link already exists."
fi

# Link for nano configuration (.nanorc)
if [ -f "$USER_HOME/.nanorc" ] && ! [ -L "$USER_HOME/.nanorc" ]; then
    echo "Backing up existing .nanorc to .nanorc.pre-dotfiles"
    mv "$USER_HOME/.nanorc" "$USER_HOME/.nanorc.pre-dotfiles"
fi
if [ -L "$USER_HOME/.nanorc" ] && [ "$(readlink $USER_HOME/.nanorc)" != "$DOTFILES_DIR/nanorc" ]; then
    rm "$USER_HOME/.nanorc"
fi
# Create the .config/nano directory if it doesn't exist (alternative location for nano config)
mkdir -p "$USER_HOME/.config/nano"
if [ ! -L "$USER_HOME/.nanorc" ]; then
    echo "Creating symbolic link for .nanorc..."
    ln -sf "$DOTFILES_DIR/nanorc" "$USER_HOME/.nanorc"
else
    echo ".nanorc symbolic link already exists."
fi

curl -fsSL https://raw.githubusercontent.com/dylanaraps/pfetch/refs/heads/master/pfetch > ~/pfetch || true
chmod +x ~/pfetch || true

# Run flutter doctor
# Guarded: flutter doctor exits non-zero when any category reports an issue.
echo "Running flutter doctor..."
flutter doctor || true

# Onboarding animation
if command -v task &> /dev/null && [ -f "Taskfile.yml" ]; then # Check if task exists and Taskfile.yml exists
    echo "Running onboarding animation..."
    export TERM=xterm-256color
    task onboarding | while IFS= read -r line; do
        for (( i=0; i<${#line}; i++ )); do
            echo -n "${line:$i:1}"
            sleep 0.003
        done
        echo
    done
else
    echo "Command 'task' or Taskfile.yml not found, skipping onboarding animation."
fi

echo "on-create script finished."
