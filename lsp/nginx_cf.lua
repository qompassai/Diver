-- /qompassai/Diver/lsp/nginx_formatter.lua
-- Qompass AI Nginx Config Formatter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['nginx_formatter'] = {
  cmd = { 'nginxfmt.py' },
  filetypes = { 'nginx', 'nginx.conf' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    nginx_formatter = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}