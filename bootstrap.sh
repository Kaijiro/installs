#!/usr/bin/env bash
set -e

# --- Configuration ----------------------------------------------------

brewfilesPath="brewfiles"
manifestFile=".install-manifest"

# Initialize manifest file (clear if exists)
> "$manifestFile"

# Dynamically discover available profiles from brewfiles directory
AVAILABLE_PROFILES=()
for file in "${brewfilesPath}"/Brewfile.*; do
  if [[ -f "$file" ]]; then
    # Extract profile name (everything after "Brewfile.")
    profile=$(basename "$file" | sed 's/^Brewfile\.//')
    # Exclude "base" since it's installed automatically
    if [[ "$profile" != "base" ]]; then
      AVAILABLE_PROFILES+=("$profile")
    fi
  fi
done

# --- Helpers ----------------------------------------------------------

install_brew() {
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

apply_brewfile() {
  file=$1
  if [[ -f "$file" ]]; then
    echo "👉 Installing: $file"

    # Parse Brewfile to extract package names
    # Extract brew formulae (brew "package")
    grep -E '^[[:space:]]*brew[[:space:]]+"[^"]+"' "$file" | \
      sed -E 's/^[[:space:]]*brew[[:space:]]+"([^"]+)".*/\1/' >> "$manifestFile"

    # Extract casks (cask "package")
    grep -E '^[[:space:]]*cask[[:space:]]+"[^"]+"' "$file" | \
      sed -E 's/^[[:space:]]*cask[[:space:]]+"([^"]+)".*/\1/' >> "$manifestFile"

    # Run brew bundle
    brew bundle --file="$file"
  else
    echo "⏩ Skipping missing file: $file"
  fi
}

# --- Install brew -----------------------------------------------------
install_brew
brew update

# --- Install gum (UI) if needed ---------------------------------------
if ! command -v gum &>/dev/null; then
  echo "Installing gum..."
  brew install gum
fi

# --- Prompt for profiles ----------------------------------------------
echo "Select the profiles to install:"
echo "(Base will be installed automatically)"

PROFILES=$(gum choose \
  --no-limit \
  "${AVAILABLE_PROFILES[@]}" \
)

echo ""
echo "Selected : $PROFILES"
echo ""

# Save selected profiles for post-install scripts
echo "$PROFILES" | tr ' ' '\n' > .selected-profiles

# --- Install base ------------------------------------------------------

apply_brewfile "${brewfilesPath}/Brewfile.base"

# --- Apply selected profiles -------------------------------------------

for p in $PROFILES; do
  apply_brewfile "${brewfilesPath}/Brewfile.$p"
done

# --- Run post-install scripts ------------------------------------------

echo ""
if [[ -f "run-post-install.sh" ]]; then
  bash "run-post-install.sh"
fi

echo ""
echo "🎉 Installation done !"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Installation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show installed profiles
echo "✅ Profiles installed:"
echo "   • base"
for p in $PROFILES; do
  echo "   • $p"
done
echo ""

# Show package count
if [[ -f "$manifestFile" ]]; then
  PACKAGE_COUNT=$(sort "$manifestFile" | uniq | wc -l | tr -d ' ')
  echo "📊 Total packages: $PACKAGE_COUNT"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Source the shell configuration to apply changes
echo "🔄 Applying shell configuration..."
if [[ -f "~/.zshrc" ]]; then
  source "~/.zshrc" 2>/dev/null || true
fi
