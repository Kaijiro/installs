#!/usr/bin/env bash
# ============================================================
# Unit tests for run-post-install.sh script SELECTION + ORDER
# ============================================================
# Verifies *which* post-install scripts the runner selects and in *what order*,
# without installing anything or altering the system.
#
# How it works (no dependencies, runs on bash 3.2+):
#   - Each case runs in a throwaway sandbox ($(mktemp -d)).
#   - The REAL run-post-install.sh is copied in and executed there; its
#     SCRIPT_DIR resolves to the sandbox, so it reads our fixture
#     post-install.yml / .install-manifest / .selected-profiles.
#   - Every script referenced by `script:` is generated as an executable
#     no-op stub, so the runner reaches its "🔧 Running: <name>" line.
#   - `uname` is shimmed via PATH to force the platform, exercising the
#     `os:` gate for both darwin and linux on any host.
#   - We parse the runner's "Running: <name>" lines for the selected order
#     and compare against the expected list.
#
# Usage:  ./tests/test-post-install.sh        (exits non-zero on any failure)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNNER="$REPO_ROOT/run-post-install.sh"

PASS=0
FAIL=0

# --- Fixture builders (operate on the current $SANDBOX) -------------------

new_sandbox() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/post-install" "$SANDBOX/bin"
  cp "$RUNNER" "$SANDBOX/run-post-install.sh"
  : > "$SANDBOX/.install-manifest"
  : > "$SANDBOX/.selected-profiles"
  set_os "Darwin"   # default platform unless a case overrides it
}

# Reads the YAML config from stdin, then generates an executable no-op stub
# for every script it references so the runner can "run" them.
set_config() {
  cat > "$SANDBOX/post-install.yml"
  local f
  grep -E '^[[:space:]]{4}script:' "$SANDBOX/post-install.yml" \
    | sed -E 's/.*script:[[:space:]]*//' \
    | while read -r f; do
        printf '#!/usr/bin/env bash\nexit 0\n' > "$SANDBOX/post-install/$f"
        chmod +x "$SANDBOX/post-install/$f"
      done
}

set_manifest() { printf '%s\n' "$@" > "$SANDBOX/.install-manifest"; }
set_profiles() { printf '%s\n' "$@" > "$SANDBOX/.selected-profiles"; }

# Shim `uname -s` to return a fixed platform string.
set_os() {
  printf '#!/usr/bin/env bash\necho "%s"\n' "$1" > "$SANDBOX/bin/uname"
  chmod +x "$SANDBOX/bin/uname"
}

# Run the runner and emit the selected script names, in order, space-joined.
selected_order() {
  ( cd "$SANDBOX" && PATH="$SANDBOX/bin:$PATH" /bin/bash run-post-install.sh 2>/dev/null ) \
    | grep 'Running:' \
    | sed -E 's/.*Running: ([^ ]+).*/\1/' \
    | tr '\n' ' ' | sed 's/ *$//'
}

# --- Assertion -----------------------------------------------------------

expect_order() {
  local name="$1"; shift
  local expected="$*"
  local actual; actual="$(selected_order)"
  if [[ "$actual" == "$expected" ]]; then
    printf '  \033[32mPASS\033[0m  %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  \033[31mFAIL\033[0m  %s\n' "$name"
    printf '          expected: [%s]\n' "$expected"
    printf '          actual:   [%s]\n' "$actual"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$SANDBOX"
}

# =========================================================================
# Cases
# =========================================================================

echo "run-post-install.sh — selection & ordering"
echo

# 1. requires met -> runs
new_sandbox
set_manifest git zsh curl
set_config <<'YAML'
scripts:
  needs-git:
    script: a.sh
    requires: [git]
YAML
expect_order "requires met -> selected" "needs-git"

# 2. requires NOT met (and no profile) -> skipped
new_sandbox
set_manifest zsh curl
set_config <<'YAML'
scripts:
  needs-docker:
    script: a.sh
    requires: [docker]
YAML
expect_order "requires not met -> skipped" ""

# 3. profile match -> runs
new_sandbox
set_profiles node
set_config <<'YAML'
scripts:
  node-thing:
    script: a.sh
    profiles: [node]
YAML
expect_order "profile selected -> selected" "node-thing"

# 4. profile not selected -> skipped
new_sandbox
set_profiles node
set_config <<'YAML'
scripts:
  game-thing:
    script: a.sh
    profiles: [gamedev]
YAML
expect_order "profile not selected -> skipped" ""

# 5. unconditional (requires [] and no profiles) -> always runs
#    Regression guard for the dotfiles-setup bug.
new_sandbox
set_manifest git
set_config <<'YAML'
scripts:
  always:
    script: a.sh
    requires: []
YAML
expect_order "unconditional -> selected (dotfiles-setup regression)" "always"

# 6. os: darwin gate
new_sandbox
set_manifest git
set_os "Darwin"
set_config <<'YAML'
scripts:
  mac-only:
    script: a.sh
    requires: [git]
    os: darwin
YAML
expect_order "os:darwin on macOS -> selected" "mac-only"

new_sandbox
set_manifest git
set_os "Linux"
set_config <<'YAML'
scripts:
  mac-only:
    script: a.sh
    requires: [git]
    os: darwin
YAML
expect_order "os:darwin on Linux -> skipped" ""

# 7. os: linux gate
new_sandbox
set_manifest git
set_os "Linux"
set_config <<'YAML'
scripts:
  linux-only:
    script: a.sh
    requires: [git]
    os: linux
YAML
expect_order "os:linux on Linux -> selected" "linux-only"

# 8. priority ordering (distinct priorities; ties are intentionally avoided)
new_sandbox
set_manifest git
set_config <<'YAML'
scripts:
  third:
    script: c.sh
    requires: [git]
    priority: 30
  first:
    script: a.sh
    requires: [git]
    priority: 10
  second:
    script: b.sh
    requires: [git]
    priority: 20
YAML
expect_order "priority ordering" "first second third"

# 9. profiles: [base] always matches (special-cased in check_profiles)
new_sandbox
set_profiles node
set_config <<'YAML'
scripts:
  base-thing:
    script: a.sh
    profiles: [base]
YAML
expect_order "profiles:[base] always matches" "base-thing"

# 10. requires OR profiles (either triggers), mixed run with ordering
new_sandbox
set_manifest git
set_profiles node
set_config <<'YAML'
scripts:
  by-profile:
    script: a.sh
    profiles: [node]
    priority: 5
  by-require:
    script: b.sh
    requires: [git]
    priority: 15
  excluded:
    script: c.sh
    requires: [rust]
    profiles: [gamedev]
    priority: 1
YAML
expect_order "requires OR profiles, ordered, excludes non-matching" "by-profile by-require"

# 11. GOLDEN: the repo's real post-install.yml, base manifest + node profile,
#     on macOS. Locks current behavior; update deliberately when config changes.
new_sandbox
cp -r "$REPO_ROOT/post-install/." "$SANDBOX/post-install/" 2>/dev/null || true
# real scripts exist+executable already; still (re)stub to keep them no-op
set_manifest git zsh curl
set_profiles node
set_os "Darwin"
cp "$REPO_ROOT/post-install.yml" "$SANDBOX/post-install.yml"
# ensure every referenced script is an executable no-op stub
grep -E '^[[:space:]]{4}script:' "$SANDBOX/post-install.yml" \
  | sed -E 's/.*script:[[:space:]]*//' \
  | while read -r f; do
      printf '#!/usr/bin/env bash\nexit 0\n' > "$SANDBOX/post-install/$f"
      chmod +x "$SANDBOX/post-install/$f"
    done
expect_order "golden: real config (base + node, macOS)" \
  "oh-my-zsh nvm-install spaceship-theme dotfiles-setup githooks-setup"

# =========================================================================

echo
echo "  $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
