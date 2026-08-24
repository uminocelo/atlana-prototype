# AGENTS.md — Project Rules (portable)

> Loaded automatically by Crush, OpenCode, Claude Code (via CLAUDE.md symlink), Cursor, and other agents that respect `AGENTS.md`.
> Keep this file factual and short. Put long procedures in **skills**. Put hard enforcement in **hooks**.

## Stack & commands

<!-- Replace with your real project values -->
- Package manager: (pnpm | npm | yarn | bun | cargo | go | …)
- Install: `…`
- Dev server: `…`
- Test: `…`
- Lint / format: `…`
- Build: `…`

## Conventions

- Prefer small, focused commits. Do not commit unless the user asks.
- Do not invent APIs or files that do not exist; read the codebase first.
- Match existing style (naming, imports, error handling) before introducing new patterns.
- Prefer editing existing files over creating new ones when a natural home exists.

## Planning workflow (Atlana skills)

When the user wants to plan or structure work:

1. Use **idea-planner** — produce milestones → issues → tasks in chat only.
2. When they ask to persist the plan, use **write-development-plan** — write `.plan/`.
3. When they ask to implement a milestone, use **start-milestone** — read `.plan/`, confirm, branch, then implement.

Do not invent a plan if `.plan/` already exists and the user is asking to start a milestone.
Do not write `.plan/` files from idea-planner.
Do not start coding a milestone without explicit confirmation (start-milestone Phase B).

## Safety

- Never run destructive git commands (`reset --hard`, `push --force`, `clean -fdx`) unless the user explicitly asks.
- Never commit secrets, `.env` files, or credentials.
- Prefer `rm` of specific paths over recursive deletes of broad trees.

## Tests & quality

- After non-trivial code changes, run the project test command when it is cheap and relevant.
- Do not “improve” scope beyond what the user or the `.plan/` issue asked for.

## Delegation

- Use a read-only / research subagent (or Crush’s task agent) for broad codebase exploration so the main session stays focused.
- Keep implementation in the main coding agent unless the user asks for parallel work.

## Security

When asked for a security review or DB data protection, use **secure-webapp-audit**.
It runs the secure-* skills in order and returns one prioritized report.
