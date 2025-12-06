-- /qompassai/Diver/lsp/groovy_ls.lua
-- Qompass AI Groovy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/prominic/groovy-language-server.git
vim.lsp.config['groovy_ls'] = {
  cmd = {
    'java',
    '-jar',
    'groovy-language-server-all.jar'
  },
  filetypes = {
    'groovy'
  },
  root_markers = {
    '.git',
    'Jenkinsfile'
  },
}