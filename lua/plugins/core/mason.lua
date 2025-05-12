return {
  {
    "mason-org/mason.nvim",
    lazy = false,
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      { "ms-jpq/coq_nvim", branch = "coq" },
      { "ms-jpq/coq.artifacts", branch = "artifacts" },
      { 'ms-jpq/coq.thirdparty', branch = "3p" },
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "b0o/SchemaStore.nvim",
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
    },
    config = function()
      require("config.core.mason").setup_mason()
      require("config.core.lspconfig")
    end,
  },
}
