# Minimal Arch Linux image for integration-testing the post-install pipeline
# against a real, from-scratch machine. The class of bug this exists to catch
# (post-install scripts dying silently under `set -e`, so later dotfiles never
# get deployed) only showed up on an actual fresh install — the pure-bash unit
# tests in tests/test-post-install.sh only cover script SELECTION, not what
# the scripts actually do to the filesystem.
FROM archlinux:latest

# DisableSandbox works around a seccomp incompatibility between pacman 7's
# sandboxed downloader and QEMU-emulated amd64 (hit on Apple Silicon dev
# machines building with --platform linux/amd64; a no-op on native amd64 CI).
RUN echo "DisableSandbox" >> /etc/pacman.conf \
    && pacman -Syu --noconfirm archlinux-keyring \
    && pacman -S --noconfirm --needed zsh git curl which

RUN useradd -m -s /bin/bash tester
USER tester
WORKDIR /home/tester
