-- /qompassai/Diver/lsp/groovy_ls.lua
-- Qompass AI Groovy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['groovyls'] = {
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