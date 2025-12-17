-- cssmodule_ls.lua
-- Qompass AI Diver CSS Module LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'cssmodules-language-server',
  },
  filetypes = { ---@type string[]
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
  },
  init_options = { ---@type string[]
    camelCase = 'dashes',
  },
  root_markers = { ---@type string[]
    'package.json'
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.definitionProvider = false ---@type boolean
  end,
}