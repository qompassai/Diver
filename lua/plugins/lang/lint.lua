-- /qompassai/Diver/lua/plugins/lang/nvim-lint.lua
-- Qompass AI Linter Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  'mfussenegger/nvim-lint',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    local lint = require('lint')
    local lint_config = require('config.lang.lint')
    lint_config.setup_linters(lint)
    local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' },
      {
        group = lint_augroup,
        callback = function() lint.try_lint() end
      })
    vim.keymap.set('n', '<leader>l', function() lint.try_lint() end,
      { desc = 'Trigger linting for current file' })
  end
}
