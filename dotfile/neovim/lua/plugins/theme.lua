return {
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        theme = "wave",
        background = { dark = "dragon", light = "lotus" },
      })
      vim.cmd.colorscheme("kanagawa")
    end,
  },
}
