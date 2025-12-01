#!/usr/bin/env bash
# Set up global git hooks via symlinks

set -e

echo "🔧 Setting up global git hooks..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up one level to get to the project root
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GITHOOKS_SOURCE="$PROJECT_ROOT/scripts/githooks"

# Global git hooks directory (matching .gitconfig)
GLOBAL_HOOKS_DIR="$HOME/.githooks"

# Check if githooks directory exists
if [[ ! -d "$GITHOOKS_SOURCE" ]]; then
  echo "⚠️  Git hooks directory not found at $GITHOOKS_SOURCE"
  exit 1
fi

# Create global hooks directory
mkdir -p "$GLOBAL_HOOKS_DIR"

# Symlink hooks
hook_count=0
for hook_file in "$GITHOOKS_SOURCE"/*; do
  if [[ -f "$hook_file" ]]; then
    hook_name=$(basename "$hook_file")
    target="$GLOBAL_HOOKS_DIR/$hook_name"

    # Remove existing file or symlink
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
      rm "$target"
    fi

    # Create symlink
    ln -s "$hook_file" "$target"

    echo "  ✅ Linked: $hook_name"
    ((hook_count++))
  fi
done

if [[ $hook_count -eq 0 ]]; then
  echo "⚠️  No git hooks found to install"
  exit 0
fi

echo ""
echo "✅ Successfully linked $hook_count global git hook(s) to $GLOBAL_HOOKS_DIR"
