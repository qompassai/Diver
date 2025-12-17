-- /qompassai/Diver/lsp/somesass_ls.lua
-- Qompass AI Some Sass LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g some-sass-language-server@latest
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'some-sass-language-server',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'scss',
    'sass',
  },
  root_markers = { ---@type string[]
    '.git',
    '.package.json',
    '.package.jsonc',
  },
  settings = { ---@type boolean[]
    somesass = {
      suggestAllFromOpenDocument = true,
    },
  },
}