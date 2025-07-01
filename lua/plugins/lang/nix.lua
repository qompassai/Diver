-- /qompassai/Diver/lua/plugins/lang/nix.lua
-- Qompass AI Diver Nix Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local nix_cfg = require("config.lang.nix")

return {
  {
    "stevearc/conform.nvim",
    ft = { "nix" },
    opts = function()
      return nix_cfg.nix_conform()
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    ft = { "nix" },
    opts = function(_, opts)
      opts = opts or {}
      return vim.tbl_deep_extend("force", opts, {
        sources = nix_cfg.nix_nls(opts),
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ft = { "nix" },
    config = function()
      local lsp_opts = nix_cfg.nix_lsp({})
      require("lspconfig").nil_ls.setup(lsp_opts)
    end,
  },
}
