-- /qompassai/Diver/lsp/unison_ls.lua
-- Qompass AI Diver Unison LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'nc',
    'localhost',
    os.getenv('UNISON_LSP_PORT') or '5757',
    -- 'socat', 'STDIO', 'TCP:127.0.0.1:5757',
  },
  filetypes = {
    'unison'
  },
  root_markers = {
    '.git',
    '.unisonConfig',
  },
  settings = {},
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
    vim.api.nvim_create_autocmd('CursorHold',
      {
        buffer = bufnr,
        callback = function()
          local opts = {
            focusable = false,
            close_events = {
              'BufLeave',
              'CursorMoved',
              'InsertEnter',
              'FocusLost'
            },
            border = 'rounded',
            source = 'always',
            prefix = ' ',
            scope = 'cursor',
          }
          vim.diagnostic.open_float(nil, opts)
        end,
      })
  end
}