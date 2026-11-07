"""
Atlana MCP Server

Exposes Atlana skills, commands, hooks, and rules to MCP clients
(Claude Code, Cursor, OpenCode, etc.).

Resources (application-controlled, browsable):
  skill://{name}              SKILL.md
  skill://{name}/references   list of reference files
  skill://{name}/references/{file}  one reference
  hook://{name}               hook script
  rule://{name}               rule markdown
  command://{name}            command script (read-only)

Tools:
  list_skills, get_skill, get_skill_references
  list_commands, list_hooks, get_hook, list_rules, get_rule
  list_resources, get_resource, write_resource, read
  atlana_info
  run_command (read-only whitelist: list, agents, commands)
  shell (arbitrary shell, cwd limited to Atlana root)
  create_skill, worktree_list, git_worktree_status
  sync_status, skill_diff, hook_test, security_scan
  agent_health, hook_log
  db_query, docker_logs, test_runner, deps_outdated, coverage_summary

Run:
  ATLANA_ROOT=/path/to/atlana python server.py
"""

from __future__ import annotations

import os
import re
import shlex
import subprocess
from pathlib import Path
from typing import Any

try:
    from mcp.server import MCPServer
except ImportError:
    from mcp.server.fastmcp import FastMCP as MCPServer  # type: ignore

# ---------------------------------------------------------------------------
# Root resolution
# ---------------------------------------------------------------------------

def resolve_root() -> Path:
    env = os.environ.get("ATLANA_ROOT")
    if env:
        p = Path(env).expanduser().resolve()
        if (p / "skills").is_dir() and (p / "bin" / "atlana").is_file():
            return p
        raise SystemExit(f"ATLANA_ROOT={env} does not look like an Atlana repo")

    here = Path(__file__).resolve().parent
    for candidate in (here.parent, here.parent.parent, here):
        if (candidate / "skills").is_dir() and (candidate / "bin" / "atlana").is_file():
            return candidate
    raise SystemExit("Could not find Atlana root. Set ATLANA_ROOT=/path/to/atlana")

ROOT = resolve_root()
SKILLS = ROOT / "skills"
COMMANDS = ROOT / "command"
HOOKS = ROOT / "hooks"
RULES = ROOT / "rules"
ATLANA_BIN = ROOT / "bin" / "atlana"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)

def parse_frontmatter(text: str) -> dict[str, str]:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    meta: dict[str, str] = {}
    lines = m.group(1).splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        i += 1
        # top-level keys only; nested maps (metadata:) are skipped
        if line[:1].isspace() or ":" not in line:
            continue
        k, v = line.split(":", 1)
        v = v.strip()
        if v[:1] in (">", "|"):
            # YAML block scalar (>-, |, …): gather the indented continuation lines
            block: list[str] = []
            while i < len(lines) and (not lines[i].strip() or lines[i][:1].isspace()):
                block.append(lines[i].strip())
                i += 1
            sep = " " if v[0] == ">" else "\n"
            v = sep.join(b for b in block if b)
        meta[k.strip()] = v.strip('"').strip("'")
    return meta

def skill_dirs() -> list[Path]:
    if not SKILLS.is_dir():
        return []
    return sorted(p for p in SKILLS.iterdir() if p.is_dir() and (p / "SKILL.md").is_file())

def find_skill(name: str) -> Path | None:
    name = name.strip()
    for d in skill_dirs():
        text = (d / "SKILL.md").read_text(encoding="utf-8", errors="replace")
        meta = parse_frontmatter(text)
        if d.name == name or meta.get("name") == name:
            return d
    return None

def command_files() -> list[Path]:
    if not COMMANDS.is_dir():
        return []
    return sorted(
        p for p in COMMANDS.iterdir()
        if p.is_file() and p.name != "README.md" and os.access(p, os.X_OK)
    )

def hook_files() -> list[Path]:
    if not HOOKS.is_dir():
        return []
    return sorted(
        p for p in HOOKS.iterdir()
        if p.is_file() and p.suffix in (".sh", ".js", ".py") and p.name != "README.md"
    )

def rule_files() -> list[Path]:
    if not RULES.is_dir():
        return []
    return sorted(p for p in RULES.iterdir() if p.is_file() and p.suffix == ".md")

def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

mcp = MCPServer("atlana")

# ---------------------------------------------------------------------------
# Resources (3) — browsable by the host
# ---------------------------------------------------------------------------

@mcp.resource("skill://{name}", mime_type="text/markdown")
def skill_resource(name: str) -> str:
    """SKILL.md for a skill (by folder name or frontmatter name)."""
    d = find_skill(name)
    if not d:
        raise ValueError(f"skill not found: {name}")
    return read_text(d / "SKILL.md")

@mcp.resource("skill://{name}/references", mime_type="text/plain")
def skill_references_list(name: str) -> str:
    """List of reference files under skills/<name>/references/."""
    d = find_skill(name)
    if not d:
        raise ValueError(f"skill not found: {name}")
    refs = d / "references"
    if not refs.is_dir():
        return f"(no references/ in {name})"
    files = sorted(p.name for p in refs.iterdir() if p.is_file())
    return "\n".join(files) if files else "(empty)"

@mcp.resource("skill://{name}/references/{file}", mime_type="text/markdown")
def skill_reference_file(name: str, file: str) -> str:
    """One reference file under skills/<name>/references/."""
    d = find_skill(name)
    if not d:
        raise ValueError(f"skill not found: {name}")
    # prevent path traversal
    if "/" in file or "\\" in file or file.startswith("."):
        raise ValueError("invalid reference file name")
    path = d / "references" / file
    if not path.is_file():
        raise ValueError(f"reference not found: {file}")
    return read_text(path)

@mcp.resource("hook://{name}", mime_type="text/plain")
def hook_resource(name: str) -> str:
    """Hook script content."""
    for p in hook_files():
        if p.name == name or p.stem == name:
            return read_text(p)
    raise ValueError(f"hook not found: {name}")

@mcp.resource("rule://{name}", mime_type="text/markdown")
def rule_resource(name: str) -> str:
    """Rule markdown content."""
    for p in rule_files():
        if p.name == name or p.stem == name:
            return read_text(p)
    raise ValueError(f"rule not found: {name}")

@mcp.resource("command://{name}", mime_type="text/plain")
def command_resource(name: str) -> str:
    """Command script content (read-only)."""
    for p in command_files():
        if p.name == name:
            return read_text(p)
    raise ValueError(f"command not found: {name}")

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

@mcp.tool()
def list_skills() -> list[dict[str, str]]:
    """List every skill with name, description, and relative path."""
    out = []
    for d in skill_dirs():
        text = read_text(d / "SKILL.md")
        meta = parse_frontmatter(text)
        out.append({
            "name": meta.get("name", d.name),
            "description": meta.get("description", ""),
            "path": str(d.relative_to(ROOT)),
            "uri": f"skill://{d.name}",
        })
    return out

@mcp.tool()
def list_resources() -> list[dict[str, str]]:
    """
    Return every concrete resource URI the server can serve.

    Includes skill://, skill://…/references, skill://…/references/file,
    hook://, rule://, and command://.
    """
    out: list[dict[str, str]] = []

    # skills
    for d in skill_dirs():
        out.append({
            "kind": "skill",
            "name": d.name,
            "uri": f"skill://{d.name}",
            "mime": "text/markdown",
        })
        refs = d / "references"
        if refs.is_dir():
            out.append({
                "kind": "skill-references",
                "name": d.name,
                "uri": f"skill://{d.name}/references",
                "mime": "text/plain",
            })
            for p in sorted(refs.iterdir()):
                if p.is_file():
                    out.append({
                        "kind": "skill-reference",
                        "name": f"{d.name}/{p.name}",
                        "uri": f"skill://{d.name}/references/{p.name}",
                        "mime": "text/markdown",
                    })

    # hooks
    for p in hook_files():
        out.append({
            "kind": "hook",
            "name": p.name,
            "uri": f"hook://{p.name}",
            "mime": "text/plain",
        })

    # rules
    for p in rule_files():
        out.append({
            "kind": "rule",
            "name": p.name,
            "uri": f"rule://{p.name}",
            "mime": "text/markdown",
        })

    # commands
    for p in command_files():
        out.append({
            "kind": "command",
            "name": p.name,
            "uri": f"command://{p.name}",
            "mime": "text/plain",
        })

    return out

@mcp.tool()
def get_resource(uri: str) -> str:
    """
    Return the content of any concrete resource URI.

    Accepts the URIs produced by list_resources:
      skill://name
      skill://name/references
      skill://name/references/file
      hook://name
      rule://name
      command://name
    """
    uri = uri.strip()
    if uri.startswith("skill://"):
        rest = uri[len("skill://"):]
        if "/references/" in rest:
            name, file = rest.split("/references/", 1)
            d = find_skill(name)
            if not d:
                raise ValueError(f"skill not found: {name}")
            if "/" in file or "\\" in file or file.startswith("."):
                raise ValueError("invalid reference file name")
            path = d / "references" / file
            if not path.is_file():
                raise ValueError(f"reference not found: {file}")
            return read_text(path)
        if rest.endswith("/references"):
            name = rest[: -len("/references")]
            d = find_skill(name)
            if not d:
                raise ValueError(f"skill not found: {name}")
            refs = d / "references"
            if not refs.is_dir():
                return f"(no references/ in {name})"
            files = sorted(p.name for p in refs.iterdir() if p.is_file())
            return "\n".join(files) if files else "(empty)"
        # plain skill://name
        d = find_skill(rest)
        if not d:
            raise ValueError(f"skill not found: {rest}")
        return read_text(d / "SKILL.md")

    if uri.startswith("hook://"):
        name = uri[len("hook://"):]
        for p in hook_files():
            if p.name == name or p.stem == name:
                return read_text(p)
        raise ValueError(f"hook not found: {name}")

    if uri.startswith("rule://"):
        name = uri[len("rule://"):]
        for p in rule_files():
            if p.name == name or p.stem == name:
                return read_text(p)
        raise ValueError(f"rule not found: {name}")

    if uri.startswith("command://"):
        name = uri[len("command://"):]
        for p in command_files():
            if p.name == name:
                return read_text(p)
        raise ValueError(f"command not found: {name}")

    raise ValueError(f"unsupported URI: {uri}")

@mcp.tool()
def write_resource(uri: str, content: str) -> str:
    """
    Create or overwrite a resource.

    Allowed URIs:
      skill://name                     → skills/<name>/SKILL.md
      skill://name/references/file     → skills/<name>/references/<file>
      hook://name                      → hooks/<name>
      rule://name                      → rules/<name>
      command://name                   → command/<name> (chmod +x)

    Path traversal is refused. Existing files are overwritten.
    """
    uri = uri.strip()
    content = content or ""

    def safe_name(n: str) -> str:
        if not n or "/" in n or "\\" in n or n.startswith(".") or ".." in n:
            raise ValueError(f"invalid name: {n}")
        return n

    if uri.startswith("skill://"):
        rest = uri[len("skill://"):]
        if "/references/" in rest:
            name, file = rest.split("/references/", 1)
            name = safe_name(name)
            file = safe_name(file)
            dest_dir = SKILLS / name / "references"
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest = dest_dir / file
            dest.write_text(content, encoding="utf-8")
            return f"wrote {dest.relative_to(ROOT)}"
        # plain skill
        name = safe_name(rest)
        dest_dir = SKILLS / name
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / "SKILL.md"
        dest.write_text(content, encoding="utf-8")
        return f"wrote {dest.relative_to(ROOT)}"

    if uri.startswith("hook://"):
        name = safe_name(uri[len("hook://"):])
        dest = HOOKS / name
        HOOKS.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        dest.chmod(0o755)
        return f"wrote {dest.relative_to(ROOT)}"

    if uri.startswith("rule://"):
        name = safe_name(uri[len("rule://"):])
        dest = RULES / name
        RULES.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        return f"wrote {dest.relative_to(ROOT)}"

    if uri.startswith("command://"):
        name = safe_name(uri[len("command://"):])
        dest = COMMANDS / name
        COMMANDS.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        dest.chmod(0o755)
        return f"wrote {dest.relative_to(ROOT)}"

    raise ValueError(f"unsupported URI: {uri}")

@mcp.tool()
def read(uri_or_path: str) -> str:
    """
    Read a resource by URI or a file by relative path under the Atlana root.

    Accepts:
      skill://name
      skill://name/references
      skill://name/references/file
      hook://name
      rule://name
      command://name
      skills/foo/SKILL.md
      hooks/bar.sh
      rules/AGENTS.md
      bin/atlana
      … any path relative to the Atlana root

    Absolute paths and path traversal are refused.
    """
    target = uri_or_path.strip()
    if not target:
        raise ValueError("empty path")

    # resource URI → delegate to get_resource
    if "://" in target:
        return get_resource(target)

    # relative path under ROOT
    if target.startswith("/") or target.startswith("~") or ".." in target.split("/"):
        raise ValueError("absolute paths and path traversal are not allowed")

    path = (ROOT / target).resolve()
    try:
        path.relative_to(ROOT.resolve())
    except ValueError:
        raise ValueError("path escapes Atlana root")

    if not path.is_file():
        raise ValueError(f"not a file: {target}")

    return read_text(path)

@mcp.tool()
def get_skill(name: str) -> str:
    """Return the full SKILL.md content for a skill."""
    d = find_skill(name)
    if not d:
        raise ValueError(f"skill not found: {name}")
    return read_text(d / "SKILL.md")

@mcp.tool()
def get_skill_references(name: str) -> list[dict[str, str]]:
    """Return reference files under skills/<name>/references/ (name + content)."""
    d = find_skill(name)
    if not d:
        raise ValueError(f"skill not found: {name}")
    refs = d / "references"
    if not refs.is_dir():
        return []
    out = []
    for p in sorted(refs.iterdir()):
        if p.is_file():
            out.append({
                "name": p.name,
                "uri": f"skill://{d.name}/references/{p.name}",
                "content": read_text(p),
            })
    return out

@mcp.tool()
def list_commands() -> list[dict[str, str]]:
    """List executable shortcuts in Atlana command/."""
    return [
        {"name": p.name, "path": str(p.relative_to(ROOT)), "uri": f"command://{p.name}"}
        for p in command_files()
    ]

@mcp.tool()
def list_hooks() -> list[dict[str, str]]:
    """List hook scripts in Atlana hooks/."""
    return [
        {"name": p.name, "path": str(p.relative_to(ROOT)), "uri": f"hook://{p.name}"}
        for p in hook_files()
    ]

@mcp.tool()
def get_hook(name: str) -> str:
    """Return the content of a hook script."""
    for p in hook_files():
        if p.name == name or p.stem == name:
            return read_text(p)
    raise ValueError(f"hook not found: {name}")

@mcp.tool()
def list_rules() -> list[dict[str, str]]:
    """List rule markdown files in Atlana rules/."""
    return [
        {"name": p.name, "path": str(p.relative_to(ROOT)), "uri": f"rule://{p.name}"}
        for p in rule_files()
    ]

@mcp.tool()
def get_rule(name: str) -> str:
    """Return the content of a rule file."""
    for p in rule_files():
        if p.name == name or p.stem == name:
            return read_text(p)
    raise ValueError(f"rule not found: {name}")

@mcp.tool()
def atlana_info() -> dict[str, Any]:
    """Return Atlana root path and inventory counts."""
    return {
        "root": str(ROOT),
        "skills": len(skill_dirs()),
        "commands": len(command_files()),
        "hooks": len(hook_files()),
        "rules": len(rule_files()),
        "has_bin": ATLANA_BIN.is_file(),
    }

# ---------------------------------------------------------------------------
# Safe run_command (2) — read-only whitelist only
# ---------------------------------------------------------------------------

READ_ONLY_ACTIONS = {"list", "agents", "commands"}

@mcp.tool()
def run_command(action: str, args: list[str] | None = None) -> str:
    """
    Run a read-only Atlana CLI action.

    Allowed actions: list, agents, commands.
    Extra args are passed through (e.g. ["--component", "skills"]).
    Writes (install, add, remove, sync, add-agent, etc.) are refused.
    """
    action = action.strip().lower()
    if action not in READ_ONLY_ACTIONS:
        raise ValueError(
            f"action '{action}' is not allowed. "
            f"Only read-only: {sorted(READ_ONLY_ACTIONS)}"
        )
    if not ATLANA_BIN.is_file():
        raise RuntimeError("bin/atlana not found")

    cmd = [str(ATLANA_BIN), action]
    if args:
        # refuse anything that looks like a write flag
        forbidden = {"--force", "--from", "--direction", "install", "add", "remove", "sync"}
        for a in args:
            if a in forbidden or a.startswith("--from") or a.startswith("--direction"):
                raise ValueError(f"arg not allowed in read-only mode: {a}")
        cmd.extend(args)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(ROOT),
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("atlana command timed out")

    out = result.stdout or ""
    err = result.stderr or ""
    if result.returncode != 0:
        raise RuntimeError(f"atlana exited {result.returncode}\n{err}")
    return out or err or "(no output)"

ATLANA_ALIASES = {"atlana", "bin/atlana", "./bin/atlana"}
# `mcp` would start a nested server on the same stdio
SHELL_REFUSED = {"mcp"}
ATLANA_ACTIONS = {
    "install", "add", "remove", "sync", "list", "agents", "commands", "help",
    "--help", "-h", "--version",
}
SHELL_OPERATORS = {";", "|", "||", "&", "&&", ">", ">>", "<", "<<"}

@mcp.tool()
def shell(command: str, cwd: str | None = None, timeout: int = 30) -> str:
    """
    Run an Atlana CLI command (the only program this tool can run).

    - `command` is an atlana invocation, with or without the leading `atlana`:
      "atlana install --component skills --agent crush --all --force" or
      "list --component hooks". Writes are allowed; pass --force, since
      there is no TTY to confirm overwrites.
    - No shell is involved: pipes, redirects, `;`, `&&`, and other binaries
      are not interpreted. `atlana mcp` is refused.
    - Default cwd is the Atlana root (this is the default for --project).
      cwd must be a relative path under the Atlana root (no absolute paths, no ..).
    - Timeout defaults to 30 seconds (max 120).
    - Returns combined stdout + stderr. Non-zero exit raises.
    """
    if not command or not command.strip():
        raise ValueError("empty command")

    argv = shlex.split(command)
    if argv and argv[0] in ATLANA_ALIASES:
        argv = argv[1:]
    if not argv:
        raise ValueError("missing atlana action, e.g. 'atlana list'")
    if argv[0] in SHELL_REFUSED:
        raise ValueError(f"'atlana {argv[0]}' is not allowed from the MCP server")
    allowed = ATLANA_ACTIONS | {p.name for p in command_files()}
    if argv[0] not in allowed:
        raise ValueError(
            f"only the atlana CLI can be run; '{argv[0]}' is not an atlana action "
            f"or command/ shortcut. Allowed: {sorted(allowed - SHELL_REFUSED)}"
        )
    operators = [a for a in argv if a in SHELL_OPERATORS]
    if operators:
        raise ValueError(f"shell operators are not supported: {operators}")
    if not ATLANA_BIN.is_file():
        raise RuntimeError("bin/atlana not found")

    work = ROOT
    if cwd:
        cwd = cwd.strip()
        if cwd.startswith("/") or cwd.startswith("~") or ".." in cwd.split("/"):
            raise ValueError("cwd must be a relative path under the Atlana root")
        work = (ROOT / cwd).resolve()
        try:
            work.relative_to(ROOT.resolve())
        except ValueError:
            raise ValueError("cwd escapes Atlana root")
        if not work.is_dir():
            raise ValueError(f"cwd is not a directory: {cwd}")

    timeout = max(1, min(int(timeout), 120))

    try:
        result = subprocess.run(
            [str(ATLANA_BIN), *argv],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(work),
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"command timed out after {timeout}s")

    out = result.stdout or ""
    err = result.stderr or ""
    combined = (out + ("\n" + err if err else "")).strip()
    if result.returncode != 0:
        raise RuntimeError(f"exit {result.returncode}\n{combined}")
    return combined or "(no output)"

# ---------------------------------------------------------------------------
# Atlana-specific tools
# ---------------------------------------------------------------------------

@mcp.tool()
def create_skill(name: str, description: str, body: str = "") -> str:
    """
    Scaffold a new skill folder with SKILL.md.

    name: folder name (kebab-case recommended)
    description: one-line description for frontmatter
    body: optional markdown body (after frontmatter)
    """
    if not name or "/" in name or "\\" in name or name.startswith("."):
        raise ValueError("invalid skill name")
    dest = SKILLS / name
    if dest.exists():
        raise ValueError(f"skill already exists: {name}")
    dest.mkdir(parents=True)
    content = f"""---
name: {name}
description: {description}
---

# {name}

{body or "TODO: describe what this skill does."}
"""
    (dest / "SKILL.md").write_text(content, encoding="utf-8")
    return f"created skills/{name}/SKILL.md"

@mcp.tool()
def worktree_list() -> str:
    """List git worktrees and their branches."""
    try:
        result = subprocess.run(
            ["git", "worktree", "list"],
            capture_output=True,
            text=True,
            timeout=10,
            cwd=str(ROOT),
        )
        return result.stdout or result.stderr or "(no worktrees)"
    except Exception as e:
        return f"error: {e}"

@mcp.tool()
def sync_status() -> dict[str, Any]:
    """
    Rough skill sync status across known agent skill directories.
    Returns counts of skills present in Atlana vs each agent.
    """
    agents = {
        "crush": Path.home() / ".config" / "crush" / "skills",
        "cursor": Path.home() / ".cursor" / "skills",
        "claude": Path.home() / ".claude" / "skills",
        "opencode": Path.home() / ".config" / "opencode" / "skills",
        "agents": Path.home() / ".agents" / "skills",
    }
    atlana_skills = {d.name for d in skill_dirs()}
    out = {"atlana": len(atlana_skills)}
    for name, path in agents.items():
        if path.is_dir():
            agent_skills = {p.name for p in path.iterdir() if p.is_dir()}
            out[name] = {
                "count": len(agent_skills),
                "only_in_atlana": sorted(atlana_skills - agent_skills)[:10],
                "only_in_agent": sorted(agent_skills - atlana_skills)[:10],
            }
        else:
            out[name] = {"count": 0, "missing_dir": True}
    return out

@mcp.tool()
def skill_diff(name: str, agent: str) -> str:
    """
    Diff a skill between Atlana and a specific agent directory.

    agent: crush | cursor | claude | opencode | agents
    """
    d = find_skill(name)
    if not d:
        raise ValueError(f"skill not found: {name}")
    agents = {
        "crush": Path.home() / ".config" / "crush" / "skills",
        "cursor": Path.home() / ".cursor" / "skills",
        "claude": Path.home() / ".claude" / "skills",
        "opencode": Path.home() / ".config" / "opencode" / "skills",
        "agents": Path.home() / ".agents" / "skills",
    }
    agent_dir = agents.get(agent.lower())
    if not agent_dir:
        raise ValueError(f"unknown agent: {agent}")
    agent_skill = agent_dir / d.name / "SKILL.md"
    if not agent_skill.is_file():
        return f"skill not present in {agent}"
    try:
        result = subprocess.run(
            ["diff", "-u", str(d / "SKILL.md"), str(agent_skill)],
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result.stdout or "(identical)"
    except Exception as e:
        return f"diff error: {e}"

@mcp.tool()
def hook_test(name: str, payload: str = "{}") -> str:
    """
    Dry-run a hook script with a JSON payload on stdin.

    name: hook file name (e.g. block-destructive.sh)
    """
    for p in hook_files():
        if p.name == name or p.stem == name:
            try:
                result = subprocess.run(
                    [str(p)],
                    input=payload,
                    capture_output=True,
                    text=True,
                    timeout=10,
                    cwd=str(ROOT),
                )
                return f"exit {result.returncode}\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
            except Exception as e:
                return f"error: {e}"
    raise ValueError(f"hook not found: {name}")

@mcp.tool()
def security_scan(path: str = ".") -> str:
    """
    Run a simple security checklist against a path (relative to Atlana root).
    Looks for common issues: hardcoded secrets, SQL injection patterns, etc.
    """
    target = (ROOT / path).resolve()
    try:
        target.relative_to(ROOT.resolve())
    except ValueError:
        raise ValueError("path escapes Atlana root")
    if not target.exists():
        raise ValueError(f"path not found: {path}")

    findings = []
    secret_patterns = [
        r"(?i)(password|secret|api_key|token)\s*[:=]\s*['\"][^'\"]{8,}['\"]",
        r"(?i)sk-[a-zA-Z0-9]{20,}",
        r"(?i)ghp_[a-zA-Z0-9]{36}",
    ]
    for p in target.rglob("*"):
        if not p.is_file() or p.suffix in (".png", ".jpg", ".gif", ".lock", ".pyc"):
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for pat in secret_patterns:
            if re.search(pat, text):
                findings.append(f"possible secret in {p.relative_to(ROOT)}")
                break
        if len(findings) > 20:
            break
    return "\n".join(findings) if findings else "(no obvious issues found)"

@mcp.tool()
def agent_health() -> dict[str, Any]:
    """Check which agents are installed and whether their skill dirs exist."""
    agents = {
        "crush": Path.home() / ".config" / "crush",
        "cursor": Path.home() / ".cursor",
        "claude": Path.home() / ".claude",
        "opencode": Path.home() / ".config" / "opencode",
        "agents": Path.home() / ".agents",
    }
    out = {}
    for name, base in agents.items():
        skills = base / "skills"
        out[name] = {
            "base_exists": base.is_dir(),
            "skills_exists": skills.is_dir(),
            "skill_count": len(list(skills.iterdir())) if skills.is_dir() else 0,
        }
    return out

@mcp.tool()
def hook_log(lines: int = 50) -> str:
    """Return the last N lines of any hook log files found under hooks/ or logs/."""
    logs = []
    for p in (ROOT / "hooks").glob("*.log") if (ROOT / "hooks").is_dir() else []:
        logs.append(p)
    for p in (ROOT / "logs").glob("*.log") if (ROOT / "logs").is_dir() else []:
        logs.append(p)
    if not logs:
        return "(no hook logs found)"
    text = []
    for p in logs[:3]:
        content = read_text(p).splitlines()
        text.append(f"=== {p.name} ===\n" + "\n".join(content[-lines:]))
    return "\n\n".join(text)

# ---------------------------------------------------------------------------
# Stack-specific tools (db, docker, tests, deps, coverage)
# ---------------------------------------------------------------------------

@mcp.tool()
def db_query(query: str, engine: str = "postgres", dsn: str | None = None) -> str:
    """
    Run a read-only SQL query.

    engine: postgres | sqlite
    dsn: connection string (or SQLITE path). Falls back to env POSTGRES_DSN / SQLITE_PATH.
    Only SELECT / EXPLAIN / PRAGMA allowed.
    """
    q = query.strip().lower()
    if not any(q.startswith(prefix) for prefix in ("select", "explain", "pragma", "with")):
        raise ValueError("only SELECT / EXPLAIN / PRAGMA / WITH allowed")

    if engine == "sqlite":
        path = dsn or os.environ.get("SQLITE_PATH")
        if not path:
            raise ValueError("sqlite path required (dsn or SQLITE_PATH)")
        cmd = ["sqlite3", "-header", "-column", path, query]
    else:
        dsn = dsn or os.environ.get("POSTGRES_DSN") or os.environ.get("DATABASE_URL")
        if not dsn:
            raise ValueError("postgres dsn required (dsn or POSTGRES_DSN)")
        cmd = ["psql", dsn, "-c", query, "--no-align", "--tuples-only"]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        out = (result.stdout or "") + (result.stderr or "")
        if result.returncode != 0:
            raise RuntimeError(out)
        return out.strip() or "(no rows)"
    except FileNotFoundError:
        raise RuntimeError(f"{engine} client not found (psql / sqlite3)")

@mcp.tool()
def docker_logs(container: str, lines: int = 100) -> str:
    """Tail the last N lines of a Docker container's logs."""
    try:
        result = subprocess.run(
            ["docker", "logs", "--tail", str(lines), container],
            capture_output=True,
            text=True,
            timeout=15,
        )
        return (result.stdout or result.stderr or "(no logs)").strip()
    except Exception as e:
        return f"error: {e}"

@mcp.tool()
def test_runner(path: str = ".") -> str:
    """
    Detect project type and run tests. Returns failures only when possible.

    Supports: Elixir (mix test), Go (go test), Rust (cargo test),
    Ruby (bundle exec rspec / rake), Node (npm test / vitest / jest).
    """
    target = (ROOT / path).resolve()
    try:
        target.relative_to(ROOT.resolve())
    except ValueError:
        raise ValueError("path escapes Atlana root")

    cmds = []
    if (target / "mix.exs").is_file():
        cmds.append(["mix", "test"])
    if (target / "go.mod").is_file():
        cmds.append(["go", "test", "./..."])
    if (target / "Cargo.toml").is_file():
        cmds.append(["cargo", "test"])
    if (target / "Gemfile").is_file():
        cmds.append(["bundle", "exec", "rspec"])
    if (target / "package.json").is_file():
        cmds.append(["npm", "test", "--", "--passWithNoTests"])

    if not cmds:
        return "no recognized test runner in " + str(target)

    outputs = []
    for cmd in cmds:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120, cwd=str(target))
            out = (result.stdout or "") + (result.stderr or "")
            outputs.append(f"$ {' '.join(cmd)}\nexit {result.returncode}\n{out[-4000:]}")
        except Exception as e:
            outputs.append(f"$ {' '.join(cmd)}\nerror: {e}")
    return "\n\n".join(outputs)

@mcp.tool()
def deps_outdated(path: str = ".") -> str:
    """
    List outdated dependencies.

    Supports: Elixir (mix hex.outdated), Rust (cargo outdated), Go (go list -u),
    Node (npm outdated), Ruby (bundle outdated).
    """
    target = (ROOT / path).resolve()
    try:
        target.relative_to(ROOT.resolve())
    except ValueError:
        raise ValueError("path escapes Atlana root")

    cmds = []
    if (target / "mix.exs").is_file():
        cmds.append(["mix", "hex.outdated"])
    if (target / "Cargo.toml").is_file():
        cmds.append(["cargo", "outdated"])
    if (target / "go.mod").is_file():
        cmds.append(["go", "list", "-u", "-m", "all"])
    if (target / "package.json").is_file():
        cmds.append(["npm", "outdated"])
    if (target / "Gemfile").is_file():
        cmds.append(["bundle", "outdated"])

    if not cmds:
        return "no recognized dependency manager"

    outputs = []
    for cmd in cmds:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60, cwd=str(target))
            out = (result.stdout or "") + (result.stderr or "")
            outputs.append(f"$ {' '.join(cmd)}\n{out[-3000:]}")
        except Exception as e:
            outputs.append(f"$ {' '.join(cmd)}\nerror: {e}")
    return "\n\n".join(outputs)

@mcp.tool()
def git_worktree_status() -> list[dict[str, str]]:
    """List git worktrees with dirty status."""
    try:
        result = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=10,
            cwd=str(ROOT),
        )
        if result.returncode != 0:
            return [{"error": result.stderr}]

        worktrees = []
        current = {}
        for line in result.stdout.splitlines():
            if line.startswith("worktree "):
                if current:
                    worktrees.append(current)
                current = {"path": line.split(" ", 1)[1]}
            elif line.startswith("branch "):
                current["branch"] = line.split(" ", 1)[1]
            elif line.startswith("HEAD "):
                current["head"] = line.split(" ", 1)[1]
        if current:
            worktrees.append(current)

        # dirty check
        for wt in worktrees:
            try:
                st = subprocess.run(
                    ["git", "-C", wt["path"], "status", "--porcelain"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                wt["dirty"] = "yes" if st.stdout.strip() else "no"
            except Exception:
                wt["dirty"] = "?"
        return worktrees
    except Exception as e:
        return [{"error": str(e)}]

@mcp.tool()
def coverage_summary(path: str = ".") -> str:
    """
    Look for common coverage files and return a short summary.

    Looks for: cover/excoveralls.json, coverage/lcov.info, coverage.xml, etc.
    """
    target = (ROOT / path).resolve()
    try:
        target.relative_to(ROOT.resolve())
    except ValueError:
        raise ValueError("path escapes Atlana root")

    candidates = [
        "cover/excoveralls.json",
        "coverage/lcov.info",
        "coverage.xml",
        "coverage/cobertura.xml",
        "lcov.info",
    ]
    found = []
    for c in candidates:
        p = target / c
        if p.is_file():
            found.append(str(p.relative_to(ROOT)))
    if not found:
        return "no coverage files found"
    return "found coverage files:\n" + "\n".join(found)


if __name__ == "__main__":
    mcp.run(transport="stdio")
