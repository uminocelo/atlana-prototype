# Porting Atlana across agents

Atlana is built on the **Agent Skills** open standard plus portable context and hooks. Map each layer once and reuse it.

## Layer map

| Layer | Role | Crush | Claude Code | OpenCode | Cursor | Grok |
|-------|------|-------|-------------|----------|--------|------|
| **Rules** | Always-on soft guidance | `AGENTS.md`, `CRUSH.md`, `context_paths` | `CLAUDE.md`, `.claude/rules/` | `AGENTS.md` (or `CLAUDE.md`) | `.cursorrules`, `.cursor/rules/` | `AGENTS.md` (`~/.grok/`, repo root → cwd) |
| **Skills** | On-demand procedures | `.crush/skills`, `.agents/skills`, … | `.claude/skills` | `.opencode/skills`, `.claude/skills` | `.cursor/skills` | `.grok/skills`, `~/.grok/skills`, `~/.claude/skills` |
| **Hooks** | Hard enforcement | `PreToolUse` in `crush.json` / `crushrc` | `PreToolUse` (+ more events) in `.claude/settings.json` | `tool.execute.before` (plugin/config) | Limited / rules-based | `[[hooks.PreToolUse]]` in `~/.grok/config.toml`, `.grok/hooks/` |
| **Subagents** | Isolated workers | Built-in **coder** + **task** (`agent` tool) | `.claude/agents/*.md` | Agent configs / skills | Composer / rules | Agent profiles in `.grok/agents/` |

## Recommended project layout

```
your-project/
├── AGENTS.md                 # portable rules (source of truth)
├── CLAUDE.md → AGENTS.md     # symlink for Claude Code
├── hooks/                    # shared shell hooks (Crush + Claude compatible)
│   └── block-destructive.sh
├── .crush.json               # or crushrc — hooks + skill paths (Crush)
├── .claude/
│   ├── settings.json         # hooks for Claude Code
│   ├── skills/               # or symlink to shared skills
│   └── agents/               # explorer, reviewer, planner
├── skills/ in Atlana repo → installed to .agents/skills/ etc. skills (or symlink)
├── .crush/skills/
└── .cursor/skills/
```

Install your Atlana skills, hooks, rules, and subagents into the project (point the URL at your fork):

```bash
curl -fsSL https://raw.githubusercontent.com/uminocelo/atlana-prototype/main/install.sh | bash -s -- --project --force
```

## Rules

1. Maintain **one** `AGENTS.md` at the repo root.
2. For Claude Code:

   ```bash
   ln -sf AGENTS.md CLAUDE.md
   ```

3. Crush already prefers `AGENTS.md` by default (`initialize_as`).

## Skills

Same `SKILL.md` folders work everywhere Agent Skills are supported.

```bash
# From Atlana repo or any skill source
./skill-manager.sh --scan . --to project --project /path/to/app --force
# or global for Crush
./bin/atlana install my-skill --component skills --agent crush --force
```

## Hooks

Scripts under `hooks/` use exit code **2** to deny (Crush + Claude Code).

| Agent | Wire-up |
|-------|---------|
| **Crush** | Copy `templates/crush.json` → `.crush.json`, or `hook add` in `crushrc` (see `hooks/README.md`) |
| **Claude Code** | `.claude/settings.json` PreToolUse entries pointing at the same scripts |
| **OpenCode** | In a plugin, on `tool.execute.before`, run the script; if exit code is 2, reject the tool call |

Crush only exposes **PreToolUse** today; Claude Code also has PostToolUse, Stop, SessionStart, etc. Keep shared policy in PreToolUse so one script serves both.

## Subagents

### Crush

Crush ships two agents:

- **coder** — full tools (implementation)
- **task** — read-only tools (explore / research)

The main agent spawns work via the **`agent`** tool. You cannot yet drop custom markdown agents like Claude Code; encode specialized behavior as **skills** + AGENTS.md guidance (“use the task agent for broad exploration”).

### Claude Code

Custom agents live in `.claude/agents/`:

| File | Role |
|------|------|
| `explorer.md` | Read-only survey |
| `reviewer.md` | Post-change review |
| `planner.md` | Structured plan in an isolated session (chat only) |
| `elixir-writer.md` | *Example:* idiomatic Elixir implementation + tests |
| `elixir-reviewer.md` | *Example:* Elixir review: logic, DRY, boundaries, OTP/Ecto |
| `elixir-business-validator.md` | *Example:* validate business rules vs code |

Install them with `./bin/atlana install --component subagents --agent claude --all --force` (or `--project`).

### OpenCode

Prefer **AGENTS.md** + **skills**. Where OpenCode supports custom agents, mirror the explorer/reviewer prompts from `.claude/agents/`.

### Grok

Atlana installs **skills** to `~/.grok/skills` and **rules** to `~/.grok/AGENTS.md` (`--agent grok`). Grok also reads `~/.claude/skills`, so a skill present in both places is deduplicated by Grok; keep the copies identical via `sync`. Hooks are declared as `[[hooks.PreToolUse]]` in `~/.grok/config.toml` (or `.grok/hooks/` per project, after `/hooks-trust`) pointing at the Atlana hook scripts; Atlana does not wire them automatically. `~/.grok/agents/` holds agent *profiles*, not Claude-style subagents, so subagents are not installed.

## Mental model (best environment)

```
AGENTS.md     →  what the model should always know
Skills        →  multi-step workflows loaded on demand (your skills/)
Hooks         →  what must never happen (rm -rf /, force push, …)
Subagents     →  isolated context for research/review so the main thread stays clean
```

Prompts are probabilistic. Hooks are deterministic. Use both.
