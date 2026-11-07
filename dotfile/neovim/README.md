# Atlana Neovim (VS Code–like)

Goal: keep modal editing, but make the **mouse, sidebar, tabs, search, terminal, LSP, and shortcuts** feel close to VS Code.

## Install

```bash
# from Atlana repo
chmod +x ../install-neovim.sh
../install-neovim.sh
nvim   # then :Lazy sync
```

Host tools (search + formatters work better with these):

```bash
brew install ripgrep fd neovim
```

## What maps to VS Code

| VS Code | Here |
|---------|------|
| Explorer | nvim-tree (`<C-b>` / `<C-S-e>`) |
| Tabs | bufferline (click + `<C-Tab>`) |
| Quick Open | Telescope files (`<C-p>`) |
| Search in project | Telescope live_grep (`<C-S-f>`) |
| Command Palette | Telescope commands (`<C-S-p>`) |
| Terminal | toggleterm (`<C-`>`) |
| Problems | trouble (`<C-S-m>` loosely) |
| Git gutter | gitsigns |
| IntelliSense | nvim-cmp + LSP (Mason) |
| Format on save | conform.nvim |
| Settings JSON | `lua/core/options.lua` + `lua/user/` |

Leader is **Space** (Vim muscle memory). VS Code chords that work in the terminal are bound in `lua/core/keymaps.lua`.

## Layout

```
neovim/
├── init.lua
├── lazy-lock.json          # pin after :Lazy sync
└── lua/
    ├── core/               # options + VS Code keymaps
    ├── plugins/            # one spec file per concern
    │   └── lang/           # language extras
    └── user/               # your personal overrides (loaded last)
```
