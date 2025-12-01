#!/usr/bin/env bash
# Set up dotfiles by creating symlinks for tools that were just installed

set -e

echo "🔧 Setting up dotfiles..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up one level to get to the project root
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOTFILES_DIR="$PROJECT_ROOT/dotfiles"
DOTFILES_CONFIG="$PROJECT_ROOT/dotfiles.yml"
MANIFEST_FILE="$PROJECT_ROOT/.install-manifest"

# Check if manifest exists
if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "⚠️  No installation manifest found, linking all dotfiles"
  # If no manifest, we can't do conditional linking, so skip
  exit 0
fi

# Check if dotfiles directory exists
if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "⚠️  Dotfiles directory not found at $DOTFILES_DIR"
  exit 1
fi

# Check if dotfiles config exists
if [[ ! -f "$DOTFILES_CONFIG" ]]; then
  echo "⚠️  Dotfiles configuration not found at $DOTFILES_CONFIG"
  exit 1
fi

# Backup directory
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Ensure ~/.dotfiles/ directory exists for modular shell configs
mkdir -p "$HOME/.dotfiles"

# Read installed packages from manifest
echo "📋 Reading installation manifest..."
INSTALLED_PACKAGES=($(cat "$MANIFEST_FILE" | sort | uniq))

if [[ ${#INSTALLED_PACKAGES[@]} -eq 0 ]]; then
  echo "⚠️  No packages were installed in this run"
  exit 0
fi

echo "   Found ${#INSTALLED_PACKAGES[@]} newly installed package(s)"

# Function to check if a tool/package was installed
is_installed() {
  local package="$1"
  for installed in "${INSTALLED_PACKAGES[@]}"; do
    # Match if the installed package contains the required package name
    # This handles cases like "git" matching "git" or "brave-browser" matching "brave-browser"
    if [[ "$installed" == "$package" ]] || [[ "$installed" == *"$package"* ]]; then
      return 0
    fi
  done
  return 1
}

# Function to check if all requirements are met
check_requirements() {
  local requirements="$1"

  # Extract array of requirements from YAML-like format: [git, zsh] -> git zsh
  local reqs=$(echo "$requirements" | sed 's/\[//g; s/\]//g; s/,/ /g')

  for req in $reqs; do
    if is_installed "$req"; then
      return 0  # At least one requirement is met
    fi
  done

  return 1  # No requirements met
}

# Function to create symlink
create_symlink() {
  local source="$1"
  local target="$2"
  local filename=$(basename "$source")

  # If target already exists
  if [[ -e "$target" ]] || [[ -L "$target" ]]; then
    # Check if it's already the correct symlink
    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
      echo "  ✓ $filename (already linked)"
      return 0
    fi

    # Back up existing file
    mkdir -p "$BACKUP_DIR"
    echo "  📦 Backing up existing $filename to $BACKUP_DIR/"
    mv "$target" "$BACKUP_DIR/"
  fi

  # Create symlink
  ln -s "$source" "$target"
  echo "  ✅ Linked $filename"
}

# Parse dotfiles.yml and link conditionally
echo ""
echo "🔍 Checking which dotfiles to link..."
echo ""

count=0
skipped=0

# Simple YAML parsing for dotfiles section
# This is a basic parser that works for our simple structure
while IFS= read -r line; do
  # Skip empty lines and comments
  [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]] && continue

  # Detect dotfile entry (starts with two spaces and ends with :)
  if [[ "$line" =~ ^[[:space:]]{2}([^:]+):$ ]]; then
    dotfile_path="${BASH_REMATCH[1]}"
    continue
  fi

  # Detect requires field
  if [[ "$line" =~ ^[[:space:]]{4}requires:[[:space:]]*(.+)$ ]]; then
    requirements="${BASH_REMATCH[1]}"

    # Check if requirements are met
    if check_requirements "$requirements"; then
      source_file="$DOTFILES_DIR/$dotfile_path"
      target_file="$HOME/$dotfile_path"

      if [[ -f "$source_file" ]]; then
        # Create parent directory if needed
        target_dir=$(dirname "$target_file")
        mkdir -p "$target_dir"

        create_symlink "$source_file" "$target_file"
        ((count++))
      else
        echo "  ⏩ Skipping $dotfile_path (file not found in dotfiles/)"
        ((skipped++))
      fi
    else
      echo "  ⏩ Skipping $dotfile_path (requirements not met: $requirements)"
      ((skipped++))
    fi
  fi
done < "$DOTFILES_CONFIG"

echo ""
if [[ $count -eq 0 ]]; then
  echo "⚠️  No dotfiles were linked"
else
  echo "✅ Successfully linked $count dotfile(s)"
fi

if [[ $skipped -gt 0 ]]; then
  echo "⏩ Skipped $skipped dotfile(s)"
fi

if [[ -d "$BACKUP_DIR" ]]; then
  echo "📦 Original files backed up to: $BACKUP_DIR"
fi
