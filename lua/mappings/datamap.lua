-- /qompassai/Diver/lua/mappings/datamap.lua
-- Qompass AI Diver Data Plugin Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.datamap'
local M = {}
function M.setup_datamap()
  local map = vim.keymap.set
  local ns = vim.api.nvim_create_namespace('latex_preview')
  local function toggle_line_math()
    local bufnr = vim.api.nvim_get_current_buf()
    local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { lnum, 0 }, { lnum, -1 }, {})
    if #marks > 0 then
      vim.api.nvim_buf_clear_namespace(bufnr, ns, lnum, lnum + 1)
      return
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ''
    local math = line:match('%$(.-)%$') or line:match('%$%$(.-)%$%$') or line
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, -1, {
      virt_text = {
        {
          ' ⟹ ' .. math, 'Comment'
        }
      },
      virt_text_pos = 'eol',
    })
  end

  local function toggle_all_math()
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.b.latex_preview_enabled then
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      vim.b.latex_preview_enabled = false
      return
    end
    vim.b.latex_preview_enabled = true
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, line in ipairs(lines) do
      local math = line:match('%$(.-)%$') or line:match('%$%$(.-)%$%$')
      if math then
        vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, -1, {
          virt_text = { { ' ⟹ ' .. math, 'Comment' } },
          virt_text_pos = 'eol',
        })
      end
    end
  end
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local bufnr = ev.buf
      local opts = {
        noremap = true,
        silent = true,
        buffer = bufnr,
      }
      map('n', '<leader>mp', toggle_line_math, vim.tbl_extend('force', opts, {
        desc = 'Preview LaTeX (virt text)',
      }))
      map('n', '<leader>mt', toggle_all_math, vim.tbl_extend('force', opts, {
        desc = 'Toggle LaTeX virt text',
      }))
    end,
  })
end

return M