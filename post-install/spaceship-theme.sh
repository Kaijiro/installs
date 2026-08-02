#!/usr/bin/env bash
# Install Spaceship prompt theme for oh-my-zsh

set -e

echo "🔧 Setting up Spaceship theme..."

# Check if oh-my-zsh is installed
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "⚠️  oh-my-zsh not found, skipping Spaceship theme installation"
  exit 0
fi

THEME_DIR="$HOME/.oh-my-zsh/custom/themes/spaceship-prompt"

# Check if already installed
if [[ -d "$THEME_DIR" ]]; then
  echo "✅ Spaceship theme already installed, skipping"
  exit 0
fi

# Clone the repository
echo "📦 Installing Spaceship theme..."
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$THEME_DIR" --depth=1

# Create symlink
ln -sf "$THEME_DIR/spaceship.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/spaceship.zsh-theme"

# ZSH_THEME is already hardcoded to "spaceship" in the tracked dotfiles/.zshrc
# (the single source of truth deployed via dotfiles-setup.sh) — no rc file
# needs editing here. Editing $HOME/.zshrc directly would also risk clobbering
# it: once dotfiles-setup.sh has run, that path is a symlink into the tracked
# file, and `sed -i` replaces symlinks with a plain file instead of following them.

echo "✅ Spaceship theme installed successfully"
