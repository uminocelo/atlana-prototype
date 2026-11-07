return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua", "vim", "vimdoc", "query",
          "javascript", "typescript", "tsx", "json",
          "html", "css", "markdown", "markdown_inline",
          "bash", "python", "go", "rust", "elixir", "heex",
          "ruby", "cpp", "c",
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
}
