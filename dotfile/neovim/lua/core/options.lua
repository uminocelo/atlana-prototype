local o = vim.opt

o.mouse = "a"
o.mousemodel = "popup_setpos"
o.clipboard = "unnamedplus"
o.number = true
o.relativenumber = true
o.cursorline = true
o.termguicolors = true
o.signcolumn = "yes"
o.splitright = true
o.splitbelow = true
o.wrap = false
o.scrolloff = 4
o.sidescrolloff = 8
o.ignorecase = true
o.smartcase = true
o.updatetime = 250
o.timeoutlen = 400
o.undofile = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.completeopt = { "menu", "menuone", "noselect" }
o.laststatus = 3

-- Ctrl-S / Ctrl-Q must not freeze the TTY
pcall(function()
  vim.fn.system({ "stty", "-ixon" })
end)
