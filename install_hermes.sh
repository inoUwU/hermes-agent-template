#!/bin/bash
set -Eeuo pipefail

MODE="${1:---force}"
if [[ "$MODE" != "--force" && "$MODE" != "--missing-only" ]]; then
  echo "usage: $0 [--force|--missing-only]" >&2
  exit 64
fi

HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
RUNTIME_DIR="${HERMES_RUNTIME_DIR:-$HERMES_HOME/runtime}"
SRC_DIR="${HERMES_SRC_DIR:-$RUNTIME_DIR/hermes-agent}"
VENV_DIR="${HERMES_VENV_DIR:-$RUNTIME_DIR/venv}"
BIN_DIR="${HERMES_BIN_DIR:-$HERMES_HOME/bin}"
META_FILE="${HERMES_RUNTIME_META:-$RUNTIME_DIR/install-meta.json}"
REPO_URL="${HERMES_REPO_URL:-https://github.com/NousResearch/hermes-agent.git}"
REPO_REF="${HERMES_REPO_REF:-main}"
TMP_SRC="${RUNTIME_DIR}/hermes-agent.next"
TMP_VENV="${RUNTIME_DIR}/venv.next"
TMP_META="${RUNTIME_DIR}/install-meta.json.next"
PREV_SRC="${RUNTIME_DIR}/hermes-agent.prev"
PREV_VENV="${RUNTIME_DIR}/venv.prev"
UV_CACHE_DIR="${UV_CACHE_DIR:-$RUNTIME_DIR/.cache/uv}"
ROLLBACK_READY=0
INSTALL_COMPLETE=0

log() {
  echo "[install-hermes] $*"
}

cleanup() {
  rm -rf "$TMP_SRC" "$TMP_VENV" "$TMP_META"
  if [[ "$INSTALL_COMPLETE" -eq 1 ]]; then
    rm -rf "$PREV_SRC" "$PREV_VENV"
  fi
}

rollback() {
  local status=$?
  trap - ERR INT TERM
  if [[ "$ROLLBACK_READY" -eq 1 ]]; then
    log "Update failed after staging new runtime; restoring previous install."
    rm -rf "$SRC_DIR" "$VENV_DIR"
    if [[ -e "$PREV_SRC" ]]; then
      mv "$PREV_SRC" "$SRC_DIR"
    fi
    if [[ -e "$PREV_VENV" ]]; then
      mv "$PREV_VENV" "$VENV_DIR"
    fi
    if [[ -x "$VENV_DIR/bin/hermes" ]]; then
      ln -sfn "$VENV_DIR/bin/hermes" "$BIN_DIR/hermes"
    fi
  fi
  exit "$status"
}

trap cleanup EXIT
trap rollback ERR INT TERM

if [[ "$MODE" == "--missing-only" && -x "$BIN_DIR/hermes" ]]; then
  log "Existing runtime install found at $BIN_DIR/hermes; skipping bootstrap."
  exit 0
fi

mkdir -p "$RUNTIME_DIR" "$BIN_DIR" "$UV_CACHE_DIR"
rm -rf "$TMP_SRC" "$TMP_VENV" "$TMP_META" "$PREV_SRC" "$PREV_VENV"

log "Fetching ${REPO_URL} (${REPO_REF})..."
git clone --depth 1 "$REPO_URL" "$TMP_SRC"
git -C "$TMP_SRC" fetch --depth 1 origin "$REPO_REF"
git -C "$TMP_SRC" checkout --force FETCH_HEAD

commit="$(git -C "$TMP_SRC" rev-parse HEAD)"
short_commit="$(git -C "$TMP_SRC" rev-parse --short HEAD)"

log "Creating runtime virtualenv..."
uv venv "$TMP_VENV"

log "Installing Hermes into ${TMP_VENV}..."
UV_CACHE_DIR="$UV_CACHE_DIR" uv pip install --python "$TMP_VENV/bin/python" --upgrade "$TMP_SRC[all]"

version="$("$TMP_VENV/bin/hermes" --version 2>/dev/null | head -n 1 || true)"
installed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [[ -e "$SRC_DIR" ]]; then
  mv "$SRC_DIR" "$PREV_SRC"
fi
if [[ -e "$VENV_DIR" ]]; then
  mv "$VENV_DIR" "$PREV_VENV"
fi

ROLLBACK_READY=1
mv "$TMP_SRC" "$SRC_DIR"
mv "$TMP_VENV" "$VENV_DIR"
ln -sfn "$VENV_DIR/bin/hermes" "$BIN_DIR/hermes"

META_FILE="$TMP_META" \
REPO_URL="$REPO_URL" \
REPO_REF="$REPO_REF" \
COMMIT="$commit" \
SHORT_COMMIT="$short_commit" \
VERSION="$version" \
INSTALLED_AT="$installed_at" \
BIN_PATH="$BIN_DIR/hermes" \
"$VENV_DIR/bin/python" - <<'PY'
import json
import os
from pathlib import Path

meta_path = Path(os.environ["META_FILE"])
meta_path.parent.mkdir(parents=True, exist_ok=True)
meta = {
    "repo_url": os.environ["REPO_URL"],
    "repo_ref": os.environ["REPO_REF"],
    "commit": os.environ["COMMIT"],
    "short_commit": os.environ["SHORT_COMMIT"],
    "version": os.environ["VERSION"],
    "installed_at": os.environ["INSTALLED_AT"],
    "binary": os.environ["BIN_PATH"],
}
meta_path.write_text(json.dumps(meta, indent=2) + "\n")
PY
mv "$TMP_META" "$META_FILE"

ROLLBACK_READY=0
INSTALL_COMPLETE=1
log "Hermes runtime is ready at ${BIN_DIR}/hermes (${short_commit})."
