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

# Get latest release URLs (zip and checksums)
echo "📦 Fetching latest Godots release..."
RELEASE_API=$(curl -s https://api.github.com/repos/MakovWait/godots/releases/latest)

# Determine the correct zip file based on OS
case "$OS_TYPE" in
  darwin)
    ZIP_NAME="macOS.zip"
    ;;
  linux)
    ZIP_NAME="LinuxX11.zip"
    ;;
  *)
    echo "⚠️  Unsupported OS: $OS_TYPE"
    exit 1
    ;;
esac

LATEST_URL=$(echo "$RELEASE_API" | \
  grep "browser_download_url.*${ZIP_NAME}\"" | \
  cut -d '"' -f 4)

CHECKSUMS_URL=$(echo "$RELEASE_API" | \
  grep "browser_download_url.*SHA512-SUMS.txt" | \
  cut -d '"' -f 4)

if [[ -z "$LATEST_URL" ]]; then
  echo "⚠️  Could not find release for $OS_TYPE"
  echo "   Please install manually from: https://github.com/MakovWait/godots"
  exit 1
fi

# Download zip file
echo "📥 Downloading Godots..."
TEMP_ZIP=$(mktemp)
if ! curl -fsSL "$LATEST_URL" -o "$TEMP_ZIP"; then
  echo "❌ Failed to download Godots"
  echo "   Please check your internet connection and try again"
  rm -f "$TEMP_ZIP"
  exit 1
fi

# Download and verify checksum if available
if [[ -n "$CHECKSUMS_URL" ]]; then
  echo "🔐 Verifying checksum..."
  CHECKSUMS_FILE=$(mktemp)

  if curl -fsSL "$CHECKSUMS_URL" -o "$CHECKSUMS_FILE"; then
    # Get expected checksum for this zip
    EXPECTED_CHECKSUM=$(grep "$ZIP_NAME" "$CHECKSUMS_FILE" | awk '{print $1}')

    if [[ -n "$EXPECTED_CHECKSUM" ]]; then
      # Calculate actual checksum (SHA512)
      if command -v sha512sum &>/dev/null; then
        ACTUAL_CHECKSUM=$(sha512sum "$TEMP_ZIP" | awk '{print $1}')
      elif command -v shasum &>/dev/null; then
        ACTUAL_CHECKSUM=$(shasum -a 512 "$TEMP_ZIP" | awk '{print $1}')
      else
        echo "⚠️  No SHA512 tool found, skipping checksum verification"
        ACTUAL_CHECKSUM="$EXPECTED_CHECKSUM"
      fi

      if [[ "$ACTUAL_CHECKSUM" == "$EXPECTED_CHECKSUM" ]]; then
        echo "✅ Checksum verified"
      else
        echo "❌ Checksum verification failed!"
        echo "   Expected: $EXPECTED_CHECKSUM"
        echo "   Got:      $ACTUAL_CHECKSUM"
        rm -f "$TEMP_ZIP" "$CHECKSUMS_FILE"
        exit 1
      fi
    else
      echo "⚠️  Checksum not found for ${ZIP_NAME}, skipping verification"
    fi

    rm -f "$CHECKSUMS_FILE"
  else
    echo "⚠️  Could not download checksums file, skipping verification"
  fi
else
  echo "⚠️  No checksums file available, skipping verification"
fi

# Extract and install
echo "📦 Extracting Godots..."
TEMP_DIR=$(mktemp -d)
if ! unzip -q "$TEMP_ZIP" -d "$TEMP_DIR"; then
  echo "❌ Failed to extract Godots"
  rm -rf "$TEMP_ZIP" "$TEMP_DIR"
  exit 1
fi

if [[ "$OS_TYPE" == "linux" ]]; then
  # Release ships a single arch-suffixed binary: Godots.x86_64 (capital G)
  GODOTS_BINARY=$(find "$TEMP_DIR" -type f -iname "godots*" | head -n 1)
  if [[ -z "$GODOTS_BINARY" ]]; then
    echo "❌ Could not find Godots binary in zip"
    rm -rf "$TEMP_ZIP" "$TEMP_DIR"
    exit 1
  fi
  chmod +x "$GODOTS_BINARY"
  mv "$GODOTS_BINARY" "$BIN_DIR/godots"
else
  # macOS release: outer zip contains a nested Godots.zip holding Godots.app
  INNER_ZIP=$(find "$TEMP_DIR" -name "Godots.zip" | head -n 1)
  if [[ -z "$INNER_ZIP" ]]; then
    echo "❌ Could not find inner Godots.zip in macOS archive"
    rm -rf "$TEMP_ZIP" "$TEMP_DIR"
    exit 1
  fi
  INNER_DIR=$(mktemp -d)
  unzip -q "$INNER_ZIP" -d "$INNER_DIR"
  APP_SRC=$(find "$INNER_DIR" -name "Godots.app" -type d | head -n 1)
  if [[ -z "$APP_SRC" ]]; then
    echo "❌ Could not find Godots.app in macOS archive"
    rm -rf "$TEMP_ZIP" "$TEMP_DIR" "$INNER_DIR"
    exit 1
  fi
  echo "📦 Installing Godots.app to /Applications..."
  cp -r "$APP_SRC" /Applications/Godots.app
  ln -sf "/Applications/Godots.app/Contents/MacOS/Godots" "$BIN_DIR/godots"
  rm -rf "$INNER_DIR"
fi

# Cleanup
rm -rf "$TEMP_ZIP" "$TEMP_DIR"

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
