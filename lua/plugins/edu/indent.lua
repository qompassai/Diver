-- /qompassai/Diver/lua/plugins/edu/indent.lua
-- Qompass AI Diver Indent Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---
return {
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = {
        char = '│',
      },
      scope = {
        enabled = true,
        show_start = true,
        show_end = true,
      },
    },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
      'folke/which-key.nvim',
    },
    config = function(_, opts)
      require('ibl').setup(opts)
      local highlight_names = {
        'RainbowRed',
        'RainbowYellow',
        'RainbowBlue',
        'RainbowOrange',
        'RainbowGreen',
        'RainbowViolet',
        'RainbowCyan',
      }
      local hooks = require('ibl.hooks')
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, 'IndentBlanklineChar', {
          fg = '#4DA6FF',
          nocombine = true,
        })
        vim.api.nvim_set_hl(0, 'RainbowRed',
          {
            fg = '#E06C75',
          })
        vim.api.nvim_set_hl(0, 'RainbowYellow',
          {
            fg = '#E5C07B',
          })
        vim.api.nvim_set_hl(0, 'RainbowBlue',
          {
            fg = '#61AFEF',
          })
        vim.api.nvim_set_hl(0, 'RainbowOrange', {
          fg = '#D19A66',
        })
        vim.api.nvim_set_hl(0, 'RainbowGreen', {
          fg = '#98C379',
        })
        vim.api.nvim_set_hl(0, 'RainbowViolet', { fg = '#C678DD' })
        vim.api.nvim_set_hl(0, 'RainbowCyan', { fg = '#56B6C2' })
      end)
      require('ibl').setup({
        scope = {
          highlight = highlight_names,
        },
      })
      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
    end,
  },
  {
    'nmac427/guess-indent.nvim',
    event = 'BufReadPre',
    config = function()
      require('guess-indent').setup({
        auto_cmd = true,
        override_editorconfig = false,
        filetype_exclude = {
          'netrw',
          'tutor',
          'help',
          'dashboard',
          'neo-tree',
          'terminal',
          --'TelescopePrompt',
          'nofile',
          'lspinfo',
        },
      })
    end,
  },
}