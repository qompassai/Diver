-- /qompassai/Diver/lsp/starlark_ls.lua
-- Qompass AI Starlark LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'starlark',
    '--lsp',
  },
  filetypes = { ---@type string[]
    'star',
    'bzl',
    'BUILD.bazel',
  },
  root_markers = { ---@type string[]
    '.git',
  },
}