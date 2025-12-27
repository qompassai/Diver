-- /qompassai/Diver/lsp/dj_ls.lua
-- Qompass AI Django LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- uv tool install django-language-server
return {
  cmd = {
    'djls',
    'serve',
  },
  filetypes = {
    'html',
    'htmldjango',
    -- 'python',
  },
  root_markers = {
    'manage.py',
    'pyproject.toml',
    '.git',
  },
}