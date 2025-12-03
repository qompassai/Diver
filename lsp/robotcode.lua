-- robotcode.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- pip install "robotcode[all]"
vim.lsp.config['robotcode'] = {
  cmd = { 'robotcode', 'language-server' },
  filetypes = { 'robot', 'resource' },
  root_markers = {
    'robot.toml', 'pyproject.toml', 'Pipfile', '.git' },
  get_language_id = function(_, _)
    return 'robotframework'
  end,
}