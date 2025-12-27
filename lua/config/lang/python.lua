-- /qompassai/Diver/lua/config/lang/python.lua
-- Qompass AI Diver Python Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd(
  'FileType',
  {
    pattern = 'python',
    callback = function()
      vim.opt_local.autoindent = true
      vim.opt_local.smartindent = true
      vim.api.nvim_buf_create_user_command(0, 'PythonLint', function()
        vim.lsp.buf.format()
        vim.cmd('write')
        vim.echo('Python code linted and formatted', vim.log.levels.INFO)
      end, {})
      vim.api.nvim_buf_create_user_command(0, 'PyTestFile', function()
        local file = vim.fn.expand('%:p')
        vim.cmd('split | terminal pytest ' .. file)
      end, {})
      vim.api.nvim_buf_create_user_command(0, 'PyTestFunc', function()
        local file = vim.fn.expand('%:p')
        local cmd = 'pytest ' .. file .. '::' .. vim.fn.expand('<cword>') .. ' -v'
        vim.cmd('split | terminal ' .. cmd)
      end, {})
    end,
  }
)
vim.api.nvim_create_autocmd('BufWritePre',
  {
    pattern = {
      '*.py',
    },
    callback = function(args)
      vim.lsp.buf.format({
        async = false,
        bufnr = args.buf,
        filter = function(client)
          return client.name == 'ruff_lsp' or client.name == 'ruff'
        end,
      })
    end,
  })