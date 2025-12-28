-- qompassai/Diver/lua/config/data/sqlite.lua
-- Qompass AI Diver SQLite Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.sqlite_ftd()
  vim.filetype.add({
    extension = {
      sqlite = 'sqlite',
      sqlite3 = 'sqlite',
      db = 'sqlite'
    },
    pattern = {
      ['%.lite%.sql$'] = 'sqlite',
      ['%.sqlite%.sql$'] = 'sqlite'
    },
  })
end

function M.sqlite_keymaps(opts)
  opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
    ['<leader>Ds'] = {
      name = '+sqlite'
    },
    ['<leader>Dsf'] = {
      '<cmd>lua require(\'conform\').format()<cr>',
      'Format SQLite',
    },
    ['<leader>Dst'] = { '<cmd>DBUIToggle<cr>', 'Toggle DBUI' },
    ['<leader>Dsa'] = { '<cmd>DBUIAddConnection<cr>', 'Add Connection' },
    ['<leader>Dsh'] = { '<cmd>DBUIFindBuffer<cr>', 'Find DB Buffer' },
    ['<leader>Dse'] = {
      function()
        if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
          vim.cmd('\'<,\'>DB')
        else
          vim.cmd('DB')
        end
      end,
      'Execute Query',
    },
    ['<leader>Dsst'] = {
      '<cmd>DB SELECT name FROM sqlite_master WHERE type=\'table\'<cr>',
      'List Tables',
    },
    ['<leader>Dssi'] = {
      '<cmd>DB SELECT * FROM sqlite_master WHERE type=\'index\'<cr>',
      'List Indexes',
    },
    ['<leader>Dssv'] = {
      '<cmd>DB PRAGMA schema_version<cr>',
      'Schema Version',
    },
  })
  return opts
end

return M