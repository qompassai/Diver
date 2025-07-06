-- /qompassai/Diver/lua/plugins/core/flash.lua
-- Qompass AI Diver Flash Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
  {
    'kkharji/sqlite.lua',
    config = function()
      vim.g.sqlite_clib_path = '/usr/lib/libsqlite3.so'
    end
  }, {
  'folke/flash.nvim',
  event = 'VeryLazy',
  opts = {
    modes = {
      search = {
        enabled = true,
        highlight = { backdrop = true },
        jump = { history = true, register = true, nohlsearch = true }
      },
      char = {
        enabled = true,
        config = function(opts)
          opts.autohide = vim.fn.mode(true):find('no') and
              vim.v.operator == 'y'
        end,
        chars = { 'f', 'F', 't', 'T', ';', ',' },
        keys = { 'f', 'F', 't', 'T', ';', ',' }
      },
      treesitter = {
        labels = 'abcdefghijklmnopqrstuvwxyz',
        jump = { pos = 'start' },
        search = { incremental = true }
      }
    },
    prompt = { enabled = true, prefix = { { '⚡', 'FlashPromptIcon' } } }
  }
},
  {
    'ibhagwan/fzf-lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {}
  }, {
  'nvim-neo-tree/neo-tree.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim', 'nvim-tree/nvim-web-devicons',
    'MunifTanjim/nui.nvim'
  },
  cmd = 'Neotree',
  opts = {
    filesystem = {
      follow_current_file = { enabled = true, leave_dirs_open = false },
      use_libuv_file_watcher = true,
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false
      }
    },
    window = {
      position = 'left',
      width = 35,
      mappings = {
        ['s'] = 'noop',
        ['S'] = 'noop',
        ['<cr>'] = 'open',
        ['o'] = 'open',
        ['<2-LeftMouse>'] = 'open'
      }
    }
  }
}, {
  'folke/persistence.nvim',
  event = 'BufReadPre',
  opts = {
    dir = vim.fn.stdpath('data') .. '/sessions/',
    options = {
      'buffers', 'curdir', 'tabpages', 'winsize', 'help', 'globals',
      'skiprtp'
    },
    pre_save = nil,
    save_empty = false
  }
}, {
  'nvim-treesitter/nvim-treesitter-textobjects',
  dependencies = 'nvim-treesitter/nvim-treesitter',
  event = 'BufReadPost',
  config = function()
    require('nvim-treesitter.configs').setup({
      auto_install = true,
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ['Taf'] = '@function.outer',
            ['Tif'] = '@function.inner',
            ['Tac'] = '@class.outer',
            ['Tic'] = '@class.inner',
            ['Taa'] = '@parameter.outer',
            ['Tia'] = '@parameter.inner'
          }
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            [']m'] = '@function.outer',
            [']]'] = '@class.outer'
          },
          goto_next_end = {
            [']M'] = '@function.outer',
            [']['] = '@class.outer'
          },
          goto_previous_start = {
            ['[m'] = '@function.outer',
            ['[['] = '@class.outer'
          },
          goto_previous_end = {
            ['[M'] = '@function.outer',
            ['[]'] = '@class.outer'
          }
        }
      }
    })
  end
}, {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function() require('harpoon'):setup({}) end
}
}
