# Contributing to Atlana

Thanks for wanting to improve Atlana. It is intentionally small — one Bash CLI plus plain-text components — keep it that way.

## Principles

- **Portable formats only.** Agent Skills folders (`SKILL.md` + YAML frontmatter), plain markdown, plain shell scripts. No proprietary extensions, no language-specific tooling.
- **One responsibility per component.** A skill does one procedure, a hook enforces one rule, a subagent owns one role. Do not blur boundaries.
- **Bash 3.2 compatibility.** The CLI must run on macOS stock Bash. No associative arrays, no Bash 4+ features.
- **Safe by default.** Confirmations before destructive actions, `--dry-run` support for every mutation, explicit sync direction.
- **Deterministic where it matters.** Hard limits belong in hooks (exit `2` = deny); soft guidance belongs in rules and skills.
- **No unsolicited commits.** Agents using Atlana's rules never commit unless the user asks.

## How to propose changes

1. Fork the repository: https://github.com/uminocelo/atlana
2. Create a branch from `main`.
3. Make the change (CLI, skill, hook, rule, subagent, template, or docs).
4. Test against at least one real agent (Crush, Cursor, or Claude Code).
5. Open a pull request describing:
   - What problem the change solves
   - Which component(s) were touched
   - How you verified it (agent used, commands run)

## Component guidelines

### Skills (`skills/<name>/SKILL.md`)

- Start with valid YAML frontmatter containing only `name` and `description` (plus optional standard keys such as `license`).
- Keep the `description` under 1024 characters, single line, no `<` / `>` characters.
- Body: short imperative sentences; concrete, copy-pasteable examples.
- If a task belongs to another skill or agent, say so explicitly instead of half-doing it.

### Hooks (`hooks/*.sh`, also `.js` / `.py`)

- Exit `0` to allow, exit `2` to deny — this is the Crush and Claude Code `PreToolUse` contract.
- Read stdin (JSON tool payload); never prompt interactively.
- Make the script executable (`chmod +x`) and keep it dependency-light.
- Document wiring in `hooks/README.md`; update `templates/crush.json` if you add an example.

### Rules (`rules/*.md`)

- `rules/AGENTS.md` is the source of truth; keep `rules/CLAUDE.md` mirrored with it.
- Keep it factual and short: stack commands, conventions, safety. Long procedures belong in skills; enforcement belongs in hooks.

### Subagents (`subagents/*.md`)

- Frontmatter: `name`, `description`, and the tool allowlist (see `explorer.md`).
- State read-only vs. mutating expectations explicitly in the body.
- Remember these install only to Claude Code (`~/.claude/agents/`) today.

### CLI (`bin/atlana`)

- Test with macOS stock Bash: `/bin/bash bin/atlana …`
- Run ShellCheck if available: `shellcheck bin/atlana`
- Verify all actions still behave: `list`, `agents`, `install --dry-run`, `sync --dry-run`.
- Update `usage()` and this repo's docs when adding or changing flags.

## Testing locally

```bash
# Install into a throwaway project
mkdir -p /tmp/test-atlana && cd /tmp/test-atlana && git init
/path/to/atlana/bin/atlana install --project --all --force

# Preview sync behavior without touching anything
/path/to/atlana/bin/atlana sync --component skills --agent all --dry-run
```

Then open the project in your agent of choice and confirm the installed files are picked up (skills listed, rules loaded).

## Style

- Short, imperative sentences in markdown bodies.
- Concrete examples over abstract descriptions.
- No emojis in file contents.
- Match the existing tone of the README: direct, table-heavy, example-driven.

## License

By contributing you agree that your contributions are licensed under the MIT License (see [LICENSE](LICENSE)).
