-- /qompassai/Dive/lsp/slangd.lua
-- Qompass AI Slangd LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/shader-slang/slang
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    "slangd",
  },
  filetypes = { ---@type string[]
    "hlsl",
    "shaderslang",
  },
  root_markers = { ---@type string[]
    ".git",
  },
  init_options = {
    slang = {
      predefinedMacros = {}, ---@type string[]
      additionalSearchPaths = {}, ---@type string[]
      searchInAllWorkspaceDirectories = true, ---@type boolean
      completion = {
        commitCharacters = "memberOnly", ---@type string
      },
      format = {
        clangFormatLocation = "clang-format",
        clangFormatStyle = "file",
        clangFormatFallbackStyle = "LLVM",
      },
    },
    inlayHints = {
      deducedTypes = true,
      parameterNames = true,
    },
  },
}