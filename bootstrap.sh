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
    if [[ "$OSTYPE" == "darwin"* ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || true
  fi
}

apply_brewfile() {
  file=$1
  if [[ -f "$file" ]]; then
    echo "👉 Installing: $file"

    # Run brew bundle and capture output
    brew bundle --file="$file" 2>&1 | tee /tmp/brew_output.txt

    # Parse output to extract installed packages
    # Look for lines like "Installing <package>" or "Downloading <package>"
    grep -E "^(Installing|Downloading)" /tmp/brew_output.txt | \
      sed -E 's/^(Installing|Downloading) //' | \
      tee -a "$manifestFile" || true

    rm -f /tmp/brew_output.txt
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
