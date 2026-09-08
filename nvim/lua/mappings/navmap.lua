-- /qompassai/Diver/lua/mappings/navmap.lua
-- Qompass AI Diver Nav Plugin Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.navmap'
local M = {}
function M.setup_navmap()
  local map = vim.keymap.set
  local fzf_maps = require('config.nav.fzf').keymaps
  for _, m in ipairs(fzf_maps) do
    local lhs, rhs = m[1], m[2]
    local desc = m.desc
    map('n', lhs, rhs, {
      noremap = true,
      silent = true,
      desc = desc,
    })
  end
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local bufnr = ev.buf
      local opts = {
        noremap = true,
        silent = true,
        buffer = bufnr,
      }
      map(
        {
          'n',
          'x',
          'o',
        },
        's',
        function()
          require('flash').jump()
        end,
        vim.tbl_extend('force', opts, {
          desc = 'Flash jump',
        })
      )
      map(
        {
          'n',
          'x',
          'o',
        },
        'S',
        function()
          require('flash').jump({
            search = {
              forward = false,
            },
          })
        end,
        vim.tbl_extend('force', opts, {
          desc = 'Flash jump backward',
        })
      )
      map(
        'o',
        'r',
        function()
          require('flash').remote()
        end,
        vim.tbl_extend('force', opts, {
          desc = 'Remote Flash',
        })
      )
      map(
        {
          'o',
          'x',
        },
        'R',
        function()
          require('flash').treesitter_search()
        end,
        vim.tbl_extend('force', opts, {
          desc = 'Treesitter Search',
        })
      )
      map(
        'c',
        '<C-s>',
        function()
          require('flash').toggle()
        end,
        vim.tbl_extend('force', opts, {
          desc = 'Toggle Flash Search',
        })
      )
      map('n', '<leader>e', function()
        local dir = vim.fn.expand('%:p:h')
        if dir == '' then
          dir = '.'
        end
        vim.cmd.edit(dir)
      end, {
        desc = 'Browse current directory',
      })
    end,
  })
end
return M
