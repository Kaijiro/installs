#!/usr/bin/env bash
# Post-install script runner
# Parses post-install.yml and runs scripts based on requirements and profiles

set -e

# Get script directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POST_INSTALL_DIR="$SCRIPT_DIR/post-install"
POST_INSTALL_CONFIG="$SCRIPT_DIR/post-install.yml"
MANIFEST_FILE="$SCRIPT_DIR/.install-manifest"
PROFILES_FILE="$SCRIPT_DIR/.selected-profiles"

# Current OS for the `os:` filter in post-install.yml (darwin | linux)
case "$(uname -s)" in
  Darwin) CURRENT_OS="darwin" ;;
  Linux)  CURRENT_OS="linux" ;;
  *)      CURRENT_OS="unknown" ;;
esac

echo "📋 Running post-install scripts..."
echo ""

# Check if config exists
if [[ ! -f "$POST_INSTALL_CONFIG" ]]; then
  echo "⚠️  No post-install.yml found, skipping"
  exit 0
fi

# Read installed packages from manifest
INSTALLED_PACKAGES=()
if [[ -f "$MANIFEST_FILE" ]]; then
  # Intentional word-splitting (one entry per line); mapfile is bash 4+ only.
  # shellcheck disable=SC2207
  INSTALLED_PACKAGES=($(sort -u "$MANIFEST_FILE"))
fi

# Read selected profiles
SELECTED_PROFILES=()
if [[ -f "$PROFILES_FILE" ]]; then
  # Intentional word-splitting (one profile per line); mapfile is bash 4+ only.
  # shellcheck disable=SC2207
  SELECTED_PROFILES=($(cat "$PROFILES_FILE"))
fi

echo "Selected profiles: ${SELECTED_PROFILES[*]:-none}"
echo "Installed packages: ${#INSTALLED_PACKAGES[@]}"
echo ""

# Function to check if a package was installed
is_package_installed() {
  local package="$1"
  for installed in "${INSTALLED_PACKAGES[@]}"; do
    if [[ "$installed" == "$package" ]] || [[ "$installed" == *"$package"* ]]; then
      return 0
    fi
  done
  return 1
}

# Function to check if requirements are met
check_requirements() {
  local requirements="$1"

  # Empty requirements always pass
  if [[ -z "$requirements" ]] || [[ "$requirements" == "[]" ]]; then
    return 1  # No requirements means don't trigger on requirements
  fi

  # Extract array: [git, zsh] -> git zsh
  local reqs
  reqs=$(echo "$requirements" | sed 's/\[//g; s/\]//g; s/,/ /g')

  for req in $reqs; do
    if is_package_installed "$req"; then
      return 0  # At least one requirement met
    fi
  done

  return 1  # No requirements met
}

# Function to check if profile matches
check_profiles() {
  local required_profiles="$1"

  # Empty profiles means don't trigger on profiles
  if [[ -z "$required_profiles" ]] || [[ "$required_profiles" == "[]" ]]; then
    return 1
  fi

  # Extract array: [gamedev, pro] -> gamedev pro
  local profiles
  profiles=$(echo "$required_profiles" | sed 's/\[//g; s/\]//g; s/,/ /g')

  for profile in $profiles; do
    for selected in "${SELECTED_PROFILES[@]}"; do
      # Also check "base" profile which is always selected
      if [[ "$profile" == "$selected" ]] || [[ "$profile" == "base" ]]; then
        return 0
      fi
    done
  done

  return 1
}

# Function to check if an os constraint allows running on this platform.
# Empty constraint = run anywhere.
os_allows() {
  local os="$1"
  [[ -z "$os" ]] || [[ "$os" == "$CURRENT_OS" ]]
}

# A script with neither requirements nor profiles is unconditional: it always
# runs (e.g. dotfiles-setup). An empty list is written as "[]" in the YAML.
is_unconditional() {
  local reqs="$1" profs="$2"
  [[ -z "$reqs" || "$reqs" == "[]" ]] && [[ -z "$profs" || "$profs" == "[]" ]]
}

# Parse post-install.yml and collect scripts to run.
# Indexed array of "priority|name|file" entries — kept bash 3.2 compatible
# (associative arrays require bash 4+, absent on stock macOS).
scripts_to_run=()

current_script=""
current_file=""
current_priority=50
current_requirements=""
current_profiles=""
current_os=""

while IFS= read -r line; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

  # Detect script entry (2 spaces + name + :)
  if [[ "$line" =~ ^[[:space:]]{2}([a-z0-9_-]+):$ ]]; then
    # Process previous script if any
    if [[ -n "$current_script" ]] && [[ -n "$current_file" ]]; then
      # Check if should run (requirements OR profiles)
      should_run=false

      if check_requirements "$current_requirements"; then
        should_run=true
      fi

      if check_profiles "$current_profiles"; then
        should_run=true
      fi

      if is_unconditional "$current_requirements" "$current_profiles"; then
        should_run=true
      fi

      # OS constraint overrides: never run a script on the wrong platform
      if ! os_allows "$current_os"; then
        should_run=false
      fi

      if $should_run; then
        scripts_to_run+=("$current_priority|$current_script|$current_file")
      fi
    fi

    # Start new script
    current_script="${BASH_REMATCH[1]}"
    current_file=""
    current_priority=50
    current_requirements=""
    current_profiles=""
    current_os=""
    continue
  fi

  # Parse fields
  if [[ "$line" =~ ^[[:space:]]{4}script:[[:space:]]*(.+)$ ]]; then
    current_file="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]{4}priority:[[:space:]]*([0-9]+)$ ]]; then
    current_priority="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]{4}requires:[[:space:]]*(.+)$ ]]; then
    current_requirements="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]{4}profiles:[[:space:]]*(.+)$ ]]; then
    current_profiles="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]{4}os:[[:space:]]*(.+)$ ]]; then
    current_os="${BASH_REMATCH[1]}"
  fi
done < "$POST_INSTALL_CONFIG"

# Process last script
if [[ -n "$current_script" ]] && [[ -n "$current_file" ]]; then
  should_run=false

  if check_requirements "$current_requirements"; then
    should_run=true
  fi

  if check_profiles "$current_profiles"; then
    should_run=true
  fi

  if is_unconditional "$current_requirements" "$current_profiles"; then
    should_run=true
  fi

  # OS constraint overrides: never run a script on the wrong platform
  if ! os_allows "$current_os"; then
    should_run=false
  fi

  if $should_run; then
    scripts_to_run+=("$current_priority|$current_script|$current_file")
  fi
fi

# Sort scripts by priority and run them
if [[ ${#scripts_to_run[@]} -eq 0 ]]; then
  echo "⚠️  No post-install scripts to run"
  exit 0
fi

echo "Found ${#scripts_to_run[@]} script(s) to run"
echo ""

# Sort by priority (numeric, on the leading priority field)
printf '%s\n' "${scripts_to_run[@]}" | sort -n -t'|' -k1,1 | while IFS='|' read -r priority name file; do
  script_path="$POST_INSTALL_DIR/$file"

  if [[ -f "$script_path" ]] && [[ -x "$script_path" ]]; then
    echo "🔧 Running: $name (priority: $priority)"
    bash "$script_path" || echo "⚠️  Script failed: $name"
    echo ""
  else
    echo "⚠️  Script not found or not executable: $script_path"
    echo ""
  fi
done

echo "✅ Post-install scripts completed"
