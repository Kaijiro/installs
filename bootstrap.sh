#!/usr/bin/env bash
set -e

# Never run as root: makepkg (AUR builds) refuses to, and Homebrew warns.
# Privileged steps escalate with `sudo` individually.
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "❌ Do not run this script as root. It uses sudo only where needed."
  exit 1
fi

# Anchor all relative paths to the repo root regardless of caller's CWD.
cd "$(dirname "${BASH_SOURCE[0]}")"

# --- Configuration ----------------------------------------------------

pkgfilesPath="pkgfiles"
manifestFile=".install-manifest"

# Initialize manifest file (clear if exists)
: > "$manifestFile"

# Backend buckets (indexed arrays — bash 3.2 compatible for macOS system bash)
BREW_FORMULAE=()
BREW_CASKS=()
PACMAN_PKGS=()
AUR_PKGS=()
FLATPAK_PKGS=()
MANIFEST_KEYS=()
SKIPPED=()

# --- OS detection -----------------------------------------------------
# OS_KEY selects which column of the .pkg files we read.
# Only macOS (Homebrew) and Arch-family Linux (pacman) are supported.

detect_os() {
  case "$(uname -s)" in
    Darwin)
      OS_KEY="darwin"
      ;;
    Linux)
      if command -v pacman &>/dev/null; then
        OS_KEY="arch"
      else
        echo "❌ Unsupported Linux distribution (no pacman found)."
        echo "   This installer currently supports macOS and Arch-based distros."
        exit 1
      fi
      ;;
    *)
      echo "❌ Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac
  echo "🖥️  Detected platform: $OS_KEY"
}

# --- Prerequisites ----------------------------------------------------

install_brew() {
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

# Ensure an AUR helper exists on Arch; bootstrap paru from source if not.
# makepkg refuses to run as root, so this must not be invoked under sudo.
ensure_aur_helper() {
  if command -v paru &>/dev/null; then AUR_HELPER="paru"; return; fi
  if command -v yay  &>/dev/null; then AUR_HELPER="yay";  return; fi

  echo "📦 No AUR helper found — bootstrapping paru from source..."
  sudo pacman -S --needed --noconfirm git base-devel
  local tmp
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  ( cd "$tmp/paru" && makepkg -si --noconfirm )
  rm -rf "$tmp"
  AUR_HELPER="paru"
}

ensure_prereqs() {
  if [[ "$OS_KEY" == "darwin" ]]; then
    install_brew
    brew update
    command -v gum &>/dev/null || brew install gum
  else
    # Refresh keyring first to prevent signature verification failures on
    # systems whose trust DB hasn't been updated in a while.
    echo "🔑 Updating archlinux-keyring..."
    sudo pacman -S --needed --noconfirm archlinux-keyring
    # Full sync+upgrade once, up front: avoids pacman partial-upgrade breakage.
    echo "📦 Synchronizing and upgrading system (pacman -Syu)..."
    sudo pacman -Syu --needed --noconfirm gum git base-devel
    ensure_aur_helper
  fi
}

# --- Profile collection -----------------------------------------------
# Parse a .pkg file, pick the column for the current OS, and route each
# package into its backend bucket. Inline trailing comments are absorbed
# into the discarded `_rest` field.

collect_profile() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "⏩ Skipping missing file: $file"
    return
  fi
  echo "👉 Collecting: $file"

  local tool darwin arch _rest spec backend name
  while read -r tool darwin arch _rest; do
    # Skip blank lines and comments
    [[ -z "$tool" ]] && continue
    [[ "$tool" == \#* ]] && continue

    if [[ "$OS_KEY" == "darwin" ]]; then spec="$darwin"; else spec="$arch"; fi

    # Unavailable on this OS (explicit "-" or missing column)
    if [[ -z "$spec" || "$spec" == "-" ]]; then
      SKIPPED+=("$tool")
      continue
    fi

    backend="${spec%%:*}"
    name="${spec#*:}"

    case "$backend" in
      brew)    BREW_FORMULAE+=("$name") ;;
      cask)    BREW_CASKS+=("$name") ;;
      pacman)  PACMAN_PKGS+=("$name") ;;
      aur)     AUR_PKGS+=("$name") ;;
      flatpak) FLATPAK_PKGS+=("$name") ;;
      *)
        echo "  ⚠️  Unknown backend '$backend' for '$tool' (skipping)"
        continue
        ;;
    esac

    MANIFEST_KEYS+=("$tool")
  done < "$file"
}

# --- Backend installers -----------------------------------------------

install_darwin() {
  local tmp
  tmp="$(mktemp)"
  local f
  for f in "${BREW_FORMULAE[@]:-}"; do [[ -n "$f" ]] && echo "brew \"$f\"" >> "$tmp"; done
  for f in "${BREW_CASKS[@]:-}";   do [[ -n "$f" ]] && echo "cask \"$f\"" >> "$tmp"; done

  if [[ -s "$tmp" ]]; then
    echo "🍺 Installing via brew bundle ($(wc -l < "$tmp" | tr -d ' ') entries)..."
    brew bundle --file="$tmp"
  fi
  rm -f "$tmp"
}

install_arch() {
  if (( ${#PACMAN_PKGS[@]} )); then
    echo "📦 pacman: ${PACMAN_PKGS[*]}"
    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
  fi
  if (( ${#AUR_PKGS[@]} )); then
    echo "📦 AUR ($AUR_HELPER): ${AUR_PKGS[*]}"
    "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
  fi
  if (( ${#FLATPAK_PKGS[@]} )); then
    command -v flatpak &>/dev/null || sudo pacman -S --needed --noconfirm flatpak
    # Flathub is opt-in on EndeavourOS — ensure the remote exists before installing.
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    local f
    for f in "${FLATPAK_PKGS[@]}"; do
      echo "📦 flatpak: $f"
      flatpak install -y flathub "$f"
    done
  fi
}

run_install() {
  if [[ "$OS_KEY" == "darwin" ]]; then
    install_darwin
  else
    install_arch
  fi
}

# --- Main -------------------------------------------------------------

detect_os
ensure_prereqs

# Dynamically discover available profiles from pkgfiles directory
AVAILABLE_PROFILES=()
for file in "${pkgfilesPath}"/*.pkg; do
  [[ -f "$file" ]] || continue
  profile="$(basename "$file" .pkg)"
  # Exclude "base" since it's installed automatically
  [[ "$profile" != "base" ]] && AVAILABLE_PROFILES+=("$profile")
done

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

# --- Collect base + selected profiles ---------------------------------

collect_profile "${pkgfilesPath}/base.pkg"
for p in $PROFILES; do
  collect_profile "${pkgfilesPath}/$p.pkg"
done

# --- Install ----------------------------------------------------------

run_install

# Write canonical tool keys to the manifest (deduplicated).
# `|| true` guards the zero-package edge case under a future `set -o pipefail`.
printf '%s\n' "${MANIFEST_KEYS[@]:-}" | grep -v '^$' | sort -u > "$manifestFile" || true

# --- Run post-install scripts -----------------------------------------

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
  PACKAGE_COUNT=$(grep -c . "$manifestFile" | tr -d ' ')
  echo "📊 Total packages: $PACKAGE_COUNT"
fi

# Report anything skipped as unavailable on this platform
if (( ${#SKIPPED[@]} )); then
  echo "⏩ Skipped (no $OS_KEY equivalent): ${SKIPPED[*]}"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Source the shell configuration to apply changes
echo "🔄 Applying shell configuration..."
if [[ -f "$HOME/.zshrc" ]]; then
  source "$HOME/.zshrc" 2>/dev/null || true
fi
