#!/bin/bash
set -Eeuo pipefail

MODE="${1:---missing-only}"
if [[ "$MODE" != "--force" && "$MODE" != "--missing-only" ]]; then
  echo "usage: $0 [--force|--missing-only]" >&2
  exit 64
fi

GH_CONFIG_DIR="${GH_CONFIG_DIR:-${HOME:-/data}/.config/gh}"
COPILOT_EXTENSION="github/gh-copilot"
COPILOT_HOME="${GH_COPILOT_HOME:-${HOME:-/data}/.local/share/gh/copilot}"
COPILOT_BIN="${GH_COPILOT_BIN:-$COPILOT_HOME/bin/copilot}"
mkdir -p "$GH_CONFIG_DIR"
LOCK_FILE="${GH_COPILOT_INSTALL_LOCK_FILE:-$GH_CONFIG_DIR/gh-copilot.install.lock}"

log() {
  echo "[install-github-tools] $*"
}

if ! command -v gh >/dev/null 2>&1; then
  log "GitHub CLI (gh) is not installed."
  exit 1
fi

has_copilot_extension() {
  gh extension list 2>/dev/null | awk '{print $1}' | grep -Eq '(^|/)gh-copilot$'
}

has_native_copilot_command() {
  gh copilot --help >/dev/null 2>&1
}

if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  flock 9
fi

if [[ "$MODE" == "--missing-only" ]]; then
  if [[ -x "$COPILOT_BIN" ]]; then
    log "Native gh copilot CLI already bootstrapped at $COPILOT_BIN; skipping bootstrap."
    exit 0
  fi
  if has_copilot_extension; then
    log "gh-copilot already installed; skipping bootstrap."
    exit 0
  fi
fi

if has_native_copilot_command && ! has_copilot_extension; then
  log "Bootstrapping native gh copilot CLI..."
  gh copilot -- --help >/dev/null
  log "$(gh --version | head -n 1)"
  log "gh copilot is ready."
  exit 0
fi

if has_copilot_extension; then
  log "Upgrading gh-copilot..."
  gh extension upgrade gh-copilot
else
  log "Installing gh-copilot..."
  gh extension install "$COPILOT_EXTENSION"
fi

gh copilot --help >/dev/null
log "$(gh --version | head -n 1)"
log "gh-copilot is ready."
