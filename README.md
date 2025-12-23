# Development Environment Setup

Automated setup for development environments on new computers using Homebrew and profile-based installation.

## Features

- **Profile-based installation**: Select from modular profiles (aws, java, node, python, gamedev)
- **Automated tool installation**: Brewfiles for each domain
- **Version managers**: Automatic installation of nvm, pyenv, SDKMAN, Godots
- **Dotfiles management**: Symlink-based dotfiles with conditional linking
- **Post-install automation**: Run scripts after tools are installed
- **Interactive UI**: Uses `gum` for beautiful CLI prompts

## Requirements

- macOS or Linux compatible with Homebrew
- Internet connection
- curl (usually pre-installed)

## Quick Start

```bash
# Clone this repository
git clone https://github.com/Kaijiro/installs.git
cd installs

# Run the bootstrap script
./bootstrap.sh
```

The script will:
1. Install Homebrew (if not present)
2. Install `gum` for interactive prompts
3. Let you select which profiles to install
4. Install all tools from selected profiles
5. Run post-install scripts (version managers, dotfiles, etc.)

## Available Profiles

### Base (Always Installed)
Essential tools for any setup:
- git, jq, curl, wget, zsh
- JetBrains Toolbox, Sublime Text, Postman, Docker
- Raycast, Stats, Brave Browser, Deezer
- FiraCode Nerd Font

### AWS
AWS cloud development tools:
- AWS CLI v2
- CloudFormation linter (cfn-lint)
- aws-vault (secure credential storage)

### Java
Java/JVM development:
- Maven, Gradle
- SDKMAN (auto-installed for managing Java versions)

### Node
Node.js development:
- nvm (auto-installed for managing Node.js versions)

### Python
Python development:
- pyenv (version manager)
- pyenv-virtualenv (virtual environment plugin)
- pipx (isolated Python app installer)

### Gamedev
Game development and creative tools:
- Gimp, Blender, Audacity
- Godots (auto-installed for managing Godot versions)

## Usage

### Selecting Multiple Profiles

When prompted, use arrow keys and spacebar to select multiple profiles:

```
Select the profiles to install:
(Base will be installed automatically)

[ ] aws
[x] node
[x] python
[ ] java
[ ] gamedev
```

### Dotfiles

Dotfiles are automatically symlinked based on installed tools:

1. Add your dotfile to `dotfiles/` (e.g., `dotfiles/.gitconfig`)
2. Add entry to `dotfiles.yml`:
```yaml
.gitconfig:
  requires: [git]
  description: "Git configuration"
```
3. When git is installed, the dotfile will be symlinked to `~/.gitconfig`

**Note**: Original files are backed up to `~/.dotfiles_backup_<timestamp>/`

### Shell Configuration

The setup uses a modular approach to shell configuration:

#### Automatic Configuration

The `.zshrc` dotfile automatically:
- Loads Oh My Zsh with the Spaceship theme
- Adds the `scripts/` directory to your PATH (via symlink resolution)
- Sources all `.zsh` files from `~/.dotfiles/` for modular configs

#### Customization

**For personal customizations** (not tracked in git):
Create a `~/.zshrc.local` file for your local-only settings:

```bash
# Example ~/.zshrc.local
export MY_CUSTOM_VAR="value"
export PATH="$HOME/my-tools:$PATH"
alias myalias="some-command"
```

**For modular profile configs** (can be tracked in git):
Create `.zsh` files in `~/.dotfiles/`:

```bash
# Example: ~/.dotfiles/nvm.zsh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Example: ~/.dotfiles/java.zsh
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
```

The post-install scripts automatically create these modular configs for version managers.

## Project Structure

```
.
├── bootstrap.sh              # Main installation script
├── run-post-install.sh       # Post-install script runner
├── brewfiles/                # Homebrew bundle files
├── post-install/             # Post-installation scripts
├── post-install.yml          # Post-install script configuration
├── dotfiles/                 # Dotfiles
├── dotfiles.yml              # Dotfiles metadata
└── README.md
```

## Maintenance

### Re-running Installation

Safe to run multiple times - the bootstrap script is idempotent:
- Skips already installed tools
- Won't reinstall version managers
- Backs up existing dotfiles before linking

## License

This project is personal and particularly suits my needs. Feel free to take inspiration from it, copy parts of it, fork it
or even clone it to use as a starting point for your own setup.
Using it for your own setup is at your own risk though.

Part of this project has been vibe-coded for experimenting with LLMs.
