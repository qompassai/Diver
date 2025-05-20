return {
  {
    "saghen/blink.cmp",
    lazy = true,
    build = "cargo build --release",
    event = "InsertEnter",
    dependencies = {
       "nvimtools/none-ls.nvim",
      "zeioth/none-ls-autoload.nvim",
      "gwinn/none-ls-jsonlint.nvim",
      {
        "L3MON4D3/LuaSnip",
        dependencies = { "rafamadriz/friendly-snippets" },
      },
      {
        "saghen/blink.compat",
        version = "*",
        opts = {},
      },
    },
    version = "1.*",
    opts = {
      keymap = { preset = "default" },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        documentation = { auto_show = true },
      },
      snippets = {
        expand = function(snippet, _)
          require("luasnip").lsp_expand(snippet)
        end,
      },
      sources = {
        default = { "lsp", "snippets", "buffer", "path" },
        providers = {
          lsp = { score_offset = 1000 },
          snippets = { score_offset = 750 },
          buffer = { score_offset = 500 },
          path = { score_offset = 250 },
        },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },
}
