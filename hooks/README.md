# Atlana Hooks

Deterministic guardrails. Hooks run **outside** the model — they cannot be talked out of.

`block-destructive.sh` is the example hook. Add your own next to it: read the
command or path from the env vars (`CRUSH_TOOL_INPUT_COMMAND`,
`CLAUDE_TOOL_INPUT_COMMAND`, `CRUSH_TOOL_INPUT_FILE_PATH`) or the JSON on
stdin, exit `0` to allow, and exit `2` with a reason on stderr to deny. Wire it
up here and in `templates/crush.json`.

## Crush

Add to project `.crush.json` or `crush.json`:

```json
{
  "$schema": "https://charm.land/crush.json",
  "hooks": {
    "PreToolUse": [
      {
        "name": "block-destructive",
        "matcher": "^bash$",
        "command": "./hooks/block-destructive.sh",
        "timeout": 10
      }
    ]
  }
}
```

Or via `crushrc`:

```bash
hook add PreToolUse --name block-destructive --matcher '^bash$' \
  --command './hooks/block-destructive.sh' --timeout 10
```

Make scripts executable: `chmod +x hooks/*.sh`

Crush currently supports **PreToolUse** only. Scripts are Claude Code–compatible (exit `2` = deny).

## Claude Code

In `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/hooks/block-destructive.sh"
          }
        ]
      }
    ]
  }
}
```

## OpenCode

Map to `tool.execute.before` in a plugin or config hook that runs the same shell scripts and rejects when exit code is `2`. See [PORTING.md](../PORTING.md).
