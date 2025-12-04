-- /qompassai/Dive/lsp/slangd.lua
-- Qompass AI Slangd LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/shader-slang/slang
vim.lsp.config['slangd'] = {
  cmd = {
    'slangd'
  },
  filetypes = {
    'hlsl',
    'shaderslang'
  },
  root_markers = {
    '.git'
  },
}
settings = {
  slang = {
    predefinedMacros = {
      ...
    },
    additionalSearchPaths = {
    },
    searchInAllWorkspaceDirectories = true,
    completion = {
      commitCharacters = 'memberOnly',
    },
    format = {
      clangFormatLocation = 'clang-format',
      clangFormatStyle = 'file',
      clangFormatFallbackStyle = 'LLVM',
    },
  },
  inlayHints = {
    deducedTypes = true,
    parameterNames = true,
  },
  init_options = {
    slang = {
      additionalSearchPaths = {
        ...
      },
    },
  },
}