-- /qompassai/Diver/lua/ui/line.lua
-- Qompass AI LuaLine Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}

require('lualine').setup({
  options           = {
    icons_enabled        = true,
    theme                = 'auto',
    component_separators = { left = '', right = '' },
    section_separators   = { left = '', right = '' },
    disabled_filetypes   = {
      statusline = {},
      winbar     = {},
    },
    ignore_focus         = {},
    always_divide_middle = false,
    globalstatus         = true,
    refresh              = {
      statusline   = 1000,
      tabline      = 1000,
      winbar       = 1000,
      refresh_time = 16,
      events       = {
        'WinEnter',
        'BufEnter',
        'BufWritePost',
        'SessionLoadPost',
        'FileChangedShellPost',
        'VimResized',
        'FileType',
        'CursorMoved',
        'CursorMovedI',
        'ModeChanged',
      },
    },
  },
  sections          = {
    lualine_a = {
      {
        'mode',
        icons_enabled = true,
        icon = nil,
      },
    },
    lualine_b = {
      {
        'branch',
        icon = '',
      },
      {
        'diff',
        colored = true,
        diff_color = {
          added    = 'LuaLineDiffAdd',
          modified = 'LuaLineDiffChange',
          removed  = 'LuaLineDiffDelete',
        },
        symbols = {
          added = '+',
          modified = '~',
          removed = '-',
        },
        source = nil,
      },
      {
        'diagnostics',
        sources           = { 'nvim_lsp', 'nvim_diagnostic', 'nvim_workspace_diagnostic' },
        sections          = { 'error', 'warn', 'info', 'hint' },
        diagnostics_color = {
          error = { fg = '#e06c75' },
          warn  = { fg = '#e5c07b' },
          info  = { fg = '#56b6c2' },
          hint  = { fg = '#98c379' },
        },
        symbols           = {
          error = ' ',
          warn  = ' ',
          info  = ' ',
          hint  = ' ',
        },
        colored           = true,
        update_in_insert  = true,
        always_visible    = false,
      },
    },
    lualine_c = {
      {
        'searchcount',
        maxcount = 999,
        timeout = 500,
      },
      {
        function()
          local wc = vim.fn.wordcount()
          local line_count = vim.api.nvim_buf_line_count(0)
          return string.format('%d words, %d chars, %d lines', wc.words, wc.chars, line_count)
        end,
        icon = '# ',
      },
    },
    lualine_x = {
      {
        'location'
      },
    },
    lualine_y = {
      {
        'progress'
      },
    },
    lualine_z = {
      {
        function() return os.date('%H:%M:%S') end,
        refresh = 1000,
      },
      {
        function() return os.date('%Y-%m-%d') end,
      },
    }
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      { 'filename'
      },
    },
    lualine_x = {
      { 'location'
      },
    },
    lualine_y = {},
    lualine_z = {},
  },
  tabline           = {
    lualine_a = {
      {
        'tabs',
        tab_max_length = 40,
        max_length = vim.o.columns / 3,
        mode = 0,
        use_mode_colors = true,
      },
    },
    lualine_b = {
      'branch'
    },
    lualine_c = {
      {
        'filename',
        file_status = true,
        newfile_status = true,
        path = 2,
        shorting_target = 40,
        symbols = {
          modified = '[+]',
          readonly = '[-]',
          unnamed = '[No Name]',
          newfile = '[New]',
        },
        {
          'filetype',
          colored = true,
          icon_only = false,
          icon = { align = 'right' },
        },
        {
          'fileformat',
          symbols = {
            unix = ' ',
            dos = ' ',
            mac = ' ',
          },
        },
      },
    },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
  winbar            = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      {
        'windows',
        mode = 2,
        use_mode_colors = true,
        max_length = vim.o.columns * 2 / 3,
      },
      {
        'lsp_status',
        icon = '',
        symbols = {
          spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
          done = '✓',
          separator = ' ',
        },
        ignore_lsp = {},
      },
      { 'branch'
      },
    },
    lualine_x = {
      { 'encoding' },
    },
    lualine_y = {},
    lualine_z = {},
  },
  inactive_winbar   = {},
  extensions        = {
    'fzf',
    'lazy',
    'mason',
    'neo-tree',
    'nvim-dap-ui',
    'nvim-tree',
    'quickfix',
    'toggleterm',
    'trouble',
  },
})
return M