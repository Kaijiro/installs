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
chsh -s $(which zsh)

echo "✅ oh-my-zsh installed successfully"
