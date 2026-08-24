# Atlana Hooks

Deterministic guardrails. Hooks run **outside** the model — they cannot be talked out of.

## Crush

Add to project `.crush.json` or `crush.json`:

```json
{
  "$schema": "https://charm.land/crush.json",
  "hooks": {
    "PreToolUse": [
      {
        "name": "your-script",
        "matcher": "^bash$",
        "command": "./hooks/your-script.sh",
        "timeout": 10
      }
    ]
  }
}
```

Or via `crushrc`:

```bash
hook add PreToolUse --name your-script --matcher '^bash$' \
  --command './hooks/your-script.sh' --timeout 10
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
            "command": "\"$CLAUDE_PROJECT_DIR\"/hooks/your-script.sh"
          }
        ]
      }
    ]
  }
}
```

## OpenCode

Map to `tool.execute.before` in a plugin or config hook that runs the same shell scripts and rejects when exit code is `2`. See [PORTING.md](../PORTING.md).
