# Atlana

**Atlana** is a single-file Bash CLI that manages a portable environment for AI coding agents: **skills**, **subagents**, **hooks**, and **rules** — from one repo, across every agent on your machine.

Primary target: **Crush** (Charmbracelet). Also works with **Cursor**, **Claude Code**, **OpenCode**, and any agent that loads [Agent Skills](https://agentskills.io) (`SKILL.md`) and common context files (`AGENTS.md` / `CLAUDE.md`).

| Doc | Topic |
|-----|-------|
| [PORTING.md](PORTING.md) | Map rules / hooks / subagents across agents |
| [docs/SYNC.md](docs/SYNC.md) | Bidirectional sync details |
| [hooks/README.md](hooks/README.md) | Hook wire-up for Crush / Claude Code / OpenCode |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |

---

## Why

Every coding agent keeps its own config in its own place. Atlana gives you:

- **One source of truth** — your skills, rules, hooks, and subagent definitions live here, versioned with git.
- **Many targets** — install the same component to Crush, Cursor, Claude Code, OpenCode, or all of them at once.
- **Bidirectional sync** — content-hash based (`sha256`, not mtime), so experiments done inside an agent can be pulled back into the repo safely.
- **Zero dependencies** — plain Bash 3.2+ (macOS stock Bash works). Markdown + YAML frontmatter everywhere else.

---

## Requirements

- **Bash 3.2+** — no associative arrays used
- `git` — for the clone-based install
- Optional: `sha256sum` — required by `sync` (usually present via coreutils)

```bash
bash --version   # 3.2+ is enough
```

---

## Quick start

```bash
git clone https://github.com/uminocelo/atlana-prototype.git
cd atlana
chmod +x bin/atlana

# Interactive: component → action → agent
./bin/atlana

# Or explicit — new machine, skills + hooks → Cursor only
./bin/atlana install \
  --component skills --component hooks \
  --agent cursor --all --force
```

Day-to-day, just run `./bin/atlana` (or symlink `bin/atlana` somewhere on your `PATH`). `install.sh` is only a thin bootstrap that calls `bin/atlana install …`.

Restart your agents after installing so they rediscover new files.

### One-liner bootstrap

```bash
git clone --depth 1 https://github.com/uminocelo/atlana-prototype.git /tmp/atlana \
  && /tmp/atlana/install.sh --agent cursor --force \
  && rm -rf /tmp/atlana
```

Or piped:

```bash
curl -fsSL https://raw.githubusercontent.com/uminocelo/atlana-prototype/main/install.sh \
  | bash -s -- --agent cursor --force
```

`install.sh` installs all four components (`--all`) and forwards any extra flags to `bin/atlana install`.

---

## What Atlana manages

| Component | Format | Used by |
|-----------|--------|---------|
| **Skills** | Folders with `SKILL.md` ([Agent Skills](https://agentskills.io)) | All supported agents |
| **Subagents** | Markdown agents with YAML frontmatter | Claude Code (`.claude/agents/`) |
| **Hooks** | Shell scripts, exit `2` = deny | Crush + Claude Code (`PreToolUse`) |
| **Rules** | `AGENTS.md` context file, mapped to agent-specific names | All supported agents |

Atlana ships examples for **subagents** (`subagents/explorer.md`, `reviewer.md`, `planner.md`), **rules** (`rules/AGENTS.md` mirrored as `rules/CLAUDE.md`), and hook wiring (`templates/crush.json`). Skills and hook scripts are yours to add — see below.

### Adding your own

```bash
# Import a skill folder from another project into Atlana, then install to Crush
./bin/atlana add --component skills --from ~/Projects/banana/my-skill --agent crush --force

# Import a hook script
./bin/atlana add --component hooks --from ~/scripts/block-destructive.sh
```

Anything under `skills/` (a directory with `SKILL.md`), `hooks/*.sh`, `rules/*.md`, or `subagents/*.md` becomes manageable automatically.

---

## Layout

```
atlana/
├── bin/atlana              # The CLI (single file, Bash 3.2+)
├── skills/                 # Agent Skills — add your own SKILL.md folders
├── subagents/              # Claude-style agent markdown
│   ├── explorer.md         #   read-only research
│   ├── reviewer.md         #   post-change review
│   └── planner.md          #   isolated planning session
├── hooks/                  # PreToolUse scripts (exit 2 = deny)
│   └── README.md           #   wiring guide for Crush / Claude / OpenCode
├── rules/                  # Context files
│   ├── AGENTS.md           #   source of truth
│   └── CLAUDE.md           #   mirror for Claude Code
├── agents/                 # reserved for future agent profiles
├── templates/
│   └── crush.json          # Example Crush config (hooks + skill paths)
├── docs/SYNC.md            # Bidirectional sync reference
├── PORTING.md              # Cross-agent mapping guide
├── install.sh              # Thin bootstrap → bin/atlana install
└── skill-manager.sh        # Deprecated wrapper → bin/atlana
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
  list        List items in Atlana (--json supported)
  agents      Detect agents on this machine (--json supported)
  help

Options:
  --component <c>    skills | subagents | hooks | rules   (repeatable)
  --agent <a>        crush | cursor | claude | opencode | agents | all
  --project [dir]    Project-local targets (default: cwd)
  --all              All items of the selected component(s)
  --force            Skip confirmations
  --dry-run          Print actions only
  --from <path>      Source for add
  --direction <d>    sync: push | pull | both (default: both)
  --prefer <p>       sync conflicts: atlana | agent | ask (default: ask)
  --json             Machine-readable output (list / agents)
  --version
```

### Examples

```bash
# Inventory
./bin/atlana list --component skills
./bin/atlana agents

# Install everything into the current project (team-friendly, committed to git)
./bin/atlana install \
  --component skills --component hooks --component rules --component subagents \
  --project --all --force

# Install skills + hooks to Crush only
./bin/atlana install --component skills --component hooks --agent crush --all --force

# Remove one skill from Cursor
./bin/atlana remove my-skill --component skills --agent cursor --force

# Preview before touching anything
./bin/atlana sync --component skills --agent all --dry-run

# Sync skills both ways with every known agent
./bin/atlana sync --component skills --agent all --direction both

# Deploy-only (never overwrite Atlana from agents)
./bin/atlana sync --component skills --component hooks \
  --agent cursor --direction push --force
```

### Sync model

Each `(component, item, target)` pair is compared by content hash:

| State | Action in `both` (default) |
|-------|----------------------------|
| identical | no-op |
| only in Atlana | push → agent |
| only on agent | pull → Atlana |
| differ | conflict → resolved by `--prefer` |

With `--prefer ask` (default) conflicts prompt interactively; `--force` falls back to *Atlana wins*. See [docs/SYNC.md](docs/SYNC.md).

---

## Where things install

| Agent | Skills | Hooks | Rules file | Subagents |
|-------|--------|-------|------------|-----------|
| Crush | `~/.config/crush/skills` | `~/.config/crush/hooks` | `~/.config/crush/CRUSH.md` | built-in only |
| Cursor | `~/.cursor/skills` | — | `~/.cursor/rules/AGENTS.md` | — |
| Claude Code | `~/.claude/skills` | `~/.claude/hooks` | `~/.claude/CLAUDE.md` | `~/.claude/agents` |
| OpenCode | `~/.config/opencode/skills` | — | `~/.config/opencode/AGENTS.md` | — |
| Generic | `~/.agents/skills` | — | `~/.agents/AGENTS.md` | — |
| **Project** (`--project`) | `.cursor/skills`, `.crush/skills`, `.claude/skills`, `.agents/skills` | `./hooks` | `./AGENTS.md` | `.claude/agents` |

Rules always install as the agent's expected filename (e.g. `CRUSH.md` for Crush), using `rules/AGENTS.md` as the source of truth.

Not every agent supports every component — unsupported combinations are skipped with a warning (e.g. custom subagents only exist for Claude Code today). See [PORTING.md](PORTING.md) for the full mapping and workarounds.

---

## Typical workflow

1. **Detect** what's installed — `./bin/atlana agents`
2. **Populate** the repo — `add` your best skills/hooks/rules once
3. **Deploy** — `install` to machines and projects (`--project` for team-shared configs committed alongside the code)
4. **Converge** — `sync` pulls improvements made inside agents back into the repo, pushes fixes out
5. **Version** — everything is plain text in git; review diffs, commit, repeat

---

## Design principles

- **Portable formats only** — Agent Skills folders, plain markdown, shell scripts. No proprietary lock-in.
- **Deterministic where it matters** — hooks enforce hard limits outside the model; prompts stay soft.
- **Content-based sync** — `sha256` hashes, never mtimes; clock skew can't create false conflicts.
- **Safe by default** — confirmations on destructive actions, `--dry-run` everywhere, explicit direction control.
- **One file CLI** — Bash 3.2+, no build step, easy to audit.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
