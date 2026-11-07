# Atlana Prototype

**Atlana** is a portable environment for AI coding agents: **skills**, **rules**, **hooks**, and **subagents**, managed by one CLI and installed into every agent on your machine (or into a project).

This repository is the **empty framework**: the CLI, the hook and MCP plumbing, and the docs, with **no skills**. Fork it, add only what you want, and keep your environment in your own git repo. (The author's full setup lives in [uminocelo/atlana](https://github.com/uminocelo/atlana).)

Works with **Crush** (Charmbracelet), **Cursor**, **Claude Code**, **OpenCode**, **Grok**, and any agent that loads [Agent Skills](https://agentskills.io) (`SKILL.md`) and common context files (`AGENTS.md` / `CLAUDE.md`).

| Doc | Topic |
|-----|--------|
| [PORTING.md](PORTING.md) | Map rules / hooks / subagents across agents |
| [docs/SYNC.md](docs/SYNC.md) | Bidirectional sync details |
| [hooks/README.md](hooks/README.md) | Hook wire-up for Crush / Claude Code / OpenCode |
| [mcp/README.md](mcp/README.md) | MCP server: tools, resources, safety model |
| [command/README.md](command/README.md) | `atlana <command>` shortcuts |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |

---

## Requirements

- **Bash 3.2+** (macOS stock Bash is fine — no associative arrays required)
- `git`
- Optional: `sha256sum` (used by `sync`; usually present via coreutils)
- Optional: Python 3.10+ for the MCP server (`mcp/`) and `utils/add-agent.sh`

---

## Quick start

1. **Fork** this repository on GitHub, then clone your fork:

   ```bash
   git clone https://github.com/<you>/atlana-prototype.git atlana
   cd atlana
   chmod +x bin/atlana hooks/*.sh command/* utils/*.sh
   ```

2. **Make it yours** (see [Make it yours](#make-it-yours)): add skills, edit `rules/AGENTS.md`, keep or delete the examples, and point `install.sh` at your fork.

3. **Install** into your agents:

   ```bash
   ./bin/atlana                      # interactive: action → component → agent
   ./bin/atlana agents               # which agents are on this machine

   ./bin/atlana install \
     --component skills --component hooks --component rules --component subagents \
     --agent all --all --force
   ```

4. Optional: put `atlana` on your `PATH` with `./bin/atlana install-cli` (symlinks to `~/.local/bin/atlana`).

---

## Make it yours

| Step | What to do |
|------|------------|
| **Skills** | Add one folder per skill: `skills/<name>/SKILL.md` (kebab-case, top level). Or import one you already use: `./bin/atlana add --component skills --from ~/path/to/my-skill`. Format rules are in [CONTRIBUTING.md](CONTRIBUTING.md#skill-format-checklist-for-skills-in-your-fork). |
| **Rules** | Fill in `rules/AGENTS.md` (stack, commands, conventions). Keep `rules/CLAUDE.md` in sync with it. |
| **Hooks** | Keep `hooks/block-destructive.sh`, adjust its patterns, or add your own guardrails. |
| **Subagents** | `explorer`, `reviewer`, and `planner` are generic. The `elixir-*` ones are **examples**; delete them if you don't write Elixir. |
| **Dotfiles** | `dotfile/neovim/` is an **example** Neovim config. Replace it with yours or delete it (and `command/install-neovim`, `command/sync-neovim`). |
| **MCP** | Optional. Add tools for your own stack to `mcp/server.py`. |
| **Agents** | Missing an agent? `./bin/atlana add-agent <name>` patches the CLI for it. |
| **Bootstrap URL** | In `install.sh`, set `REPO_URL` to your fork so the one-liner installs *your* environment. |

---

## Layout

```
atlana/
├── bin/atlana              # CLI (install | add | remove | sync | list | agents | <command>)
├── skills/                 # your Agent Skills (empty: add your own)
├── subagents/              # Claude-style agent markdown
│   ├── explorer.md  reviewer.md  planner.md        # generic
│   └── elixir-writer.md  elixir-reviewer.md  elixir-business-validator.md   # examples
├── hooks/                  # PreToolUse scripts (Crush + Claude compatible)
│   └── block-destructive.sh
├── rules/                  # AGENTS.md, CLAUDE.md (templates for your projects)
├── mcp/                    # MCP server exposing skills/hooks/rules (atlana mcp)
├── command/                # shortcuts: atlana <name> (mcp, add-agent, install-cli, …)
├── utils/                  # add-agent.sh, install-cli.sh, install-mcp.sh
├── dotfile/                # editor configs (example: neovim/)
├── agents/                 # reserved for future agent profiles
├── templates/crush.json    # Crush config wiring skills paths + hooks
├── docs/SYNC.md
├── PORTING.md
└── install.sh              # thin wrapper → bin/atlana install
```

---

## CLI

```text
atlana                              Interactive mode
atlana <action> [options] [names…]

Actions:
  install     Atlana → agent(s) or project
  add         Import a path into Atlana (optional install after)
  remove      Remove from agents and/or the Atlana repo
  sync        Bidirectional sync (see --direction / docs/SYNC.md)
  list        List items in Atlana
  agents      Detect agents on this machine
  commands    List command/ shortcuts
  help

Options:
  --component <c>    skills | subagents | hooks | rules   (repeatable)
  --agent <a>        crush | cursor | claude | opencode | grok | agents | all
  --project [dir]    Project-local targets (default: cwd)
  --all              All items of the selected component(s)
  --force            Skip confirmations (required when not on a TTY)
  --dry-run          Print actions only
  --from <path>      Source for add
  --direction <d>    sync: push | pull | both (default: both)
  --prefer <p>       sync conflicts: atlana | agent | ask (default: ask)
  --json             Machine-readable output (list / agents)
```

### Examples

```bash
# Import a skill you already use, then install it to Crush
./bin/atlana add --component skills --from ~/Projects/banana/my-skill --agent crush --force

# Install one skill everywhere
./bin/atlana install my-skill --component skills --agent all --force

# Install everything into the current project (team-friendly)
./bin/atlana install \
  --component skills --component hooks --component rules --component subagents \
  --project --all --force

# Remove one skill from Cursor
./bin/atlana remove my-skill --component skills --agent cursor --force

# Sync skills both ways with every known agent
./bin/atlana sync --component skills --agent all --direction both

# Pull edits made inside an agent back into the repo (review with git diff)
./bin/atlana sync --component skills --agent crush --direction pull --prefer agent --force
```

Non-interactive runs must pass `--force`: without a TTY, confirmations answer "no" and overwrites are skipped.

---

## One-liner bootstrap

After setting `REPO_URL` in `install.sh` to your fork:

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/atlana-prototype/main/install.sh \
  | bash -s -- --agent cursor --force
```

`install.sh` always installs all four components (skills, hooks, rules, subagents) with `--all` and forwards extra flags. Use `bin/atlana` directly for selective installs.

---

## Components

### Skills

Empty on purpose. Each skill is a folder with a `SKILL.md` (YAML frontmatter `name` + `description`, then instructions), optionally with `references/`, `scripts/`, or `assets/`. Agents load a skill when its `description` matches the task, so write descriptions that say *when* to use it.

### Rules

- Source of truth: `rules/AGENTS.md` (a template with placeholders for your stack)
- `rules/CLAUDE.md` mirrors it for Claude Code
- Install maps it to agent-specific names (`CRUSH.md`, `CLAUDE.md`, project `AGENTS.md`, …)

### Hooks

Deterministic guardrails (exit `2` = deny). Compatible with Crush and Claude Code `PreToolUse`:

| Script | Purpose |
|--------|---------|
| `block-destructive.sh` | Blocks `rm -rf /`, force-push, `reset --hard`, etc. |

Wire-up examples: `hooks/README.md` and `templates/crush.json`.

### Subagents

Markdown agents under `subagents/` (Claude Code `.claude/agents/`):

| File | Role |
|------|------|
| `explorer.md` | Read-only research |
| `reviewer.md` | Post-change review |
| `planner.md` | Structured plan in an isolated session (chat only) |
| `elixir-writer.md` | *Example:* idiomatic Elixir implementation + tests |
| `elixir-reviewer.md` | *Example:* Elixir review (logic, DRY, boundaries, OTP/Ecto) |
| `elixir-business-validator.md` | *Example:* validate business rules vs code |

Crush uses built-in **coder** / **task** agents; encode specialized behavior with skills + rules there.

### MCP server

`atlana mcp` starts a stdio MCP server (`mcp/server.py`) that serves your skills, hooks, rules, and commands to any MCP client, and offers framework tools (sync status, skill diff, hook testing, test runner, read-only DB queries, …). Set it up and register it with Claude Code:

```bash
./utils/install-mcp.sh
claude mcp add atlana -s user -- /absolute/path/to/atlana/bin/atlana mcp
```

Tools, resources, the safety model, and how to keep API tokens out of config files: [`mcp/README.md`](mcp/README.md).

### Commands

Executables in `command/` become `atlana <name>`: `mcp`, `add-agent`, `install-cli`, `sync-skills` / `sync-skills-push` / `sync-skills-pull`, and the Neovim example's `install-neovim` / `sync-neovim`. Add your own the same way. `atlana commands` lists them.

---

## Where things install

| Agent | Skills | Hooks | Rules file | Subagents |
|-------|--------|-------|------------|-----------|
| Crush | `~/.config/crush/skills` | `~/.config/crush/hooks` | `~/.config/crush/CRUSH.md` | (built-in only) |
| Cursor | `~/.cursor/skills` | — | `~/.cursor/rules/AGENTS.md` | — |
| Claude Code | `~/.claude/skills` | `~/.claude/hooks` | `~/.claude/CLAUDE.md` | `~/.claude/agents` |
| OpenCode | `~/.config/opencode/skills` | — | `~/.config/opencode/AGENTS.md` | — |
| Grok | `~/.grok/skills` | — | `~/.grok/AGENTS.md` | — |
| Generic | `~/.agents/skills` | — | `~/.agents/AGENTS.md` | — |
| **Project** (`--project`) | `.cursor/skills`, `.crush/skills`, `.claude/skills`, `.agents/skills` | `./hooks` | `./AGENTS.md` | `.claude/agents` |

---

## Design principles

- **One source of truth** — your environment lives in git; agents get copies.
- **Bring your own content** — the framework ships no opinions you have to delete.
- **No unsolicited commits** — agents commit only when asked.
- **Hooks for must-never** — prompts are soft; hooks are hard.
- **Portable** — markdown + YAML frontmatter; Bash 3.2+ CLI.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
