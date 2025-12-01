-- sql_ls.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['sql-language-server'] = {
  cmd = {
    'sql-language-server',
    'up',
    '--method',
    'stdio',
  },
  filetypes = {
    'sql',
    'mysql',
  },
  root_markers = {
    '.sqllsrc.json',
  },
  settings = {
    sqlLanguageServer = {
      connections = {
        {
        },
      },
      lint = {
        rules = {
          ["align-column-to-the-first"] = 'on',
          ["column-new-line"] = 'error',
          ["linebreak-after-clause-keyword"] = "error",
          ["reserved-word-case"] = {
            'error',
            'upper'
          },
          ["space-surrounding-operators"] = "error",
          ["where-clause-new-line"] = "error",
          ["align-where-clause-to-the-first"] = "error",
        },
      },
    },
  },
}