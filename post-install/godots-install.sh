#!/usr/bin/env bash
# Install Godots (Godot version manager)

set -e

echo "🔧 Installing Godots (Godot version manager)..."

# Check if already installed
if command -v godots &>/dev/null; then
  echo "✅ Godots already installed"
  godots --version
  exit 0
fi

# Installation directory
INSTALL_DIR="$HOME/.godots"
BIN_DIR="$HOME/.local/bin"

# Create directories
mkdir -p "$BIN_DIR"

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin*)
    OS_TYPE="darwin"
    ;;
  Linux*)
    OS_TYPE="linux"
    ;;
  *)
    echo "⚠️  Unsupported OS: $OS"
    exit 1
    ;;
esac

case "$ARCH" in
  x86_64)
    ARCH_TYPE="amd64"
    ;;
  arm64|aarch64)
    ARCH_TYPE="arm64"
    ;;
  *)
    echo "⚠️  Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Get latest release URL
echo "📦 Fetching latest Godots release..."
LATEST_URL=$(curl -s https://api.github.com/repos/mayuso/godots/releases/latest | \
  grep "browser_download_url.*${OS_TYPE}_${ARCH_TYPE}" | \
  cut -d '"' -f 4)

if [[ -z "$LATEST_URL" ]]; then
  echo "⚠️  Could not find release for ${OS_TYPE}_${ARCH_TYPE}"
  echo "   Please install manually from: https://github.com/mayuso/godots"
  exit 1
fi

# Download and install
echo "📥 Downloading Godots..."
curl -L "$LATEST_URL" -o /tmp/godots

# Make executable and move to bin
chmod +x /tmp/godots
mv /tmp/godots "$BIN_DIR/godots"

echo "✅ Godots installed successfully to $BIN_DIR/godots"
echo ""
echo "💡 Make sure $BIN_DIR is in your PATH"
echo "   Add this to your ~/.zshrc or ~/.bashrc:"
echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "Usage:"
echo "  godots install 4.3    # Install Godot 4.3"
echo "  godots list           # List installed versions"
echo "  godots use 4.3        # Use specific version"
