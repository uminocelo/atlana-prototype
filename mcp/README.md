# Atlana MCP Server

Exposes your Atlana skills, commands, hooks, rules, and workflow tools to any MCP-aware agent
(Claude Code, Cursor, OpenCode, etc.).

## Tools

### Core inventory

| Tool | What it returns |
|------|-----------------|
| `list_skills` | Every skill: name, description, path, `skill://` URI |
| `list_resources` | Every concrete URI (skills, hooks, rules, commands, references) |
| `get_resource` | Content of any URI from `list_resources` |
| `write_resource` | Create or overwrite a skill / hook / rule / command |
| `read` | Read by URI or relative path under the Atlana root |
| `get_skill` | Full `SKILL.md` |
| `get_skill_references` | Files under `skills/<name>/references/` |
| `list_commands` | Executable shortcuts under `command/` |
| `list_hooks` | Hook scripts under `hooks/` |
| `get_hook` | Hook script content |
| `list_rules` | Rule markdown under `rules/` |
| `get_rule` | Rule content |
| `atlana_info` | Root + counts |

### Safe execution

| Tool | What it does |
|------|--------------|
| `run_command` | Read-only Atlana CLI (`list`, `agents`, `commands` only) |
| `shell` | Arbitrary shell command (cwd limited to Atlana root, timeout) |

### Atlana workflow tools

| Tool | What it does |
|------|--------------|
| `create_skill` | Scaffold a new skill folder + `SKILL.md` |
| `worktree_list` | List git worktrees |
| `sync_status` | Skill sync status across agents |
| `skill_diff` | Diff a skill between Atlana and an agent |
| `hook_test` | Dry-run a hook with a JSON payload |
| `security_scan` | Simple secret/pattern scan under a path |
| `agent_health` | Which agents are installed and skill counts |
| `hook_log` | Tail hook log files |
| `db_query` | Read-only SQL (Postgres / SQLite) |
| `docker_logs` | Tail Docker container logs |
| `test_runner` | Detect language and run tests |
| `deps_outdated` | List outdated dependencies |
| `git_worktree_status` | Worktrees with dirty status |
| `coverage_summary` | Find coverage files |

## Resources (browsable by the host)

| URI template | Content |
|--------------|---------|
| `skill://{name}` | `SKILL.md` |
| `skill://{name}/references` | list of reference files |
| `skill://{name}/references/{file}` | one reference file |
| `hook://{name}` | hook script |
| `rule://{name}` | rule markdown |
| `command://{name}` | command script (read-only) |

## Quick start

### Python

```bash
cd mcp
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# from the Atlana repo root
export ATLANA_ROOT=.
python mcp/server.py
```

Or use the Atlana command (if `command/mcp` is installed):

```bash
atlana mcp
atlana mcp --inspect
```

### TypeScript

```bash
cd mcp/typescript
npm install
export ATLANA_ROOT=../..
npx tsx src/index.ts
```

## Wire it into an agent

### Claude Code / Cursor

```json
{
  "mcpServers": {
    "atlana": {
      "command": "/absolute/path/to/atlana/mcp/.venv/bin/python",
      "args": ["/absolute/path/to/atlana/mcp/server.py"],
      "env": { "ATLANA_ROOT": "/absolute/path/to/atlana" }
    }
  }
}
```

See `mcp-config.example.json` for a full example that also includes GitHub, Filesystem, Postgres, SQLite, Docker, Figma, and Notion.

### Keep tokens out of config files

Export tokens in your shell profile (e.g. `~/.zshrc`) and reference them from
the config instead of pasting the value. The reference syntax differs per agent:

| Agent | Config file | Reference syntax |
|-------|-------------|------------------|
| Claude Code | `~/.claude.json` (user scope) or `.mcp.json` (project) | `${GITHUB_PERSONAL_ACCESS_TOKEN}` |
| Cursor | `~/.cursor/mcp.json` or `.cursor/mcp.json` | `${env:GITHUB_PERSONAL_ACCESS_TOKEN}` |
| Crush | `~/.config/crush/crush.json` (key `mcp`, each server needs `type`) | `$GITHUB_PERSONAL_ACCESS_TOKEN` |

For Claude Code, `claude mcp add --scope user <name> -e 'KEY=${VAR}' -- <command>`
writes the reference for you (put the name before `-e`, which takes multiple values).
Agents only see variables from the shell they were launched from, so a GUI app
opened from the Dock does not read `~/.zshrc`. Start it from a terminal (`cursor .`).

Database servers belong in a per-project config (`.mcp.json` or
`.cursor/mcp.json` in the app's folder) so each app only sees its own database.

### Other useful MCP servers

| Server | Package | Notes |
|--------|---------|-------|
| GitHub | Hosted: `https://api.githubcopilot.com/mcp/` (HTTP) | Official GitHub server. Header `Authorization: Bearer <GITHUB_PERSONAL_ACCESS_TOKEN>`. The npm package `@modelcontextprotocol/server-github` is archived. |
| Filesystem | `@modelcontextprotocol/server-filesystem` | Restrict to specific directories |
| Postgres | `@modelcontextprotocol/server-postgres` | Connection string. Archived upstream (no security fixes); prefer a maintained alternative and a read-only DB user. |
| SQLite | `@modelcontextprotocol/server-sqlite` | `--db-path`. Not published on npm; the reference server is Python (`uvx mcp-server-sqlite --db-path <file>`). |
| Docker | `@modelcontextprotocol/server-docker` | Not published on npm; choose a maintained Docker MCP server before using this entry. |
| Figma | `figma-developer-mcp --stdio` (Framelink) | Reads `FIGMA_API_KEY`; map it to your `FIGMA_ACCESS_TOKEN`. |
| Notion | `@notionhq/notion-mcp-server` | Needs `NOTION_TOKEN`; share pages with the integration. |

## Safe run_command

Only these Atlana actions are allowed:

- `list` (optionally `--component skills|hooks|rules|subagents`)
- `agents`
- `commands`

Anything that writes (`install`, `add`, `remove`, `sync`, `--from`, `--direction`, `--force`) is refused.

## Layout

```
mcp/
  server.py              # Python MCP server
  requirements.txt
  README.md
  mcp-config.example.json
  typescript/            # Node/TypeScript equivalent
    package.json
    tsconfig.json
    src/index.ts
```
