#!/usr/bin/env bash
# Install oh-my-zsh shell framework

set -e

echo "🔧 Setting up oh-my-zsh..."

# Check if already installed
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "✅ oh-my-zsh already installed, skipping"
  exit 0
fi

# Download and run installer
echo "📦 Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# readlink -f canonicalizes the path before handing it to chsh: on Arch,
# /usr/sbin is a symlink to bin, so `which zsh` can resolve to
# /usr/sbin/zsh — a spelling that isn't literally listed in /etc/shells
# even though it's the same binary as the whitelisted /usr/bin/zsh.
ZSH_BIN="$(readlink -f "$(which zsh)")"
if ! chsh -s "$ZSH_BIN"; then
  echo "⚠️  Could not change default shell to $ZSH_BIN — change it manually with: chsh -s $ZSH_BIN"
fi

echo "✅ oh-my-zsh installed successfully"
