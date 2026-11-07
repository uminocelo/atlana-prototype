/**
 * Atlana MCP Server (TypeScript)
 *
 * Same surface as the Python server:
 *   Resources: skill://, hook://, rule://, command://
 *   Tools: list_skills, get_skill, get_skill_references, list_*, get_*,
 *          atlana_info, run_command (read-only)
 *
 * Run:
 *   ATLANA_ROOT=/path/to/atlana npx tsx src/index.ts
 */

import { McpServer } from "@modelcontextprotocol/server";
import { serveStdio } from "@modelcontextprotocol/server/stdio";
import { z } from "zod";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

// ---------------------------------------------------------------------------
// Root resolution
// ---------------------------------------------------------------------------

function resolveRoot(): string {
  const env = process.env.ATLANA_ROOT;
  if (env) {
    const p = path.resolve(env);
    if (fs.existsSync(path.join(p, "skills")) && fs.existsSync(path.join(p, "bin", "atlana"))) {
      return p;
    }
    throw new Error(`ATLANA_ROOT=${env} does not look like an Atlana repo`);
  }
  // walk up from this file
  let here = path.dirname(new URL(import.meta.url).pathname);
  for (let i = 0; i < 4; i++) {
    if (
      fs.existsSync(path.join(here, "skills")) &&
      fs.existsSync(path.join(here, "bin", "atlana"))
    ) {
      return here;
    }
    here = path.dirname(here);
  }
  throw new Error("Could not find Atlana root. Set ATLANA_ROOT");
}

const ROOT = resolveRoot();
const SKILLS = path.join(ROOT, "skills");
const COMMANDS = path.join(ROOT, "command");
const HOOKS = path.join(ROOT, "hooks");
const RULES = path.join(ROOT, "rules");
const ATLANA_BIN = path.join(ROOT, "bin", "atlana");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function parseFrontmatter(text: string): Record<string, string> {
  const m = text.match(/^---\s*\n([\s\S]*?)\n---\s*\n/);
  if (!m) return {};
  const meta: Record<string, string> = {};
  for (const line of m[1].split("\n")) {
    const idx = line.indexOf(":");
    if (idx > 0) {
      const k = line.slice(0, idx).trim();
      const v = line.slice(idx + 1).trim().replace(/^["']|["']$/g, "");
      meta[k] = v;
    }
  }
  return meta;
}

function skillDirs(): string[] {
  if (!fs.existsSync(SKILLS)) return [];
  return fs
    .readdirSync(SKILLS, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(SKILLS, d.name, "SKILL.md")))
    .map((d) => path.join(SKILLS, d.name))
    .sort();
}

function findSkill(name: string): string | null {
  name = name.trim();
  for (const d of skillDirs()) {
    const text = fs.readFileSync(path.join(d, "SKILL.md"), "utf8");
    const meta = parseFrontmatter(text);
    if (path.basename(d) === name || meta.name === name) return d;
  }
  return null;
}

function commandFiles(): string[] {
  if (!fs.existsSync(COMMANDS)) return [];
  return fs
    .readdirSync(COMMANDS)
    .filter((f) => f !== "README.md" && fs.statSync(path.join(COMMANDS, f)).isFile())
    .map((f) => path.join(COMMANDS, f))
    .sort();
}

function hookFiles(): string[] {
  if (!fs.existsSync(HOOKS)) return [];
  return fs
    .readdirSync(HOOKS)
    .filter((f) => /\.(sh|js|py)$/.test(f) && f !== "README.md")
    .map((f) => path.join(HOOKS, f))
    .sort();
}

function ruleFiles(): string[] {
  if (!fs.existsSync(RULES)) return [];
  return fs
    .readdirSync(RULES)
    .filter((f) => f.endsWith(".md"))
    .map((f) => path.join(RULES, f))
    .sort();
}

function readText(p: string): string {
  return fs.readFileSync(p, "utf8");
}

function textResult(text: string) {
  return { content: [{ type: "text" as const, text }] };
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

function createServer(): McpServer {
  const server = new McpServer({ name: "atlana", version: "0.1.0" });

  // Resources
  server.registerResource(
    "skill",
    "skill://{name}",
    { title: "Skill", description: "SKILL.md for a skill", mimeType: "text/markdown" },
    async (uri, { name }) => ({
      contents: [{ uri: uri.href, mimeType: "text/markdown", text: (() => {
        const d = findSkill(name);
        if (!d) throw new Error(`skill not found: ${name}`);
        return readText(path.join(d, "SKILL.md"));
      })() }],
    })
  );

  server.registerResource(
    "skill-references",
    "skill://{name}/references",
    { title: "Skill references list", mimeType: "text/plain" },
    async (uri, { name }) => {
      const d = findSkill(name);
      if (!d) throw new Error(`skill not found: ${name}`);
      const refs = path.join(d, "references");
      if (!fs.existsSync(refs)) return { contents: [{ uri: uri.href, text: `(no references/ in ${name})` }] };
      const files = fs.readdirSync(refs).filter((f) => fs.statSync(path.join(refs, f)).isFile()).sort();
      return { contents: [{ uri: uri.href, text: files.join("\n") || "(empty)" }] };
    }
  );

  server.registerResource(
    "skill-reference-file",
    "skill://{name}/references/{file}",
    { title: "Skill reference file", mimeType: "text/markdown" },
    async (uri, { name, file }) => {
      if (file.includes("/") || file.includes("\\") || file.startsWith(".")) {
        throw new Error("invalid reference file name");
      }
      const d = findSkill(name);
      if (!d) throw new Error(`skill not found: ${name}`);
      const p = path.join(d, "references", file);
      if (!fs.existsSync(p)) throw new Error(`reference not found: ${file}`);
      return { contents: [{ uri: uri.href, mimeType: "text/markdown", text: readText(p) }] };
    }
  );

  server.registerResource(
    "hook",
    "hook://{name}",
    { title: "Hook", mimeType: "text/plain" },
    async (uri, { name }) => {
      for (const p of hookFiles()) {
        if (path.basename(p) === name || path.basename(p, path.extname(p)) === name) {
          return { contents: [{ uri: uri.href, text: readText(p) }] };
        }
      }
      throw new Error(`hook not found: ${name}`);
    }
  );

  server.registerResource(
    "rule",
    "rule://{name}",
    { title: "Rule", mimeType: "text/markdown" },
    async (uri, { name }) => {
      for (const p of ruleFiles()) {
        if (path.basename(p) === name || path.basename(p, ".md") === name) {
          return { contents: [{ uri: uri.href, mimeType: "text/markdown", text: readText(p) }] };
        }
      }
      throw new Error(`rule not found: ${name}`);
    }
  );

  server.registerResource(
    "command",
    "command://{name}",
    { title: "Command", mimeType: "text/plain" },
    async (uri, { name }) => {
      for (const p of commandFiles()) {
        if (path.basename(p) === name) {
          return { contents: [{ uri: uri.href, text: readText(p) }] };
        }
      }
      throw new Error(`command not found: ${name}`);
    }
  );

  server.registerTool(
    "list_resources",
    { description: "Return every concrete resource URI (skills, hooks, rules, commands, references)" },
    async () => {
      const out: { kind: string; name: string; uri: string; mime: string }[] = [];

      for (const d of skillDirs()) {
        const base = path.basename(d);
        out.push({ kind: "skill", name: base, uri: `skill://${base}`, mime: "text/markdown" });
        const refs = path.join(d, "references");
        if (fs.existsSync(refs) && fs.statSync(refs).isDirectory()) {
          out.push({ kind: "skill-references", name: base, uri: `skill://${base}/references`, mime: "text/plain" });
          for (const f of fs.readdirSync(refs).sort()) {
            const fp = path.join(refs, f);
            if (fs.statSync(fp).isFile()) {
              out.push({
                kind: "skill-reference",
                name: `${base}/${f}`,
                uri: `skill://${base}/references/${f}`,
                mime: "text/markdown",
              });
            }
          }
        }
      }

      for (const p of hookFiles()) {
        out.push({ kind: "hook", name: path.basename(p), uri: `hook://${path.basename(p)}`, mime: "text/plain" });
      }
      for (const p of ruleFiles()) {
        out.push({ kind: "rule", name: path.basename(p), uri: `rule://${path.basename(p)}`, mime: "text/markdown" });
      }
      for (const p of commandFiles()) {
        out.push({ kind: "command", name: path.basename(p), uri: `command://${path.basename(p)}`, mime: "text/plain" });
      }

      return textResult(JSON.stringify(out, null, 2));
    }
  );

  server.registerTool(
    "get_resource",
    {
      description: "Return the content of any concrete resource URI from list_resources",
      inputSchema: { uri: z.string().describe("URI such as skill://my-skill or hook://block-destructive.sh") },
    },
    async ({ uri }) => {
      uri = uri.trim();

      if (uri.startsWith("skill://")) {
        const rest = uri.slice("skill://".length);
        if (rest.includes("/references/")) {
          const [name, file] = rest.split("/references/", 2);
          if (file.includes("/") || file.includes("\\") || file.startsWith(".")) {
            throw new Error("invalid reference file name");
          }
          const d = findSkill(name);
          if (!d) throw new Error(`skill not found: ${name}`);
          const p = path.join(d, "references", file);
          if (!fs.existsSync(p)) throw new Error(`reference not found: ${file}`);
          return textResult(readText(p));
        }
        if (rest.endsWith("/references")) {
          const name = rest.slice(0, -"/references".length);
          const d = findSkill(name);
          if (!d) throw new Error(`skill not found: ${name}`);
          const refs = path.join(d, "references");
          if (!fs.existsSync(refs)) return textResult(`(no references/ in ${name})`);
          const files = fs.readdirSync(refs).filter((f) => fs.statSync(path.join(refs, f)).isFile()).sort();
          return textResult(files.join("\n") || "(empty)");
        }
        const d = findSkill(rest);
        if (!d) throw new Error(`skill not found: ${rest}`);
        return textResult(readText(path.join(d, "SKILL.md")));
      }

      if (uri.startsWith("hook://")) {
        const name = uri.slice("hook://".length);
        for (const p of hookFiles()) {
          if (path.basename(p) === name || path.basename(p, path.extname(p)) === name) {
            return textResult(readText(p));
          }
        }
        throw new Error(`hook not found: ${name}`);
      }

      if (uri.startsWith("rule://")) {
        const name = uri.slice("rule://".length);
        for (const p of ruleFiles()) {
          if (path.basename(p) === name || path.basename(p, ".md") === name) {
            return textResult(readText(p));
          }
        }
        throw new Error(`rule not found: ${name}`);
      }

      if (uri.startsWith("command://")) {
        const name = uri.slice("command://".length);
        for (const p of commandFiles()) {
          if (path.basename(p) === name) {
            return textResult(readText(p));
          }
        }
        throw new Error(`command not found: ${name}`);
      }

      throw new Error(`unsupported URI: ${uri}`);
    }
  );

  server.registerTool(
    "write_resource",
    {
      description: "Create or overwrite a skill, hook, rule, or command. Path traversal is refused.",
      inputSchema: {
        uri: z.string().describe("skill://name | skill://name/references/file | hook://name | rule://name | command://name"),
        content: z.string().describe("Full file content"),
      },
    },
    async ({ uri, content }) => {
      uri = uri.trim();
      content = content ?? "";

      const safeName = (n: string): string => {
        if (!n || n.includes("/") || n.includes("\\") || n.startsWith(".") || n.includes("..")) {
          throw new Error(`invalid name: ${n}`);
        }
        return n;
      };

      if (uri.startsWith("skill://")) {
        const rest = uri.slice("skill://".length);
        if (rest.includes("/references/")) {
          const [name, file] = rest.split("/references/", 2);
          const d = path.join(SKILLS, safeName(name), "references");
          fs.mkdirSync(d, { recursive: true });
          const dest = path.join(d, safeName(file));
          fs.writeFileSync(dest, content, "utf8");
          return textResult(`wrote ${path.relative(ROOT, dest)}`);
        }
        const name = safeName(rest);
        const d = path.join(SKILLS, name);
        fs.mkdirSync(d, { recursive: true });
        const dest = path.join(d, "SKILL.md");
        fs.writeFileSync(dest, content, "utf8");
        return textResult(`wrote ${path.relative(ROOT, dest)}`);
      }

      if (uri.startsWith("hook://")) {
        const name = safeName(uri.slice("hook://".length));
        fs.mkdirSync(HOOKS, { recursive: true });
        const dest = path.join(HOOKS, name);
        fs.writeFileSync(dest, content, "utf8");
        fs.chmodSync(dest, 0o755);
        return textResult(`wrote ${path.relative(ROOT, dest)}`);
      }

      if (uri.startsWith("rule://")) {
        const name = safeName(uri.slice("rule://".length));
        fs.mkdirSync(RULES, { recursive: true });
        const dest = path.join(RULES, name);
        fs.writeFileSync(dest, content, "utf8");
        return textResult(`wrote ${path.relative(ROOT, dest)}`);
      }

      if (uri.startsWith("command://")) {
        const name = safeName(uri.slice("command://".length));
        fs.mkdirSync(COMMANDS, { recursive: true });
        const dest = path.join(COMMANDS, name);
        fs.writeFileSync(dest, content, "utf8");
        fs.chmodSync(dest, 0o755);
        return textResult(`wrote ${path.relative(ROOT, dest)}`);
      }

      throw new Error(`unsupported URI: ${uri}`);
    }
  );

  server.registerTool(
    "read",
    {
      description: "Read a resource by URI or a file by relative path under the Atlana root. Absolute paths and path traversal are refused.",
      inputSchema: {
        uri_or_path: z.string().describe("skill://… or a relative path such as skills/my-skill/SKILL.md"),
      },
    },
    async ({ uri_or_path }) => {
      const target = uri_or_path.trim();
      if (!target) throw new Error("empty path");

      if (target.includes("://")) {
        // reuse get_resource logic by calling the same resolution
        // (simple reimplementation for clarity)
        if (target.startsWith("skill://")) {
          const rest = target.slice("skill://".length);
          if (rest.includes("/references/")) {
            const [name, file] = rest.split("/references/", 2);
            if (file.includes("/") || file.includes("\\") || file.startsWith(".")) {
              throw new Error("invalid reference file name");
            }
            const d = findSkill(name);
            if (!d) throw new Error(`skill not found: ${name}`);
            const p = path.join(d, "references", file);
            if (!fs.existsSync(p)) throw new Error(`reference not found: ${file}`);
            return textResult(readText(p));
          }
          if (rest.endsWith("/references")) {
            const name = rest.slice(0, -"/references".length);
            const d = findSkill(name);
            if (!d) throw new Error(`skill not found: ${name}`);
            const refs = path.join(d, "references");
            if (!fs.existsSync(refs)) return textResult(`(no references/ in ${name})`);
            const files = fs.readdirSync(refs).filter((f) => fs.statSync(path.join(refs, f)).isFile()).sort();
            return textResult(files.join("\n") || "(empty)");
          }
          const d = findSkill(rest);
          if (!d) throw new Error(`skill not found: ${rest}`);
          return textResult(readText(path.join(d, "SKILL.md")));
        }
        if (target.startsWith("hook://")) {
          const name = target.slice("hook://".length);
          for (const p of hookFiles()) {
            if (path.basename(p) === name || path.basename(p, path.extname(p)) === name) {
              return textResult(readText(p));
            }
          }
          throw new Error(`hook not found: ${name}`);
        }
        if (target.startsWith("rule://")) {
          const name = target.slice("rule://".length);
          for (const p of ruleFiles()) {
            if (path.basename(p) === name || path.basename(p, ".md") === name) {
              return textResult(readText(p));
            }
          }
          throw new Error(`rule not found: ${name}`);
        }
        if (target.startsWith("command://")) {
          const name = target.slice("command://".length);
          for (const p of commandFiles()) {
            if (path.basename(p) === name) return textResult(readText(p));
          }
          throw new Error(`command not found: ${name}`);
        }
        throw new Error(`unsupported URI: ${target}`);
      }

      // relative path
      if (target.startsWith("/") || target.startsWith("~") || target.split("/").includes("..")) {
        throw new Error("absolute paths and path traversal are not allowed");
      }
      const abs = path.resolve(ROOT, target);
      if (!abs.startsWith(path.resolve(ROOT))) {
        throw new Error("path escapes Atlana root");
      }
      if (!fs.existsSync(abs) || !fs.statSync(abs).isFile()) {
        throw new Error(`not a file: ${target}`);
      }
      return textResult(readText(abs));
    }
  );

  server.registerTool(
    "list_skills",
    { description: "List every skill with name, description, path, and skill:// URI" },
    async () => {
      const out = skillDirs().map((d) => {
        const text = readText(path.join(d, "SKILL.md"));
        const meta = parseFrontmatter(text);
        const name = meta.name || path.basename(d);
        return { name, description: meta.description || "", path: path.relative(ROOT, d), uri: `skill://${path.basename(d)}` };
      });
      return textResult(JSON.stringify(out, null, 2));
    }
  );

  server.registerTool(
    "get_skill",
    {
      description: "Return the full SKILL.md content for a skill",
      inputSchema: { name: z.string().describe("Skill folder name or frontmatter name") },
    },
    async ({ name }) => {
      const d = findSkill(name);
      if (!d) throw new Error(`skill not found: ${name}`);
      return textResult(readText(path.join(d, "SKILL.md")));
    }
  );

  server.registerTool(
    "get_skill_references",
    {
      description: "Return reference files under skills/<name>/references/",
      inputSchema: { name: z.string() },
    },
    async ({ name }) => {
      const d = findSkill(name);
      if (!d) throw new Error(`skill not found: ${name}`);
      const refs = path.join(d, "references");
      if (!fs.existsSync(refs)) return textResult("[]");
      const out = fs.readdirSync(refs)
        .filter((f) => fs.statSync(path.join(refs, f)).isFile())
        .sort()
        .map((f) => ({
          name: f,
          uri: `skill://${path.basename(d)}/references/${f}`,
          content: readText(path.join(refs, f)),
        }));
      return textResult(JSON.stringify(out, null, 2));
    }
  );

  server.registerTool(
    "list_commands",
    { description: "List executable shortcuts in Atlana command/" },
    async () => textResult(JSON.stringify(commandFiles().map((p) => ({ name: path.basename(p), uri: `command://${path.basename(p)}` })), null, 2))
  );

  server.registerTool(
    "list_hooks",
    { description: "List hook scripts in Atlana hooks/" },
    async () => textResult(JSON.stringify(hookFiles().map((p) => ({ name: path.basename(p), uri: `hook://${path.basename(p)}` })), null, 2))
  );

  server.registerTool(
    "get_hook",
    { description: "Return the content of a hook script", inputSchema: { name: z.string() } },
    async ({ name }) => {
      for (const p of hookFiles()) {
        if (path.basename(p) === name || path.basename(p, path.extname(p)) === name) {
          return textResult(readText(p));
        }
      }
      throw new Error(`hook not found: ${name}`);
    }
  );

  server.registerTool(
    "list_rules",
    { description: "List rule markdown files in Atlana rules/" },
    async () => textResult(JSON.stringify(ruleFiles().map((p) => ({ name: path.basename(p), uri: `rule://${path.basename(p)}` })), null, 2))
  );

  server.registerTool(
    "get_rule",
    { description: "Return the content of a rule file", inputSchema: { name: z.string() } },
    async ({ name }) => {
      for (const p of ruleFiles()) {
        if (path.basename(p) === name || path.basename(p, ".md") === name) {
          return textResult(readText(p));
        }
      }
      throw new Error(`rule not found: ${name}`);
    }
  );

  server.registerTool(
    "atlana_info",
    { description: "Return Atlana root path and inventory counts" },
    async () => textResult(JSON.stringify({
      root: ROOT,
      skills: skillDirs().length,
      commands: commandFiles().length,
      hooks: hookFiles().length,
      rules: ruleFiles().length,
      has_bin: fs.existsSync(ATLANA_BIN),
    }, null, 2))
  );

  const READ_ONLY = new Set(["list", "agents", "commands"]);

  server.registerTool(
    "run_command",
    {
      description: "Run a read-only Atlana CLI action (list, agents, commands only)",
      inputSchema: {
        action: z.enum(["list", "agents", "commands"]),
        args: z.array(z.string()).optional(),
      },
    },
    async ({ action, args }) => {
      if (!READ_ONLY.has(action)) throw new Error(`action '${action}' not allowed`);
      if (!fs.existsSync(ATLANA_BIN)) throw new Error("bin/atlana not found");
      const forbidden = new Set(["--force", "--from", "--direction", "install", "add", "remove", "sync"]);
      for (const a of args ?? []) {
        if (forbidden.has(a) || a.startsWith("--from") || a.startsWith("--direction")) {
          throw new Error(`arg not allowed in read-only mode: ${a}`);
        }
      }
      const result = spawnSync(ATLANA_BIN, [action, ...(args ?? [])], {
        cwd: ROOT,
        encoding: "utf8",
        timeout: 30000,
      });
      if (result.error) throw result.error;
      if (result.status !== 0) {
        throw new Error(`atlana exited ${result.status}\n${result.stderr || ""}`);
      }
      return textResult(result.stdout || result.stderr || "(no output)");
    }
  );

  server.registerTool(
    "shell",
    {
      description: "Run a shell command. Default cwd is the Atlana root. cwd must be a relative path under Atlana. Timeout defaults to 30s (max 120).",
      inputSchema: {
        command: z.string().describe("Shell command to run"),
        cwd: z.string().optional().describe("Relative working directory under Atlana root"),
        timeout: z.number().int().min(1).max(120).optional().describe("Timeout in seconds (default 30)"),
      },
    },
    async ({ command, cwd, timeout }) => {
      if (!command || !command.trim()) throw new Error("empty command");

      let work = ROOT;
      if (cwd) {
        cwd = cwd.trim();
        if (cwd.startsWith("/") || cwd.startsWith("~") || cwd.split("/").includes("..")) {
          throw new Error("cwd must be a relative path under the Atlana root");
        }
        work = path.resolve(ROOT, cwd);
        if (!work.startsWith(path.resolve(ROOT))) {
          throw new Error("cwd escapes Atlana root");
        }
        if (!fs.existsSync(work) || !fs.statSync(work).isDirectory()) {
          throw new Error(`cwd is not a directory: ${cwd}`);
        }
      }

      const secs = Math.max(1, Math.min(timeout ?? 30, 120));
      const result = spawnSync(command, {
        shell: true,
        cwd: work,
        encoding: "utf8",
        timeout: secs * 1000,
      });

      if (result.error) {
        if ((result.error as any).code === "ETIMEDOUT") {
          throw new Error(`command timed out after ${secs}s`);
        }
        throw result.error;
      }

      const out = result.stdout || "";
      const err = result.stderr || "";
      const combined = (out + (err ? "\n" + err : "")).trim();
      if (result.status !== 0) {
        throw new Error(`exit ${result.status}\n${combined}`);
      }
      return textResult(combined || "(no output)");
    }
  );

  return server;
}

void serveStdio(createServer);
console.error("atlana MCP server running on stdio");
