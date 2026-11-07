#!/usr/bin/env bash
# add-agent.sh — register a new AI agent in Atlana knowledge (bin/atlana).
#
# Usage:
#   ./utils/add-agent.sh pi
#   ./utils/add-agent.sh codex
#   ./utils/add-agent.sh                 # asks for the agent name
#   ./utils/add-agent.sh pi --dry-run    # search + show patch, change nothing
#   ./utils/add-agent.sh pi --force      # skip confirmation before patching
#
# What it does:
#   1. Takes the agent name (arg or prompt), normalizes to lowercase.
#   2. Searches $HOME for matching dirs + binary on PATH and proposes defaults.
#   3. Prompts for skills/hooks/rules/subagents paths (empty = unsupported).
#   4. Patches bin/atlana case branches + detection + --agent all + usage.
#
# Bash 3.2 compatible (macOS stock). Patching uses python3 stdlib only.
# Never commits; review with `git diff bin/atlana` after.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/../skills" ]]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -d "$SCRIPT_DIR/skills" ]]; then
  ROOT="$SCRIPT_DIR"
else
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
ATLANA_BIN="$ROOT/bin/atlana"

DRY_RUN=0
FORCE=0
AGENT_ARG=""
SKILLS_ARG=""
HOOKS_ARG=""
SUBAGENTS_ARG=""
RULES_DIR_ARG=""
RULES_FILE_ARG=""
BINARY_ARG=""
DETECT_ARG=""
PROJECT_ARG=""
SKILLS_SET=0
HOOKS_SET=0
SUBAGENTS_SET=0
RULES_DIR_SET=0

usage() {
  cat <<USAGE
Usage: add-agent.sh [agent-name] [options]

  agent-name              e.g. pi, codex (also prompted when omitted)

Options:
  --skills-dir <path>     Agent skills dir (empty = unsupported)
  --hooks-dir <path>      Agent hooks dir (empty = unsupported)
  --subagents-dir <path>  Agent subagents dir (empty = unsupported)
  --rules-dir <path>      Agent rules dir (empty = unsupported)
  --rules-file <name>     Rules filename inside rules dir (default: AGENTS.md)
  --binary <name>         Binary on PATH used for detection (default: agent name)
  --detect-dir <path>     Extra dir whose existence means "installed"
  --project-dirname <n>   Project-local dirname, e.g. .pi (default: .<name>)
  --dry-run               Search + show patch only, change nothing
  --force                 Skip final confirmation
  --help                  Show this help

Examples:
  ./utils/add-agent.sh pi
  ./utils/add-agent.sh codex --dry-run
  ./utils/add-agent.sh pi --skills-dir ~/.pi/agent/skills --rules-dir ~/.pi/agent --force
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --skills-dir) SKILLS_ARG="$2"; SKILLS_SET=1; shift 2 ;;
    --hooks-dir) HOOKS_ARG="$2"; HOOKS_SET=1; shift 2 ;;
    --subagents-dir) SUBAGENTS_ARG="$2"; SUBAGENTS_SET=1; shift 2 ;;
    --rules-dir) RULES_DIR_ARG="$2"; RULES_DIR_SET=1; shift 2 ;;
    --rules-file) RULES_FILE_ARG="$2"; shift 2 ;;
    --binary) BINARY_ARG="$2"; shift 2 ;;
    --detect-dir) DETECT_ARG="$2"; shift 2 ;;
    --project-dirname) PROJECT_ARG="$2"; shift 2 ;;
    --*) echo "Error: unknown option: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$AGENT_ARG" ]]; then
        AGENT_ARG="$1"; shift
      else
        echo "Error: unexpected arg: $1" >&2; exit 1
      fi
      ;;
  esac
done

[[ -f "$ATLANA_BIN" ]] || { echo "Error: bin/atlana not found at $ATLANA_BIN" >&2; exit 1; }

if [[ -z "$AGENT_ARG" ]]; then
  read -r -p "Agent name (e.g. pi, codex): " AGENT_ARG
fi
AGENT_ARG="$(echo "$AGENT_ARG" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
if [[ ! "$AGENT_ARG" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "Error: agent name must match [a-z0-9][a-z0-9_-]* (got '$AGENT_ARG')" >&2
  exit 1
fi
AGENT="$AGENT_ARG"

if grep -Eq "^[[:space:]]+${AGENT}\\)" "$ATLANA_BIN" 2>/dev/null; then
  echo "Agent '$AGENT' already exists in bin/atlana — nothing to do." >&2
  grep -nE "^[[:space:]]+${AGENT}\\)" "$ATLANA_BIN" 2>/dev/null | head -10 || true
  exit 0
fi

echo ""
echo "Searching for '$AGENT' on this machine..."

FOUND_DIRS=""
SEARCH_RESULTS="$(find "${HOME}" -maxdepth 2 -type d -iname ".*${AGENT}*" 2>/dev/null | head -20 || true)"
CONFIG_RESULTS="$(find "${HOME}/.config" -maxdepth 2 -type d -iname "*${AGENT}*" 2>/dev/null | head -20 || true)"
FOUND_DIRS="$(printf '%s\n%s' "$SEARCH_RESULTS" "$CONFIG_RESULTS" | grep -v '^$' | sort -u || true)"

BIN_PATH=""
if command -v "$AGENT" >/dev/null 2>&1; then
  BIN_PATH="$(command -v "$AGENT")"
fi
if [[ -n "$BINARY_ARG" ]] && command -v "$BINARY_ARG" >/dev/null 2>&1; then
  BIN_PATH="$(command -v "$BINARY_ARG")"
fi

if [[ -n "$FOUND_DIRS" ]]; then
  echo "  directories matching '*${AGENT}*':"
  echo "$FOUND_DIRS" | while read -r d; do
    [[ -n "$d" ]] && echo "    • $d"
  done
else
  echo "  (no directories matching '*${AGENT}*' under \$HOME maxdepth 2)"
fi
if [[ -n "$BIN_PATH" ]]; then
  echo "  binary on PATH: $BIN_PATH"
else
  echo "  (no binary '$AGENT' on PATH)"
fi

GUESS_BASE=""
if [[ -d "${HOME}/.${AGENT}" ]]; then
  GUESS_BASE="${HOME}/.${AGENT}"
elif [[ -d "${HOME}/.config/${AGENT}" ]]; then
  GUESS_BASE="${HOME}/.config/${AGENT}"
else
  GUESS_BASE="$(echo "$FOUND_DIRS" | grep -v -i -e '/skills$' -e '/hooks$' -e '/agents$' | head -1 || true)"
fi

GUESS_SKILLS=""
GUESS_HOOKS=""
GUESS_RULES_DIR=""
if [[ -n "$GUESS_BASE" ]]; then
  case "$GUESS_BASE" in
    */skills) GUESS_SKILLS="$GUESS_BASE" ;;
    *) GUESS_SKILLS="$GUESS_BASE/skills" ;;
  esac
  GUESS_HOOKS="$GUESS_BASE/hooks"
  GUESS_RULES_DIR="$GUESS_BASE"
  if [[ -d "$GUESS_BASE/agent/skills" ]]; then
    GUESS_SKILLS="$GUESS_BASE/agent/skills"
    GUESS_HOOKS="$GUESS_BASE/agent/hooks"
    GUESS_RULES_DIR="$GUESS_BASE/agent"
  fi
  if [[ -d "$GUESS_BASE/skills" ]]; then
    GUESS_SKILLS="$GUESS_BASE/skills"
  fi
fi
if [[ -z "$GUESS_SKILLS" ]]; then
  GUESS_SKILLS="${HOME}/.${AGENT}/skills"
fi
if [[ -z "$GUESS_RULES_DIR" ]]; then
  GUESS_RULES_DIR="${HOME}/.${AGENT}"
fi
if [[ -z "$GUESS_HOOKS" ]]; then
  GUESS_HOOKS="${HOME}/.${AGENT}/hooks"
fi

ask() {
  local prompt="$1" def="$2" out
  local flag="${3:-}"
  if [[ -t 0 ]] && [[ $FORCE -eq 0 ]] && [[ -z "$flag" ]]; then
    read -r -p "$prompt [$def]: " out
    if [[ -z "$out" ]]; then out="$def"; fi
    echo "$out"
  else
    echo "$def"
  fi
}

if [[ $SKILLS_SET -eq 1 ]]; then SKILLS_DIR="$SKILLS_ARG"; else SKILLS_DIR="$(ask "Skills dir (empty = unsupported)" "$GUESS_SKILLS")"; fi
if [[ $HOOKS_SET -eq 1 ]]; then HOOKS_DIR="$HOOKS_ARG"; else HOOKS_DIR="$(ask "Hooks dir (empty = unsupported)" "$GUESS_HOOKS")"; fi
if [[ $RULES_DIR_SET -eq 1 ]]; then RULES_DIR="$RULES_DIR_ARG"; else RULES_DIR="$(ask "Rules dir (empty = unsupported)" "$GUESS_RULES_DIR")"; fi
if [[ -n "$RULES_FILE_ARG" ]]; then RULES_FILE="$RULES_FILE_ARG"; else RULES_FILE="$(ask "Rules filename" "AGENTS.md")"; fi
if [[ $SUBAGENTS_SET -eq 1 ]]; then SUBAGENTS_DIR="$SUBAGENTS_ARG"; else SUBAGENTS_DIR="$(ask "Subagents dir (empty = unsupported)" "")"; fi
if [[ -n "$BINARY_ARG" ]]; then BINARY="$BINARY_ARG"; else BINARY="$AGENT"; fi
if [[ -n "$DETECT_ARG" ]]; then DETECT_DIR="$DETECT_ARG"; else
  if [[ -n "$RULES_DIR" ]]; then DETECT_DIR="$RULES_DIR"
  elif [[ -n "$SKILLS_DIR" ]]; then DETECT_DIR="$(dirname "$SKILLS_DIR")"
  else DETECT_DIR="$GUESS_BASE"; fi
fi
if [[ -n "$PROJECT_ARG" ]]; then PROJECT_DOT="$PROJECT_ARG"; else PROJECT_DOT=".${AGENT}"; fi

to_home_var() {
  local p="$1"
  case "$p" in
    "$HOME"/*) echo '${HOME}'"${p#$HOME}" ;;
    *) echo "$p" ;;
  esac
}
expand_tilde() {
  local p="$1"
  case "$p" in
    "~"/*) echo "${HOME}${p#\~}" ;;
    "~") echo "$HOME" ;;
    *) echo "$p" ;;
  esac
}
SKILLS_DIR="$(expand_tilde "$SKILLS_DIR")"
HOOKS_DIR="$(expand_tilde "$HOOKS_DIR")"
RULES_DIR="$(expand_tilde "$RULES_DIR")"
SUBAGENTS_DIR="$(expand_tilde "$SUBAGENTS_DIR")"
DETECT_DIR="$(expand_tilde "$DETECT_DIR")"

SKILLS_V="$(to_home_var "$SKILLS_DIR")"
HOOKS_V="$(to_home_var "$HOOKS_DIR")"
RULES_V="$(to_home_var "$RULES_DIR")"
SUBAGENTS_V="$(to_home_var "$SUBAGENTS_DIR")"
DETECT_V="$(to_home_var "$DETECT_DIR")"

echo ""
echo "Proposed registration for '$AGENT':"
echo "  skills:    ${SKILLS_DIR:-‹unsupported›}"
echo "  hooks:     ${HOOKS_DIR:-‹unsupported›}"
echo "  rules:     ${RULES_DIR:-‹unsupported›}/${RULES_FILE}"
echo "  subagents: ${SUBAGENTS_DIR:-‹unsupported›}"
echo "  project:   \$proj/${PROJECT_DOT}/skills/<name>"
echo "  detect:    dir ${DETECT_DIR:-‹none›} + binary $BINARY"
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry-run: showing patch plan, changing nothing)"
fi

DETECT_LINE=""
if [[ -n "$DETECT_DIR" ]]; then
  DETECT_LINE="  [[ -d \"$DETECT_V\" || -n \"\$(command -v $BINARY 2>/dev/null || true)\" ]] && found+=($AGENT)"
elif command -v "$BINARY" >/dev/null 2>&1; then
  DETECT_LINE="  [[ -n \"\$(command -v $BINARY 2>/dev/null || true)\" ]] && found+=($AGENT)"
else
  DETECT_LINE="  [[ -d \"$DETECT_V\" ]] && found+=($AGENT)"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  printf '%s\n' "Patch plan for bin/atlana:"
  printf '%s\n' "  + agent_skills_dir:    $AGENT) echo \"$SKILLS_V\" ;;"
  if [[ -n "$SUBAGENTS_DIR" ]]; then
    printf '%s\n' "  + agent_subagents_dir: $AGENT) echo \"$SUBAGENTS_V\" ;;"
  else
    printf '%s\n' "  + agent_subagents_dir: ‹skip — unsupported›"
  fi
  if [[ -n "$HOOKS_DIR" ]]; then
    printf '%s\n' "  + agent_hooks_dir:     $AGENT) echo \"$HOOKS_V\" ;;"
  else
    printf '%s\n' "  + agent_hooks_dir:     ‹skip — unsupported›"
  fi
  printf '%s\n' "  + agent_rules_dir:     $AGENT) echo \"$RULES_V\" ;;"
  printf '%s\n' "  + agent_rules_file:    $AGENT) echo \"$RULES_FILE\" ;;"
  printf '%s\n' "  + detect_agents:       $DETECT_LINE"
  printf '%s\n' "  + CLI_AGENTS / known:  append $AGENT if missing"
  printf '%s\n' "  + usage --agent:       append \"| $AGENT\""
  printf '%s\n' "  + project skills:      |\$proj/${PROJECT_DOT}/skills/\$name"
  echo ""
  echo "Run without --dry-run to apply."
  exit 0
fi

if [[ $FORCE -eq 0 && -t 0 ]]; then
  read -r -p "Patch bin/atlana to add '$AGENT'? [y/N] " ok
  [[ "$ok" =~ ^[Yy]$ ]] || { echo "aborted."; exit 1; }
fi

ATLANA_BIN="$ATLANA_BIN" AGENT="$AGENT" \
SKILLS_V="$SKILLS_V" HOOKS_V="$HOOKS_V" RULES_V="$RULES_V" RULES_FILE="$RULES_FILE" \
SUBAGENTS_V="$SUBAGENTS_V" DETECT_LINE="$DETECT_LINE" PROJECT_DOT="$PROJECT_DOT" \
python3 - <<'PYEOF'
import os, re, sys

path = os.environ["ATLANA_BIN"]
agent = os.environ["AGENT"]
skills = os.environ.get("SKILLS_V", "")
hooks = os.environ.get("HOOKS_V", "")
rules_dir = os.environ.get("RULES_V", "")
rules_file = os.environ.get("RULES_FILE", "AGENTS.md")
subagents = os.environ.get("SUBAGENTS_V", "")
detect_line = os.environ["DETECT_LINE"]
project_dot = os.environ.get("PROJECT_DOT", "." + agent)

with open(path) as f:
    src = f.read()

changed = []

def insert_case(src, func, new_line):
    marker = "%s() {" % func
    i = src.find(marker)
    if i < 0:
        sys.exit("func not found: %s" % func)
    j = src.find("    *)", i)
    if j < 0:
        sys.exit("fallback not found in %s" % func)
    if re.search(r"^\s+%s\)" % re.escape(agent), src[i:j], re.M):
        return src, False
    return src[:j] + new_line + "\n" + src[j:], True

if skills:
    src, did = insert_case(src, "agent_skills_dir",
        '    %s)   echo "%s" ;;' % (agent, skills))
    changed.append(("skills", did))
if subagents:
    src, did = insert_case(src, "agent_subagents_dir",
        '    %s) echo "%s" ;;' % (agent, subagents))
    changed.append(("subagents", did))
if hooks:
    src, did = insert_case(src, "agent_hooks_dir",
        '    %s)  echo "%s" ;;' % (agent, hooks))
    changed.append(("hooks", did))
if rules_dir:
    src, did = insert_case(src, "agent_rules_dir",
        '    %s)   echo "%s" ;;' % (agent, rules_dir))
    changed.append(("rules_dir", did))
if rules_file:
    src, did = insert_case(src, "agent_rules_file",
        '    %s)   echo "%s" ;;' % (agent, rules_file))
    changed.append(("rules_file", did))

anchor = "  if [[ ${#found[@]} -gt 0 ]]; then"
if ("found+=(%s)" % agent) not in src:
    if anchor not in src:
        sys.exit("detect_agents anchor not found")
    src = src.replace(anchor, detect_line + "\n" + anchor, 1)
    changed.append(("detect", True))
else:
    changed.append(("detect", False))

def append_token_in_parens(src, prefix_re, token):
    """Find PREFIX=(a b c) and append token before ) if missing."""
    pat = re.compile(prefix_re + r"\(([^)]*)\)")
    m = pat.search(src)
    if not m:
        return src, False
    inner = m.group(1)
    parts = inner.split()
    if token in parts:
        return src, False
    new_inner = (inner.rstrip() + " " + token).strip()
    start, end = m.span()
    # rebuild using the matched prefix text + new parens
    full = m.group(0)
    new_full = full[:full.index("(") + 1] + new_inner + ")"
    return src[:start] + new_full + src[end:], True

src, did = append_token_in_parens(src, r"CLI_AGENTS=", agent)
changed.append(("CLI_AGENTS", did))
src, did = append_token_in_parens(src, r"local known=", agent)
changed.append(("known", did))

# usage: --agent line, append " | name" before end if missing
usage_pat = re.compile(r"(--agent <a>\s+)([^\n]+)")
um = usage_pat.search(src)
if um:
    line = um.group(2)
    if ("| %s" % agent) not in line and not re.search(r"\b%s\b" % re.escape(agent), line):
        # keep trailing bits; insert before optional leftover
        src = src[:um.start(2)] + line.rstrip() + " | %s" % agent + src[um.end(2):]
        changed.append(("usage", True))
    else:
        changed.append(("usage", False))
else:
    changed.append(("usage", False))

# project-local skills fan-out: any "$proj/.…/skills/$name|..." string
proj_pat = re.compile(r'"(\$proj/\.[^"]+/skills/\$name(?:\|\$proj/\.[^"]+/skills/\$name)*)"')
pm = proj_pat.search(src)
if pm:
    blob = pm.group(1)
    piece = "$proj/%s/skills/$name" % project_dot
    if piece not in blob:
        src = src[:pm.start(1)] + blob + "|" + piece + src[pm.end(1):]
        changed.append(("project", True))
    else:
        changed.append(("project", False))
else:
    changed.append(("project", False))

with open(path, "w") as f:
    f.write(src)

print("patched: " + ", ".join("%s=%s" % (k, "yes" if d else "skip") for k, d in changed))
PYEOF

chmod +x "$ATLANA_BIN"
bash -n "$ATLANA_BIN" || { echo "Error: syntax check failed after patch" >&2; exit 1; }

echo ""
echo "✓ agent '$AGENT' registered in bin/atlana."
echo "  Verify:  bash -n bin/atlana && ./bin/atlana agents"
echo "  Review:  git diff bin/atlana"
echo "  Docs:    update README.md install table + PORTING.md in the same change."
