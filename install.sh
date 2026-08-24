#!/usr/bin/env bash
# Atlana thin installer — prefers bin/atlana when available
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="${REPO_URL:-https://github.com/uminocelo/atlana}"

if [[ -x "$SCRIPT_DIR/bin/atlana" ]]; then
  ROOT="$SCRIPT_DIR"
elif [[ -d "$SCRIPT_DIR/skills" ]]; then
  ROOT="$SCRIPT_DIR"
else
  # piped install: clone
  TEMP="$(mktemp -d)"
  git clone --depth 1 "$REPO_URL" "$TEMP/atlana"
  ROOT="$TEMP/atlana"
  trap 'rm -rf "$TEMP"' EXIT
fi

exec "$ROOT/bin/atlana" install \
  --component skills \
  --component hooks \
  --component rules \
  --component subagents \
  --all \
  "$@"
