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
git clone <your-repo-url>
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

### Version Managers

After installation, version managers provide commands like:

```bash
# Node.js (nvm)
nvm install 20
nvm use 20
nvm alias default 20

# Python (pyenv)
pyenv install 3.12.0
pyenv global 3.12.0

# Java (SDKMAN)
sdk install java 21
sdk default java 21

# Godot (Godots)
godots install 4.3
godots use 4.3
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

## Project Structure

```
.
├── bootstrap.sh              # Main installation script
├── run-post-install.sh       # Post-install script runner
├── brewfiles/                # Homebrew bundle files
│   ├── Brewfile.base
│   ├── Brewfile.aws
│   ├── Brewfile.java
│   ├── Brewfile.node
│   ├── Brewfile.python
│   └── Brewfile.gamedev
├── post-install/             # Post-installation scripts
│   ├── oh-my-zsh-setup.sh
│   ├── spaceship-theme.sh
│   ├── dotfiles-setup.sh
│   ├── godots-install.sh
│   ├── sdkman-install.sh
│   └── nvm-install.sh
├── post-install.yml          # Post-install script configuration
├── dotfiles/                 # Your dotfiles
│   └── .gitconfig
├── dotfiles.yml              # Dotfiles metadata
└── README.md
```

## Customization

### Adding a New Profile

1. Create `brewfiles/Brewfile.myprofile`:
```ruby
brew "my-tool"
cask "my-app"
```

2. (Optional) Add post-install script to `post-install.yml`:
```yaml
my-setup:
  script: my-setup.sh
  profiles: [myprofile]
  description: "Setup for my profile"
  priority: 15
```

The profile will automatically appear in the selection menu.

### Adding Post-Install Scripts

Add to `post-install.yml`:

```yaml
my-script:
  script: my-script.sh
  requires: [tool-name]         # Run if tool was installed
  profiles: [profile-name]      # Run if profile selected
  description: "What it does"
  interactive: false
  priority: 50                  # Lower = earlier
```

Scripts run if **either** requirements or profiles match.

### Shell Configuration

After installation, add these to your `~/.zshrc`:

```bash
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# Godots
export PATH="$HOME/.local/bin:$PATH"
```

## Troubleshooting

**Homebrew not found after installation**
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"  # macOS Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"     # macOS Intel
```

**Version manager not found**
- Restart your shell: `exec $SHELL`
- Or source your rc file: `source ~/.zshrc`

**Dotfiles not linked**
- Check `.install-manifest` to see what was installed
- Manually run: `./post-install/dotfiles-setup.sh`

## Maintenance

### Re-running Installation

Safe to run multiple times - the bootstrap script is idempotent:
- Skips already installed tools
- Won't reinstall version managers
- Backs up existing dotfiles before linking

### Updating Tools

```bash
brew update
brew upgrade
```

## License

Personal setup script - feel free to fork and customize!
