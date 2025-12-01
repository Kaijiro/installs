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

# Update .zshrc to use spaceship theme
if [[ -f "$HOME/.zshrc" ]]; then
  if grep -q '^ZSH_THEME=' "$HOME/.zshrc"; then
    sed -i.bak 's/^ZSH_THEME=.*/ZSH_THEME="spaceship"/' "$HOME/.zshrc"
    echo "✅ Updated .zshrc to use Spaceship theme"
  else
    echo 'ZSH_THEME="spaceship"' >> "$HOME/.zshrc"
    echo "✅ Added Spaceship theme to .zshrc"
  fi
fi

echo "✅ Spaceship theme installed successfully"
