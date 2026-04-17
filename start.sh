#!/bin/bash
set -e

mkdir -p /data/.config/gh /data/.hermes/bin /data/.hermes/runtime /data/.hermes/sessions /data/.hermes/skills /data/.hermes/workspace /data/.hermes/pairing
export GH_CONFIG_DIR="/data/.config/gh"
if [ -n "${GITHUB_TOKEN:-}" ] && [ -z "${GH_TOKEN:-}" ]; then
  export GH_TOKEN="${GITHUB_TOKEN}"
fi
export PATH="${PATH}:/data/.hermes/bin"

exec python /app/server.py
