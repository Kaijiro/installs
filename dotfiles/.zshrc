# ============================================================
# Kaijiro's ZSH Configuration
# ============================================================

# --- Oh My Zsh Configuration --------------------------------

# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="spaceship"

# Plugins
plugins=(git)

# Load Oh My Zsh
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source $ZSH/oh-my-zsh.sh
fi

# --- Custom Scripts Path ------------------------------------

# Add custom scripts directory to PATH
# Find the scripts directory relative to this .zshrc's real location
ZSHRC_REAL_PATH=$(readlink ~/.zshrc || echo ~/.zshrc)
INSTALLS_ROOT=$(cd "$(dirname "$ZSHRC_REAL_PATH")/.." && pwd)
INSTALLS_SCRIPTS="$INSTALLS_ROOT/scripts"
if [ -d "$INSTALLS_SCRIPTS" ]; then
  export PATH="$INSTALLS_SCRIPTS:$PATH"
fi

# --- Load Profile Configurations ----------------------------

# Source all configuration files from ~/.dotfiles/
if [ -d "$HOME/.dotfiles" ]; then
  for config in "$HOME/.dotfiles"/*.zsh; do
    [ -f "$config" ] && source "$config"
  done
fi

# --- Local Customization ------------------------------------

# Load local customizations if they exist (not tracked in git)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
