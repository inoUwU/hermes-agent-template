#!/bin/bash
set -Eeuo pipefail

MODE="${1:---missing-only}"
if [[ "$MODE" != "--force" && "$MODE" != "--missing-only" ]]; then
  echo "usage: $0 [--force|--missing-only]" >&2
  exit 64
fi

GH_CONFIG_DIR="${GH_CONFIG_DIR:-${HOME:-/data}/.config/gh}"
COPILOT_EXTENSION="github/gh-copilot"
mkdir -p "$GH_CONFIG_DIR"

log() {
  echo "[install-github-tools] $*"
}

if ! command -v gh >/dev/null 2>&1; then
  log "GitHub CLI (gh) is not installed."
  exit 1
fi

has_copilot() {
  gh extension list 2>/dev/null | awk '{print $1}' | grep -Eq '(^|/)gh-copilot$'
}

if [[ "$MODE" == "--missing-only" ]] && has_copilot; then
  log "gh-copilot already installed; skipping bootstrap."
  exit 0
fi

if has_copilot; then
  log "Upgrading gh-copilot..."
  gh extension upgrade gh-copilot
else
  log "Installing gh-copilot..."
  gh extension install "$COPILOT_EXTENSION"
fi

gh copilot --help >/dev/null
log "$(gh --version | head -n 1)"
log "gh-copilot is ready."
