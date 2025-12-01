#!/usr/bin/env bash
# Install SDKMAN (Software Development Kit Manager for JVM)

set -e

echo "🔧 Installing SDKMAN..."

# Check if already installed
if [[ -d "$HOME/.sdkman" ]]; then
  echo "✅ SDKMAN already installed"

  # Source SDKMAN to display version
  if [[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk version
  fi

  exit 0
fi

# Download and install SDKMAN
echo "📦 Downloading and installing SDKMAN..."
curl -s "https://get.sdkman.io" | bash

echo "✅ SDKMAN installed successfully"
echo ""
echo "💡 To use SDKMAN, you need to source it in your shell"
echo "   Add this to your ~/.zshrc or ~/.bashrc:"
echo "   export SDKMAN_DIR=\"\$HOME/.sdkman\""
echo "   [[ -s \"\$HOME/.sdkman/bin/sdkman-init.sh\" ]] && source \"\$HOME/.sdkman/bin/sdkman-init.sh\""
echo ""
echo "   Or simply restart your shell and run: source ~/.zshrc"
echo ""
echo "Usage:"
echo "  sdk list java          # List available Java versions"
echo "  sdk install java 21    # Install Java 21"
echo "  sdk use java 21        # Use Java 21 for current shell"
echo "  sdk default java 21    # Set Java 21 as default"
