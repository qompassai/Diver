-- /qompassai/Diver/lsp/bufls.lua
-- Qompass AI Buf LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'buf',
    'lsp',
    'serve',
    '--timeout=0',
    '--log-format=text',
  },
  filetypes = {
    'proto',
  },
  root_markers = {
    'buf.yaml',
    '.git',
  },
  reuse_client = function(client, config)
    return client.name == config.name
  end,
}