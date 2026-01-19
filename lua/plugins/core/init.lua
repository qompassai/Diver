-- /qompassai/Diver/lua/plugins/core/init.lua
-- Qompass AI Diver Plugin Core Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.pack.add({ ---@type vim.pack.Spec[]
  {
    branch = 'main',
    name = 'cheatsheet.nvim',
    src = 'https://github.com/sudormrfbin/cheatsheet.nvim',
    keys = {
      {
        '<leader>?',
        '<cmd>Cheatsheet<CR>',
        desc = 'Open Cheatsheet'
      },
    },
    hook = function()
      require('cheatsheet').setup({
        bundled_cheatsheets = true,
        bundled_plugin_cheatsheets = true,
        include_only_installed_plugins = true,
      })
    end,
  },
  {
    branch = 'main',
    hook = function()
      require('config.core.plenary')
    end,
    src = 'https://github.com/nvim-lua/plenary.nvim',
  },
  {
    branch = 'main',
    src = 'https://github.com/ms-jpq/coq_nvim',
    version = 'dev',
    dependencies = {
      {
        branch = 'artifacts',
        src = 'https://github.com/ms-jpq/coq.artifacts',
      },
      {
        branch = '3p',
        name = 'coq.thirdparty',
        src = 'https://github.com/ms-jpq/coq.thirdparty',
      },
    },
    init = function()
      vim.g.coq_settings = {
        auto_start = true
      }
    end,
    config = function() end,
  },
  {
    src = 'https://github.com/folke/trouble.nvim',
    cmd = {
      'TroubleToggle',
      'Trouble'
    },
    opts = require('config.core.trouble')(),
    hook = function(spec)
      require('trouble').setup(spec.opts)
    end,
  },
  {
    name = 'neotest',
    src = 'https://github.com/nvim-neotest/neotest',
    opts = {
      adapters = {
        'neotest-plenary'
      },
    },
    hook = function()
      require('neotest').setup({
        adapters = {
          require('neotest-plenary'),
        },
      })
    end,
  },
  {
    branch = 'main',
    name = 'neo-tree.nvim',
    src = 'https://github.com/nvim-neo-tree/neo-tree.nvim',
       version = vim.version.range('3.*'),
  },
  {
    build = ':TSUpdate',
    name = 'nvim-treesitter',
    src = 'https://github.com/nvim-treesitter/nvim-treesitter',
    version = 'master',
    hook = function()
      require('config.core.tree').tree_cfg({})
    end,
  },
  {
    src = 'https://github.com/folke/which-key.nvim',
    hook = function()
      local WK = require('config.core.whichkey')
      WK.setup()
    end,
  },
})
return {
}