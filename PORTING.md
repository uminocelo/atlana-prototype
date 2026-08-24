# Porting Atlana across agents

Atlana is built on portable layers: **Agent Skills** (`SKILL.md`), context files (`AGENTS.md`), deterministic hooks (exit `2` = deny), and markdown subagents. Map each layer once and reuse it everywhere.

## Layer map

| Layer | Role | Crush | Claude Code | OpenCode | Cursor |
|-------|------|-------|-------------|----------|--------|
| **Rules** | Always-on soft guidance | `AGENTS.md`, `CRUSH.md`, `context_paths` | `CLAUDE.md`, `.claude/rules/` | `AGENTS.md` (or `CLAUDE.md`) | `.cursorrules`, `.cursor/rules/` |
| **Skills** | On-demand procedures | `.crush/skills`, `.agents/skills`, … | `.claude/skills` | `.opencode/skills`, `.claude/skills` | `.cursor/skills` |
| **Hooks** | Hard enforcement | `PreToolUse` in `crush.json` / crushrc | `PreToolUse` (+ more events) in `.claude/settings.json` | `tool.execute.before` (plugin/config) | Limited / rules-based |
| **Subagents** | Isolated workers | Built-in **coder** + **task** (via `agent` tool) | `.claude/agents/*.md` | Agent configs / skills | Composer / rules |

## Recommended project layout

```
your-project/
├── AGENTS.md                 # portable rules (source of truth)
├── CLAUDE.md → AGENTS.md     # symlink for Claude Code
├── hooks/                    # shared guardrail scripts (Crush + Claude compatible)
├── .crush.json               # or crushrc — hooks + skill paths (Crush)
├── .claude/
│   ├── settings.json         # hooks for Claude Code
│   └── agents/               # explorer.md, reviewer.md, planner.md
├── .crush/skills/
├── .cursor/skills/
└── .agents/skills/
```

Install Atlana's components into the project:

```bash
./bin/atlana install \
  --component skills --component hooks --component rules --component subagents \
  --project --all --force
```

This writes skills to all four project skill dirs, hooks to `./hooks`, rules to `./AGENTS.md`, and subagents to `.claude/agents/`.

## Rules

1. Maintain **one** `AGENTS.md` at the repo root — Atlana treats `rules/AGENTS.md` as the source of truth.
2. For Claude Code:

   ```bash
   ln -sf AGENTS.md CLAUDE.md
   ```

3. Crush already prefers `AGENTS.md` by default.
4. When installing via Atlana, each agent gets its expected filename automatically: `CRUSH.md` for Crush, `CLAUDE.md` for Claude Code, `rules/AGENTS.md` for Cursor, `AGENTS.md` for OpenCode.

## Skills

The same `SKILL.md` folders work everywhere Agent Skills are supported. No conversion needed.

```bash
# Import a skill from any project into Atlana, then install it to Crush
./bin/atlana add --component skills --from ~/Projects/banana/my-skill --agent crush --force

# Deploy every Atlana skill to every detected agent
./bin/atlana sync --component skills --agent all --force
```

For agents without native skills support, encode the procedure as a rule section or a project doc and reference it from `AGENTS.md`.

## Hooks

Scripts use exit code **2** to deny — identical semantics in Crush and Claude Code, so one script serves both.

| Agent | Wire-up |
|-------|---------|
| **Crush** | Copy `templates/crush.json` → `.crush.json`, or `hook add` in crushrc (see [hooks/README.md](hooks/README.md)) |
| **Claude Code** | `.claude/settings.json` PreToolUse entries pointing at the same scripts |
| **OpenCode** | In a plugin on `tool.execute.before`, run the script; reject the tool call when exit code is `2` |

Crush exposes **PreToolUse** only today; Claude Code also has PostToolUse, Stop, SessionStart, etc. Keep shared policy in PreToolUse so one script serves both, and put agent-specific logic behind environment checks if needed.

## Subagents

### Crush

Crush ships two built-in agents:

- **coder** — full tools (implementation)
- **task** — read-only tools (explore / research)

The main agent spawns work via the **`agent`** tool. Custom markdown agents are not supported yet; encode specialized behavior as **skills** plus `AGENTS.md` guidance ("use the task agent for broad exploration").

### Claude Code

Custom agents live in `.claude/agents/`. Atlana ships three under `subagents/`:

| File | Role |
|------|------|
| `explorer.md` | Read-only survey and research |
| `reviewer.md` | Post-change correctness / security review |
| `planner.md` | Structured planning in an isolated session |

Install them with:

```bash
./bin/atlana install --component subagents --agent claude --all --force
# or project-local:
./bin/atlana install --component subagents --project --all --force
```

### OpenCode

Prefer **AGENTS.md** + **skills**. Where OpenCode supports custom agents, mirror the explorer/reviewer prompts from `subagents/`.

## Mental model

```
Rules      →  what the model should always know
Skills     →  multi-step workflows loaded on demand
Hooks      →  what must never happen (deterministic, outside the model)
Subagents  →  isolated context so the main thread stays clean
```

Prompts are probabilistic. Hooks are deterministic. Use both.
