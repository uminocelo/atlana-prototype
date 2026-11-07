#!/usr/bin/env bash
# Copy live Neovim config into Atlana, then reinstall (symlink).
# Usage (from anywhere):
#   ./dotfile/sync-neovim.sh           # pull + install
#   ./dotfile/sync-neovim.sh pull      # ~/.config/nvim → atlana/dotfile/neovim
#   ./dotfile/sync-neovim.sh install   # atlana/dotfile/neovim → ~/.config/nvim
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ATL_NVIM="$ROOT/dotfile/neovim"
LIVE="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

EXCLUDE=(
  --exclude '.git/'
  --exclude '.git'
  --exclude 'lazy-lock.json.bak'
  --exclude '.DS_Store'
)

die() { echo "error: $*" >&2; exit 1; }

same_dir() {
  local a b
  a="$(cd "$1" && pwd)"
  b="$(cd "$2" && pwd)"
  [[ "$a" == "$b" ]]
}

live_points_at_atlana() {
  [[ -L "$LIVE" ]] || return 1
  local dest
  dest="$(cd "$(dirname "$LIVE")" && cd "$(readlink "$LIVE")" && pwd)"
  same_dir "$dest" "$ATL_NVIM"
}

pull() {
  [[ -e "$LIVE" ]] || die "no live config at $LIVE"
  mkdir -p "$ATL_NVIM"

  if live_points_at_atlana; then
    echo "already linked: $LIVE → $ATL_NVIM (nothing to copy)"
    return 0
  fi

  if [[ -L "$LIVE" ]]; then
    # symlink to somewhere else — copy the real files
    local real
    real="$(cd "$(dirname "$LIVE")" && cd "$(readlink "$LIVE")" && pwd)"
    echo "pull $real → $ATL_NVIM"
    rsync -a "${EXCLUDE[@]}" "$real"/ "$ATL_NVIM"/
  else
    echo "pull $LIVE → $ATL_NVIM"
    rsync -a "${EXCLUDE[@]}" "$LIVE"/ "$ATL_NVIM"/
  fi
  echo "atlana neovim updated"
}

install() {
  [[ -d "$ATL_NVIM" ]] || die "missing $ATL_NVIM (run pull first)"
  mkdir -p "$(dirname "$LIVE")"

  if live_points_at_atlana; then
    echo "already installed: $LIVE → $ATL_NVIM"
    return 0
  fi

  if [[ -e "$LIVE" ]]; then
    bak="${LIVE}.bak.$(date +%Y%m%d%H%M%S)"
    echo "backup $LIVE → $bak"
    mv "$LIVE" "$bak"
  fi

  ln -sfn "$ATL_NVIM" "$LIVE"
  echo "linked $LIVE → $ATL_NVIM"
  echo "open nvim and run :Lazy sync"
}

sync_all() {
  pull
  install
}

cmd="${1:-sync}"
case "$cmd" in
  pull) pull ;;
  install) install ;;
  sync|"") sync_all ;;
  -h|--help|help)
    sed -n '2,8p' "$0"
    ;;
  *)
    die "unknown command: $cmd (pull | install | sync)"
    ;;
esac
