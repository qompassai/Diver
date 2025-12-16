-- /qompassai/Diver/lsp/robotframework_ls.lua
-- Qompass AI Robot Framework LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'robotframework_ls'
  },
  filetypes = { ---@type string[]
    'robot'
  },
  root_markers = { ---@type string[]
    'robotidy.toml',
    'pyproject.toml',
    'conda.yaml',
    'robot.yaml',
    '.git',
  },
}