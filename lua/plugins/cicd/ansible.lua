-- qompassai/Diver/lua/plugins/cicd/ansible.lua
-- Qompass AI Diver Ansible Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local ansible_cfg = require("config.cicd.ansible")

return {
  "pearofducks/ansible-vim",
  ft = { "yaml.ansible", "ansible" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/conform.nvim",
    "nvimtools/none-ls.nvim",
    "folke/trouble.nvim",
    "redhat-developer/yaml-language-server",
    "b0o/schemastore.nvim",
  },
  config = function(_, opts)
    local cfg = ansible_cfg.ansible_cfg(opts)
    require("conform").setup(cfg.conform)
    local null_ls = require("null-ls")
    for _, src in ipairs(cfg.nls) do null_ls.register(src) end
    local lsp = require("lspconfig")
    for name, opts in pairs(cfg.lsp) do
      lsp[name].setup(opts)
    end
  end,
}
