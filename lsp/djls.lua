-- /qompassai/Diver/lsp/djls.lua
-- Qompass AI Django LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- uv tool install django-language-server
vim.lsp.config['djls'] = {
  cmd = {
    'djls',
    'serve'
  },
  filetypes = {
    'htmldjango',
    'html',
    'python'
  },
  root_markers = {
    'manage.py',
    'pyproject.toml',
    '.git'
  },
}