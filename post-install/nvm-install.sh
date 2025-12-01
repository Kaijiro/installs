#!/usr/bin/env bash
# Install nvm (Node Version Manager)

set -e

echo "🔧 Installing nvm (Node Version Manager)..."

# Check if already installed
if [[ -d "$HOME/.nvm" ]]; then
  echo "✅ nvm already installed"

  # Source nvm to display version
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
    nvm --version
  fi

  exit 0
fi

# Get latest nvm version
echo "📦 Fetching latest nvm version..."
NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$NVM_VERSION" ]]; then
  echo "⚠️  Could not fetch latest nvm version, using fallback v0.40.1"
  NVM_VERSION="v0.40.1"
else
  echo "   Latest version: $NVM_VERSION"
fi

# Download and install nvm
echo "📥 Downloading and installing nvm $NVM_VERSION..."
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

echo "✅ nvm installed successfully"
echo ""
echo "💡 To use nvm, you need to source it in your shell"
echo "   Add this to your ~/.zshrc or ~/.bashrc:"
echo "   export NVM_DIR=\"\$HOME/.nvm\""
echo "   [ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\""
echo "   [ -s \"\$NVM_DIR/bash_completion\" ] && \\. \"\$NVM_DIR/bash_completion\""
echo ""
echo "   Or simply restart your shell and run: source ~/.zshrc"
echo ""
echo "Usage:"
echo "  nvm list-remote        # List available Node.js versions"
echo "  nvm install 20         # Install Node.js 20"
echo "  nvm install --lts      # Install latest LTS version"
echo "  nvm use 20             # Use Node.js 20 for current shell"
echo "  nvm alias default 20   # Set Node.js 20 as default"
