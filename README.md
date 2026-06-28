# Development Environment Setup

Automated, cross-platform setup for development environments on new computers using profile-based installation. The same profiles install via **Homebrew on macOS** and **pacman/AUR on Arch-based Linux** (e.g. EndeavourOS) from a single source of truth.

## Features

- **Cross-platform**: One package definition per tool, resolved to Homebrew (macOS) or pacman/AUR/flatpak (Arch) at install time
- **Profile-based installation**: Select from modular profiles (aws, java, node, python, gamedev)
- **Single source of truth**: `pkgfiles/*.pkg` map each tool to its per-OS package name
- **Version managers**: Automatic installation of nvm, uv, SDKMAN, Godots
- **Dotfiles management**: Symlink-based dotfiles with conditional linking
- **Post-install automation**: Run scripts after tools are installed (with optional `os:` gating)
- **Interactive UI**: Uses `gum` for beautiful CLI prompts

## Requirements

- macOS, or an Arch-based Linux distribution (pacman)
- Internet connection
- curl (usually pre-installed)
- On Arch: `sudo` access (for pacman); an AUR helper is bootstrapped automatically if missing

## Quick Start

```bash
# Clone this repository
git clone https://github.com/Kaijiro/installs.git
cd installs

# Run the bootstrap script
./bootstrap.sh
```

The script will:
1. Detect your platform (macOS or Arch Linux)
2. Set up the package manager prerequisites:
   - **macOS**: install Homebrew (if missing) + `gum`
   - **Arch**: sync/upgrade via pacman, install `gum`, bootstrap an AUR helper (`paru`) if none is present
3. Let you select which profiles to install
4. Install all tools from selected profiles via the platform's package manager
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
- uv (fast package, project & version manager)

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
├── bootstrap.sh              # Main installation script (OS detection + dispatch)
├── run-post-install.sh       # Post-install script runner
├── pkgfiles/                 # Cross-platform package definitions (*.pkg)
├── post-install/             # Post-installation scripts
├── post-install.yml          # Post-install script configuration
├── dotfiles/                 # Dotfiles
├── dotfiles.yml              # Dotfiles metadata
└── README.md
```

### Package definitions (`pkgfiles/*.pkg`)

Each profile is a whitespace-delimited table mapping a canonical tool name to its
package on each platform:

```
# <tool-key>        <darwin-spec>            <arch-spec>
git                 brew:git                 pacman:git
jetbrains-toolbox   cask:jetbrains-toolbox   aur:jetbrains-toolbox
raycast             cask:raycast             -          # macOS-only: no Linux equivalent
```

- **spec** = `<backend>:<package-name>`, or `-` to declare the tool unavailable on that OS.
- **backends**: `brew`, `cask` (macOS); `pacman`, `aur`, `flatpak` (Arch).
- The **tool-key** is what lands in `.install-manifest` and what `dotfiles.yml` /
  `post-install.yml` match against in their `requires:` lists — keep it stable across OSes.

**Adding a tool**: add one line to the relevant `pkgfiles/*.pkg`, filling in the package
name for each OS (use `-` where it genuinely has no equivalent). Verify names against
[archlinux.org/packages](https://archlinux.org/packages/) and the
[AUR](https://aur.archlinux.org/) for the Arch column.

### Platform notes

- macOS-only apps (e.g. Raycast, Stats) carry `-` in the Arch column and are reported as
  skipped during a Linux install.
- On Arch, `docker` installs the native engine (enable with `systemctl enable --now docker`);
  swap to `aur:docker-desktop` in `pkgfiles/base.pkg` if you want GUI parity with the macOS cask.
- Post-install scripts can be restricted to a platform with an `os: darwin` or `os: linux`
  field in `post-install.yml`.

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
