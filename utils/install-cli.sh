#!/usr/bin/env bash
# Install `atlana` on PATH so it runs from any directory.
# Usage:
#   ./utils/install-cli.sh           # symlink → ~/.local/bin/atlana
#   ./utils/install-cli.sh --prefix /usr/local
#   ./utils/install-cli.sh --uninstall
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/../skills" ]]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
SRC="$ROOT/bin/atlana"
PREFIX="${HOME}/.local"
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    --help|-h)
      echo "Usage: install-cli.sh [--prefix DIR] [--uninstall]"
      echo "  default prefix: \$HOME/.local  (binary at \$prefix/bin/atlana)"
      exit 0
      ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

BIN_DIR="$PREFIX/bin"
LINK="$BIN_DIR/atlana"

[[ -f "$SRC" ]] || { echo "missing $SRC" >&2; exit 1; }
chmod +x "$SRC"

if [[ $UNINSTALL -eq 1 ]]; then
  if [[ -L "$LINK" || -f "$LINK" ]]; then
    rm -f "$LINK"
    echo "removed $LINK"
  else
    echo "nothing at $LINK"
  fi
  exit 0
fi

mkdir -p "$BIN_DIR"
ln -sfn "$SRC" "$LINK"
echo "linked $LINK → $SRC"

case ":$PATH:" in
  *":$BIN_DIR:"*) echo "PATH already includes $BIN_DIR" ;;
  *)
    echo ""
    echo "Add this to ~/.zshrc (or ~/.bashrc), then open a new terminal:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo ""
echo "Try:  atlana agents"
echo "      atlana list --component skills"
