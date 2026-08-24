# Bidirectional sync

`atlana sync` keeps Atlana (the repo) and local agent installs aligned.

## Directions

| Flag | Meaning |
|------|---------|
| `--direction push` | Atlana → agent only (never overwrite Atlana) |
| `--direction pull` | agent → Atlana only (never overwrite agent) |
| `--direction both` | **default** — push missing, pull missing, resolve conflicts |

## Item states

For each `(component, name, agent)` pair the CLI hashes content (file or whole skill directory):

| State | Action in `both` |
|-------|------------------|
| **identical** | no-op |
| **only_atlana** | push → agent |
| **only_agent** | pull → Atlana |
| **differ** | conflict → see `--prefer` |
| **unsupported** | agent has no slot for that component (e.g. Crush subagents) |

Hashes are **content-based** (`sha256`), not mtime, so clock skew does not create false conflicts.

## Conflict policy (`--prefer`)

| Value | Behavior when both sides differ |
|-------|----------------------------------|
| `ask` | **default** — interactive 1/2/3 (Atlana / agent / skip). With `--force`, falls back to **atlana**. |
| `atlana` | Atlana overwrites agent (push) |
| `agent` | agent overwrites Atlana (pull) |

## Examples

```bash
# Full bidirectional sync of skills to every known agent
./bin/atlana sync --component skills --agent all

# Only push (safe deploy from git)
./bin/atlana sync --component skills --component hooks --agent cursor --direction push --force

# Only pull (capture local experiments back into the repo)
./bin/atlana sync --component skills --agent crush --direction pull --prefer agent --force

# Conflicts: always prefer Atlana
./bin/atlana sync --component skills --agent all --direction both --prefer atlana --force

# One skill, one agent
./bin/atlana sync idea-planner --component skills --agent crush --direction both
```

## Safety notes

- **pull** writes into the Atlana git working tree. Review with `git status` / `git diff` before committing.
- **push** overwrites agent-local copies. Use `--dry-run` first if unsure.
- Project-local sync: add `--project [dir]` instead of `--agent`.
- Hooks and rules that are single files compare as files; skills compare as directory trees.

## Relation to other actions

| Action | Role |
|--------|------|
| `install` | Explicit one-way deploy (always push selected items) |
| `add` | Import a *new* path into Atlana, optional install |
| `remove` | Delete from agent and/or Atlana |
| `sync` | Reconcile existing trees with status + optional pull |
