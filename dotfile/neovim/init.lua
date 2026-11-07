local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("core.options")

require("lazy").setup({
  { import = "plugins" },
  { import = "plugins.lang" },
  { import = "user.plugins" },
}, {
  change_detection = { notify = false },
  checker = { enabled = false },
})

require("core.keymaps")

pcall(require, "user.options")
pcall(require, "user.colorscheme")
