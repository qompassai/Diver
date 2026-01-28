-- qompassai/Diver/lua/config/lang/mojo.lua
-- Qompass AI Diver Mojo Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.setup()
  M.mojo_autocmds()
  local ok_dap, dap = pcall(require, 'dap')
  if ok_dap and dap then
    dap.adapters.mojo_lldb = {
      type = 'executable',
      command = vim.fn.expand('~/.local/share/mojo/.pixi/envs/default/bin/mojo-lldb-dap'),
      env = { CONDA_PREFIX = vim.fn.expand('~/.local/share/mojo/.pixi/envs/default') },
      name = 'mojo_lldb',
    }
    dap.configurations.mojo = {
      {
        name = 'Mojo: Launch file',
        type = 'mojo_lldb',
        request = 'launch',
        program = function()
          return vim.api.nvim_buf_get_name(0)
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = {},
      },
    }
  end
end

function M.mojo_autocmds()
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'mojo',
    callback = function(args)
      local bufnr = args.buf
      if vim.bo[bufnr].filetype ~= 'mojo' then
        return
      end
      vim.bo[bufnr].tabstop = 4
      vim.bo[bufnr].shiftwidth = 4
      vim.bo[bufnr].expandtab = true
      vim.bo[bufnr].commentstring = '# %s'
      vim.opt_local.formatoptions:append('jcroql')
      vim.keymap.set('n', '<leader>mr', ':MojoRun<CR>', {
        buffer = bufnr,
        desc = 'Mojo: Run',
      })
      vim.keymap.set('n', '<leader>md', function()
        require('dap').continue()
      end, {
        buffer = bufnr,
        desc = 'Mojo: Debug',
      })
    end,
  })
end

return M