return {
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>st", "<cmd>TodoTelescope<CR>", desc = "Todo comments" },
    },
  },
}
