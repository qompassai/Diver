-- /qompassai/Diver/lua/plugins/cicd/ansible.lua
-- -------------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return {
  {
    "pearofducks/ansible-vim",
    ft = { "yaml.ansible", "ansible" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "saghen/blink.cmp",
      "stevearc/conform.nvim",
      "nvimtools/none-ls.nvim",
      "folke/trouble.nvim",
      "redhat-developer/yaml-language-server",
      "b0o/schemastore.nvim",
    },
    lazy = true,
    config = function(opts)
      require("config.cicd.ansible").setup_ansible(opts)
    end,
  },
}
