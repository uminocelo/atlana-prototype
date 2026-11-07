#!/usr/bin/env bash
# PreToolUse: block high-risk shell commands.
# Compatible with Crush and Claude Code (exit 2 = deny).
set -euo pipefail

CMD="${CRUSH_TOOL_INPUT_COMMAND:-${CLAUDE_TOOL_INPUT_COMMAND:-}}"

# Also accept JSON stdin (Claude Code / Crush full payload)
if [[ -z "$CMD" && ! -t 0 ]]; then
  INPUT=$(cat || true)
  CMD=$(printf '%s' "$INPUT" | python3 -c '
import json,sys
try:
  d=json.load(sys.stdin)
  ti=d.get("tool_input") or d.get("input") or {}
  print(ti.get("command") or ti.get("cmd") or "")
except Exception:
  print("")
' 2>/dev/null || true)
fi

[[ -z "$CMD" ]] && exit 0

# Patterns to block (extend as needed)
if echo "$CMD" | grep -qiE \
  '\brm\s+(-[a-zA-Z]*r|--recursive).*\s+/( |$)' \
  || echo "$CMD" | grep -qiE '\bgit\s+push\s+.*--force\b' \
  || echo "$CMD" | grep -qiE '\bgit\s+reset\s+--hard\b' \
  || echo "$CMD" | grep -qiE '\bgit\s+clean\s+-[a-zA-Z]*f' \
  || echo "$CMD" | grep -qiE '\bmkfs\b|\bdd\s+if=' \
  || echo "$CMD" | grep -qiE '>\s*/etc/|\bchmod\s+-R\s+777\b'
then
  echo "Blocked dangerous command by Atlana safety hook: $CMD" >&2
  exit 2
fi

exit 0
