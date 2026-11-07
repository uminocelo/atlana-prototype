-- VS Code–flavored chords + Vim leader maps.
-- Terminals swallow some Ctrl-Shift combos; leader fallbacks are listed too.

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Save / close / quit (VS Code Ctrl+S / Ctrl+W)
map({ "n", "i", "v" }, "<C-s>", "<Esc><cmd>write<CR>", { desc = "Save" })
map("n", "<C-w>", "<cmd>bdelete<CR>", { desc = "Close editor" })

-- Quick Open / Search / Palette
map("n", "<C-p>", "<cmd>Telescope find_files<CR>", { desc = "Quick Open" })
map("n", "<C-S-f>", "<cmd>Telescope live_grep<CR>", { desc = "Search in project" })
map("n", "<C-S-p>", "<cmd>Telescope commands<CR>", { desc = "Command Palette" })
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Grep project" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Buffers" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Recent files" })

-- Explorer (Ctrl+B / Ctrl+Shift+E)
map("n", "<C-b>", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle explorer" })
map("n", "<C-S-e>", "<cmd>NvimTreeFocus<CR>", { desc = "Focus explorer" })
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Explorer" })

-- Terminal (Ctrl+`)
map({ "n", "t" }, "<C-`>", "<cmd>ToggleTerm<CR>", { desc = "Terminal" })
map({ "n", "t" }, "<C-\\>", "<cmd>ToggleTerm<CR>", { desc = "Terminal" })

-- Tabs / buffers
map("n", "<C-Tab>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next tab" })
map("n", "<C-S-Tab>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev tab" })
map("n", "<leader>bn", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev buffer" })

-- Split (Ctrl+\)
map("n", "<leader>sv", "<cmd>vsplit<CR>", { desc = "Split vertical" })
map("n", "<leader>sh", "<cmd>split<CR>", { desc = "Split horizontal" })

-- Move line (Alt+Up / Alt+Down)
map("n", "<A-Up>", ":m .-2<CR>==", opts)
map("n", "<A-Down>", ":m .+1<CR>==", opts)
map("v", "<A-Up>", ":m '<-2<CR>gv=gv", opts)
map("v", "<A-Down>", ":m '>+1<CR>gv=gv", opts)

-- Comment (Ctrl+/)
map("n", "<C-/>", "gcc", { remap = true, desc = "Toggle comment" })
map("v", "<C-/>", "gc", { remap = true, desc = "Toggle comment" })

-- Problems
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Problems" })

-- LSP (F12 / Shift+F12 / F2) — also set in lsp on_attach
map("n", "<F12>", vim.lsp.buf.definition, { desc = "Go to Definition" })
map("n", "<S-F12>", vim.lsp.buf.references, { desc = "Find References" })
map("n", "<F2>", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<leader>.", vim.lsp.buf.code_action, { desc = "Quick Fix" })

-- Select all
map("n", "<C-a>", "ggVG", { desc = "Select all" })
