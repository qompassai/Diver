return {
  "neovim/nvim-lspconfig",
  lazy = false,
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
  config = function()
    -- Explicit LSP configuration
    require("mason").setup()
    require("mason-lspconfig").setup()
    require("lspconfig").lua_ls.setup({
      -- Server-specific settings
    })
  end,
}
