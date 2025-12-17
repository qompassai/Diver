-- /qompassai/Diver/lsp/tvmffi_navigator.lua
-- Qompass AI TVM FFI Navigator LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/tqchen/ffi-navigator
--pip install ffi-navigator
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'python',
    '-m',
    'ffi_navigator.langserver',
  },
  filetypes = { ---@type string[]
    'python',
    'cpp',
  },
  root_markers = { ---@type string[]
    'pyproject.toml',
    '.git',
  },
}