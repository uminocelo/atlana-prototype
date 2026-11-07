return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    opts = {
      format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        go = { "gofmt" },
        elixir = { "mix" },
        ruby = { "rubocop" },
        rust = { "rustfmt" },
        cpp = { "clang_format" },
        c = { "clang_format" },
      },
    },
  },
}
