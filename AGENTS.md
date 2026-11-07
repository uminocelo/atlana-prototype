# AGENTS.md — working in the Atlana Prototype repository

Atlana Prototype is the **empty framework** of Atlana, a portable agent
environment: a Bash CLI that installs/syncs **skills**, **rules**, **hooks**,
and **subagents** into coding agents (Crush, Cursor, Claude Code, OpenCode,
Grok) and into project directories. It ships **no skills**; people fork it and
add their own. There is no application runtime.

This file is for agents editing **this repository**. It is unrelated to
`rules/AGENTS.md`, which is a *template* distributed to consumer projects.

## Repo map

| Path | What it is |
|------|------------|
| `bin/atlana` | The CLI (single Bash script, `VERSION=0.3.0`). Actions: `install`, `add`, `remove`, `sync`, `list`, `agents`, `commands`, `help`; any other first argument runs `command/<name>`. |
| `skill-manager.sh` | Deprecated wrapper that execs `bin/atlana`; keep behavior compatible or remove, never fork logic. |
| `install.sh` | Thin bootstrap for the `curl \| bash` flow. Hardcodes `--component skills --component hooks --component rules --component subagents --all` and appends extra `"$@"`. `REPO_URL` is meant to be changed by forks. |
| `skills/` | **Empty on purpose** (`.gitkeep`). Do not add skills to this repo; forks add theirs as `skills/<name>/SKILL.md`. |
| `subagents/*.md` | Claude-style agent markdown. `explorer`, `reviewer`, `planner` are generic; `elixir-*` are **examples**. |
| `hooks/block-destructive.sh` | Example PreToolUse guardrail; exit `2` denies. |
| `rules/AGENTS.md`, `rules/CLAUDE.md` | **Distributed templates**, not repo guidance. Placeholders (`<!-- Replace with your real project values -->`) are intentional. Keep the two files identical. |
| `mcp/` | MCP server (`server.py`, Python; `typescript/` is a smaller port). Generic framework tools only. |
| `command/` | Executables run as `atlana <name>` (`mcp`, `add-agent`, `install-cli`, `sync-skills*`, Neovim example shortcuts). |
| `utils/` | `add-agent.sh` (patches `bin/atlana` for a new agent), `install-cli.sh`, `install-mcp.sh`. |
| `dotfile/neovim/` | **Example** Neovim config; personal overrides go in `lua/user/`. |
| `templates/crush.json` | Example Crush config wiring `context_paths`, `skills_paths`, and the hook. |
| `docs/SYNC.md`, `PORTING.md`, `README.md`, `CONTRIBUTING.md` | Behavior/contract docs. Keep them in sync with `bin/atlana`. |
| `agents/` | Reserved/empty (`.gitkeep`). |

## Essential commands

```bash
chmod +x bin/atlana hooks/*.sh command/* utils/*.sh   # after a fresh clone

./bin/atlana help
./bin/atlana list --component subagents     # also: skills | hooks | rules
./bin/atlana agents                         # detect installed agents (+ --json)
./bin/atlana commands                       # list command/ shortcuts

# Exercise in a throwaway project
./bin/atlana install --component skills --component hooks --component rules --component subagents \
  --project /tmp/atlana-test --all --force
```

There is **no build step, no test suite, and no CI**. Verification is manual:
`bash -n bin/atlana hooks/*.sh utils/*.sh command/*`, then run the CLI in a
throwaway project. Always test with the **empty** `skills/` folder too: it is
the state every fork starts in.

## Non-obvious behavior and gotchas

- **Non-interactive runs must pass `--force`.** `confirm()` returns false when
  stdin is not a TTY, so without `--force` overwrites are silently skipped and
  `add` aborts.
- **Bash 3.2 compatibility is a hard constraint** (macOS stock Bash, no
  associative arrays). Under `set -u`, Bash 3.2 treats an empty array as
  unbound, so every expansion of an array that can be empty needs the guard
  `"${arr[@]+"${arr[@]}"}"`. This matters more here than in a full Atlana,
  because `skills/` starts empty.
- **`sync` hashing relies on `sha256sum`**. On macOS without coreutils the hash
  is empty, so existing-but-mismatched items are reported as `differ` and, with
  `--prefer atlana --force`, can be overwritten.
- **`install.sh` always installs all four components**, even when the caller
  passes `--component`. Use `bin/atlana` directly for selective installs.
- **`rules` installs `rules/AGENTS.md`**, remapped per agent: Crush `CRUSH.md`,
  Claude `CLAUDE.md`, Cursor `rules/AGENTS.md`, OpenCode/generic `AGENTS.md`,
  project `./AGENTS.md`.
- **Agent support is asymmetric:** subagents only for `claude`; hooks only for
  `crush` and `claude`; `grok` gets skills + rules only.
- **Project installs fan out**: a skill lands in `.cursor/skills`,
  `.crush/skills`, `.agents/skills`, and `.claude/skills`.
- **`pull` writes into the git tree.** Inspect `git status` / `git diff` before
  committing; never commit on the user's behalf.
- `list_atlana_items` discovers skills by `find`ing directories at depth 1
  only, so a skill must be a top-level directory.

## What belongs here

- Framework changes (CLI, hooks plumbing, MCP server, utils, docs) that help
  every fork.
- **Not** personal skills, personal MCP tools, or personal configs. Examples
  must be clearly labeled and easy to delete; when adding one, document how to
  remove it in `README.md` ("Make it yours").
- No personal paths, usernames, or tokens anywhere (`/Users/<name>`, private
  repo links). Use placeholders like `/absolute/path/to/atlana`.

## Hook contract

- Hooks read the command/path from env vars first
  (`CRUSH_TOOL_INPUT_COMMAND`, `CLAUDE_TOOL_INPUT_COMMAND`, `CRUSH_TOOL_NAME`,
  `CRUSH_TOOL_INPUT_FILE_PATH`) and otherwise parse JSON on stdin with
  `python3`.
- Exit `0` allows, exit `2` denies; write the reason to stderr.
- Keep shared policy in `PreToolUse` so one script serves Crush (PreToolUse
  only) and Claude Code. Update `hooks/README.md` and `templates/crush.json`
  when adding a hook.

## Style

- Bash: `set -euo pipefail`, small `snake_case` functions grouped by area
  (`agent_*`, `do_*`, `*_interactive`), human output via `log` / `warn` / `die`.
  Prefer explicit `local` declarations.
- Python: standard library only in `utils/`; `mcp/` depends only on `mcp[cli]`.
- Docs are the spec: when CLI behavior changes, update `README.md`,
  `docs/SYNC.md`, and `PORTING.md` in the same change.
- No unsolicited commits; commit only when explicitly asked.
