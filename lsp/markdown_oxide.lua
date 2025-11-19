-- /qompassai/Diver/lsp/markdown_oxide.lua
-- Qompass AI Markdown_oxide LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['markdown_oxide'] = {
  cmd = { 'markdown-oxide' },
  root_markers = { '.git', '.obsidian', '.moxide.toml' },
  filetypes = { 'markdown' },

  on_attach = function(_, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'LspToday', function()
      vim.lsp.buf.execute_command { command = 'jump', arguments = { 'today' } }
    end, {
      desc = "Open today's daily note",
    })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspTomorrow', function()
      vim.lsp.buf.execute_command { command = 'jump', arguments = { 'tomorrow' } }
    end, {
      desc = "Open tomorrow's daily note",
    })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspYesterday', function()
      vim.lsp.buf.execute_command { command = 'jump', arguments = { 'yesterday' } }
    end, {
      desc = "Open yesterday's daily note",
    })
  end,
}