#!/usr/bin/env bash
# Deprecated wrapper — use: bin/atlana
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "note: skill-manager.sh is deprecated; use bin/atlana" >&2
exec "$DIR/bin/atlana" "$@"
