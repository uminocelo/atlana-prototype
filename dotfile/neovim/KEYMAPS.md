# VS Code → Neovim

Leader = `Space`. Chords that terminals eat still have a leader fallback.

| VS Code | Neovim | Notes |
|---------|--------|--------|
| Ctrl+P | `<C-p>` / `<leader>ff` | Quick Open (Telescope) |
| Ctrl+Shift+P | `<C-S-p>` | Command Palette |
| Ctrl+Shift+F | `<C-S-f>` / `<leader>fg` | Search in project (`rg`) |
| Ctrl+B | `<C-b>` / `<leader>e` | Toggle explorer |
| Ctrl+Shift+E | `<C-S-e>` | Focus explorer |
| Ctrl+` | `<C-\\>` | Panel terminal |
| Ctrl+S | `<C-s>` | Save (needs `stty -ixon` in some TTYs) |
| Ctrl+W | `<C-w>` | Close buffer (not OS window) |
| Ctrl+Tab / Ctrl+Shift+Tab | same / `<leader>bn` `bp` | Next / prev tab |
| Ctrl+/ | `<C-/>` or `gcc` | Comment |
| Alt+↑ / Alt+↓ | `<A-Up>` `<A-Down>` | Move line |
| F12 | `F12` or `gd` | Go to definition |
| Shift+F12 | `<S-F12>` or `gr` | References |
| F2 | `F2` or `<leader>rn` | Rename |
| Ctrl+. | `<leader>.` / `<leader>ca` | Quick Fix |
| Hover | `K` | LSP hover |
| Ctrl+Shift+M | `<leader>xx` | Problems (Trouble) |
| Ctrl+A | `<C-a>` | Select all (n mode) |
| File → Open Folder | `nvim .` in the project | cwd + tree |
| Multi-cursor | visual + `s` (flash) | not 1:1 with Ctrl+D |

Vim you should keep: `hjkl`, `yy`/`p`, `/`, `ciw`, `.` — they have no good VS Code clone.
