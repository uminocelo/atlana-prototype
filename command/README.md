# Atlana commands

Shortcuts invoked as `atlana <command> [args…]`.

Each file in this directory (executable, no extension) is a command.
`bin/atlana` execs it with the remaining arguments.

| Command | Script | What it does |
|---------|--------|----------------|
| `add-agent` / `add-agents` | `utils/add-agent.sh` | Register a coding agent in `bin/atlana` |
| `sync-neovim` | `dotfile/sync-neovim.sh` | Copy live nvim → repo, then symlink |
| `install-cli` | `utils/install-cli.sh` | Put `atlana` on PATH |
| `install-neovim` | `dotfile/sync-neovim.sh install` | Only symlink nvim config |

```bash
atlana commands
atlana add-agent pi
atlana add-agents pi --dry-run
atlana sync-neovim
```
