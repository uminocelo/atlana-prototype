# Contributing to Atlana Prototype

Atlana Prototype is the **empty framework** behind [Atlana](https://github.com/uminocelo/atlana):
the CLI, hook and MCP plumbing, and docs, with no personal skills. Changes here
should help everyone who forks it. Your own skills, rules, and dotfiles belong
in your fork.

## Principles

- **Framework, not content.** Do not add opinionated skills or personal configs
  here. Examples (like `dotfile/neovim` and the Elixir subagents) must be easy
  to delete and clearly marked as examples.
- **No unsolicited commits.** Agents never commit unless the user explicitly asks.
- **Portable.** Pure markdown + YAML frontmatter for skills; Bash 3.2+ for the
  CLI (macOS stock Bash, no associative arrays); Python standard library only
  in `utils/`.
- **Docs are the spec.** When CLI behavior changes, update `README.md`,
  `docs/SYNC.md`, and `PORTING.md` in the same change.

## How to propose changes

1. Fork the repository: https://github.com/uminocelo/atlana-prototype
2. Create a branch from `main`.
3. Make the change (CLI, hooks, MCP server, utils, or docs).
4. Verify it (below) with at least one real agent (Crush, Cursor, or Claude Code).
5. Open a pull request describing what problem it solves and how you verified it.

## Skill format checklist (for skills in your fork)

Every `SKILL.md` must:

- Live in its own top-level kebab-case folder: `skills/<name>/SKILL.md`
  (the CLI only discovers depth-1 folders).
- Start with valid YAML frontmatter containing `name` and `description`.
- Keep the `description` under 1024 characters, single-line (folded `>-`), with
  no colon-space (`: `) sequences and no `<` / `>` characters.
- Refuse work that belongs to a sibling skill and name that skill explicitly.

## Testing locally

There is no build step or test suite. Check syntax, then exercise the CLI in a
throwaway project:

```bash
bash -n bin/atlana && bash -n hooks/*.sh

mkdir /tmp/atlana-test && cd /tmp/atlana-test && git init
/path/to/atlana-prototype/bin/atlana install \
  --component hooks --component rules --component subagents --project --all --force
/path/to/atlana-prototype/bin/atlana install --component skills --agent crush --all --dry-run
```

For the MCP server: `./utils/install-mcp.sh`, then `./bin/atlana mcp --inspect`.

## Style

- Bash: `set -euo pipefail`, small `snake_case` functions, explicit `local`.
- Prefer short, imperative sentences in skills and docs.
- Keep examples concrete and copy-pasteable.

## License

By contributing you agree that your contributions are licensed under the MIT License (see `LICENSE`).
