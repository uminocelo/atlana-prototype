# Atlana dotfiles

Editor and tool configs Atlana can ship next to skills/hooks/rules.

> `neovim/` is an **example** config (lazy.nvim, LSP, Telescope, Treesitter).
> Replace it with your own, or delete `dotfile/neovim/` and the
> `command/install-neovim` and `command/sync-neovim` shortcuts.
> Personal overrides go in `neovim/lua/user/` (loaded last).

## Neovim

Source of truth: `dotfile/neovim/`

Install (symlink — one source of truth):

```bash
# from Atlana repo root
./bin/atlana install-neovim      # or: ./dotfile/sync-neovim.sh install
# or
ln -sfn "$(pwd)/dotfile/neovim" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
nvim  # :Lazy sync
```

Pull live config back into Atlana:

```bash
rsync -a --delete ~/.config/nvim/ ./dotfile/neovim/
```

Do not commit `~/.local/share/nvim` (plugin clones, Mason binaries). Commit `init.lua`, `lua/`, and `lazy-lock.json`.
