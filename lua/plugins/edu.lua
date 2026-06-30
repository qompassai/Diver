#!/usr/bin/env lua

-- edu.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- /home/phaedrus/.config/nvim/lua/plugins/edu.lua
-- Qompass AI Diver Education Plugins
-- ----------------------------------

vim.pack.add({
  {
    src = 'https://github.com/lukas-reineke/indent-blankline.nvim',
    version = vim.version.range('3.*'),
  },
  {
    src = 'https://github.com/nmac427/guess-indent.nvim',
  },
  {
    src = 'https://github.com/davidgranstrom/scnvim',
  },
  {
    src = 'https://github.com/folke/twilight.nvim',
  },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter',
  },
  {
    src = 'https://github.com/nvim-tree/nvim-web-devicons',
  },
  {
    src = 'https://github.com/folke/which-key.nvim',
  },
}, {
  load = true,
  confirm = true,
})

do
  local ok_ibl, ibl = pcall(require, 'ibl')
  if ok_ibl then
    local ok_hooks, hooks = pcall(require, 'ibl.hooks')

    if ok_hooks then
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, 'IndentBlanklineChar', {
          fg = '#4DA6FF',
          nocombine = true,
        })
      end)
    end

    ibl.setup({
      indent = {
        char = '│',
        highlight = 'IndentBlanklineChar',
      },
      scope = {
        enabled = false,
      },
      exclude = {
        filetypes = {
          'help',
          'dashboard',
          'neo-tree',
          'Trouble',
          'alpha',
          'lazy',
          'mason',
          'notify',
          'toggleterm',
        },
        buftypes = {
          'terminal',
          'nofile',
          'prompt',
          'quickfix',
        },
      },
    })
  end

  local ok_guess, guess_indent = pcall(require, 'guess-indent')
  if ok_guess then
    guess_indent.setup({
      auto_cmd = true,
      override_editorconfig = false,
      filetype_exclude = {
        'netrw',
        'tutor',
        'help',
        'dashboard',
        'neo-tree',
        'terminal',
        'nofile',
        'lspinfo',
      },
      buftype_exclude = {
        'help',
        'nofile',
        'terminal',
        'prompt',
        'quickfix',
      },
    })
  end

  local ok_twilight, twilight = pcall(require, 'twilight')
  if ok_twilight then
    twilight.setup({
      dimming = {
        alpha = 0.25,
        color = { 'Normal', '#ffffff' },
        term_bg = '#000000',
        inactive = false,
      },
      context = 10,
      treesitter = true,
      expand = {
        'function',
        'method',
        'table',
        'if_statement',
      },
      exclude = {},
    })
  end

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'supercollider',
    callback = function()
      local ok_scnvim, scnvim = pcall(require, 'scnvim')
      if not ok_scnvim then
        return
      end

      scnvim.setup({
        editor = {
          highlight = {
            color = 'IncSearch',
          },
        },
        postwin = {
          float = {
            enabled = true,
          },
        },
      })
    end,
  })
end
