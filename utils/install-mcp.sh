#!/usr/bin/env bash
# install-mcp.sh — set up the Atlana MCP server (Python venv + deps)
#
# Usage:
#   ./utils/install-mcp.sh              # create venv + install
#   ./utils/install-mcp.sh --force      # recreate venv
#   ./utils/install-mcp.sh --typescript # also npm install in typescript/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/../skills" ]]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -d "$SCRIPT_DIR/skills" ]]; then
  ROOT="$SCRIPT_DIR"
else
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

MCP_DIR="$ROOT/mcp"
FORCE=0
DO_TS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --typescript|--ts) DO_TS=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--force] [--typescript]"
      echo "  Creates mcp/.venv and installs requirements.txt"
      exit 0
      ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$MCP_DIR" ]]; then
  echo "Error: $MCP_DIR not found" >&2
  exit 1
fi

cd "$MCP_DIR"

# pick a Python
PY=""
for candidate in python3.15 python3.14 python3.13 python3.12 python3.11 python3; do
  if command -v "$candidate" >/dev/null 2>&1; then
    ver="$("$candidate" -c 'import sys; print(sys.version_info[:2])' 2>/dev/null || true)"
    case "$ver" in
      "(3, 11)"|"(3, 12)"|"(3, 13)"|"(3, 14)"|"(3, 15)") PY="$candidate"; break ;;
    esac
  fi
done

if [[ -z "$PY" ]]; then
  echo "Error: need Python 3.11+ (found none)" >&2
  echo "  brew install python@3.12" >&2
  exit 1
fi

echo "Using: $($PY --version)"

if [[ $FORCE -eq 1 && -d .venv ]]; then
  echo "Removing existing .venv"
  rm -rf .venv
fi

if [[ ! -d .venv ]]; then
  echo "Creating .venv"
  "$PY" -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "✓ MCP server ready"
echo "  Python:  $(which python)"
echo "  Start:   atlana mcp"
echo "  Or:      ATLANA_ROOT=$ROOT python $MCP_DIR/server.py"

if [[ $DO_TS -eq 1 && -d typescript ]]; then
  echo ""
  echo "Installing TypeScript dependencies..."
  (cd typescript && npm install)
  echo "✓ TypeScript ready (npx tsx src/index.ts)"
fi
