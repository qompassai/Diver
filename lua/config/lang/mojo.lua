-- qompassai/Diver/lua/config/lang/mojo.lua
-- Qompass AI Diver Mojo Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'config.lang.mojo'
local M = {}
function M.mojo_filetype()
  local ok, ft = pcall(require, 'filetype')
  if ok then
    ft.add({
      extension = {
        mojo = 'mojo'
      },
      pattern = {
        ['.*%.🔥'] = 'mojo'
      }
    })
  else
    vim.cmd([[
      augroup MojoFiletype
        autocmd BufNewFile,BufRead *.mojo set filetype=mojo
        autocmd BufNewFile,BufRead *.🔥 set filetype=mojo
      augroup END
    ]])
  end
end

function M.mojo_autocmds()
  pcall(vim.api.nvim_create_autocmd, 'FileType',
    {
      pattern = {
        'mojo'
      },
      callback = function(args)
        if vim.bo[args.buf].filetype ~= 'mojo' then
          return
        end
        vim.opt_local.tabstop = 4
        vim.opt_local.shiftwidth = 4
        vim.opt_local.expandtab = true
        pcall(vim.keymap.set, 'n', '<leader>mr', ':MojoRun<CR>', {
          buffer = args.buf, desc = 'Run Mojo file'
        })
        pcall(vim.keymap.set, 'n', '<leader>md', ':MojoDebug<CR>',
          { buffer = args.buf, desc = 'Debug Mojo file'
          })
      end,
    })
end

function M.mojo_setup(opts)
  opts = vim.tbl_deep_extend('force', {
    format_on_save = true,
    enable_linting = true,
    dap_enabled = false,
    keymaps = true,
  }, opts or {})
  M.mojo_filetype()
  M.mojo_autocmds()
  return M
end

return M