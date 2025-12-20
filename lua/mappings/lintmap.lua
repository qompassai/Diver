-- /qompassai/Diver/lua/mappings/lintmap.lua
-- Qompass AI Diver Linter Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}

function M.setup_lintmap()
  local map = vim.keymap.set
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local bufnr = ev.buf
      local opts = {
        noremap = true,
        silent = true,
        buffer = bufnr
      }
      map('n', '<leader>li', function()
        local ok, lint = pcall(require, 'lint') ---@type boolean
        if not ok then
          vim.echo('nvim-lint not available', vim.log.levels.WARN)
          return
        end
        local ft = vim.bo.filetype
        local linters = lint.linters_by_ft[ft] or {}
        if #linters == 0 then
          vim.echo('No linters configured for filetype: ' .. ft, vim.log.levels.INFO)
        else
          vim.echo('Available linters: ' .. table.concat(linters, ', '), vim.log.levels.INFO)
        end
      end, vim.tbl_extend('force', opts,
        {
          desc = 'Show available linters'
        }
      ))
      map('n', '<leader>lf', function()
        local ok_conform, conform = pcall(require, 'conform') ---@type boolean
        if not ok_conform then
          vim.echo('conform.nvim not available', vim.log.levels.WARN)
          return
        end
        local ok_lint, lint = pcall(require, 'lint')
        if not ok_lint then
          vim.echo('nvim-lint not available', vim.log.levels.WARN)
          return
        end
        conform.format(
          {
            async = true
          },
          function()
            lint.try_lint()
          end)
      end, vim.tbl_extend('force', opts,
        {
          desc = 'Format and lint'
        }))
      map('n', '<leader>cd', function()
        vim.diagnostic.reset()
      end, vim.tbl_extend('force', opts,
        {
          desc = 'Clear diagnostics'
        }))
    end,
  })
end

return M