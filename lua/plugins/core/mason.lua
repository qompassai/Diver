return {
  {
    "mason-org/mason-lspconfig.nvim",
    lazy = false,
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "b0o/SchemaStore.nvim",
    },
    config = function()
      require("neoconf").setup()
      --      require("mason").setup()
      --      require("mason-lspconfig").setup()
      require("config.core.lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      require("lspconfig").util.default_config.capabilities =
        vim.tbl_deep_extend("force", require("lspconfig").util.default_config.capabilities, capabilities)
      require("config.core.mason").setup_mason()
    end,
  },
  {
    "nvimdev/lspsaga.nvim",
    config = true,
  },
}
