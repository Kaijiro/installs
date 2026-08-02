#!/usr/bin/env bash
# ============================================================
# Docker-backed integration tests for the post-install pipeline
# ============================================================
# Unlike tests/test-post-install.sh (pure bash, tests SELECTION logic only,
# no scripts actually run), this executes the real scripts on a fresh Arch
# Linux container via run-post-install.sh and asserts the deployed
# end-state. This is what caught the ((count++)) under `set -e` bug that
# silently dropped .zshrc and every git hook after the first.
#
# Requires a running Docker daemon. Slow (real network: pacman sync, oh-my-zsh
# clone). Not part of the fast default test run — invoke explicitly:
#   bash tests/docker/run-tests.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IMAGE="installs-test-arch"
CONTAINER="installs-test-arch-run"
LOG_FILE="$(mktemp)"

PASS=0
FAIL=0

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

check() {
  local desc="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS  $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $desc"
    echo "        expected: $expected"
    echo "        actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not available/running — these are integration tests and require it." >&2
  exit 1
fi

echo "Building test image..."
if ! docker build --platform linux/amd64 -q -t "$IMAGE" "$SCRIPT_DIR" >"$LOG_FILE" 2>&1; then
  echo "Image build failed:" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "Starting container..."
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run --name "$CONTAINER" --platform linux/amd64 -d "$IMAGE" sleep infinity >/dev/null

# Copies the current working tree (including uncommitted edits), not the
# last commit — so this tests what's actually on disk right now.
docker cp "$REPO_ROOT" "$CONTAINER:/home/tester/installs"
docker exec -u root "$CONTAINER" chown -R tester:tester /home/tester/installs

echo "Running post-install pipeline as a non-root user..."
docker exec -u tester "$CONTAINER" bash -c '
  cd /home/tester/installs
  printf "zsh\ngit\ncurl\n" > .install-manifest
  : > .selected-profiles
  bash run-post-install.sh
' >"$LOG_FILE" 2>&1
PIPELINE_EXIT=$?

echo ""
echo "post-install pipeline — deployment assertions"
echo ""

ZSHRC_LINK="$(docker exec -u tester "$CONTAINER" readlink /home/tester/.zshrc 2>/dev/null || echo "NOT_A_SYMLINK")"
check ".zshrc is a symlink into the repo's dotfiles/" "$ZSHRC_LINK" "/home/tester/installs/dotfiles/.zshrc"

ZSHRC_MARKER="$(docker exec -u tester "$CONTAINER" bash -c 'grep -c "Kaijiro'"'"'s ZSH Configuration" ~/.zshrc 2>/dev/null' || echo 0)"
check ".zshrc content is the tracked custom file, not oh-my-zsh's default" "$ZSHRC_MARKER" "1"

GITCONFIG_LINK="$(docker exec -u tester "$CONTAINER" readlink /home/tester/.gitconfig 2>/dev/null || echo "NOT_A_SYMLINK")"
check ".gitconfig is a symlink into the repo's dotfiles/" "$GITCONFIG_LINK" "/home/tester/installs/dotfiles/.gitconfig"

EXPECTED_HOOKS="$(ls "$REPO_ROOT/scripts/githooks" | sort | tr '\n' ' ')"
ACTUAL_HOOKS="$(docker exec -u tester "$CONTAINER" bash -c 'ls ~/.githooks 2>/dev/null | sort | tr "\n" " "')"
check "every git hook is linked (not just the first)" "$ACTUAL_HOOKS" "$EXPECTED_HOOKS"

check "run-post-install.sh exits 0" "$PIPELINE_EXIT" "0"

echo ""
echo "$PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Full pipeline output:"
  cat "$LOG_FILE"
  exit 1
fi
