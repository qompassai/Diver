-- /qompassai/Diver/lsp/slangd.lua
-- Qompass AI Diver Slangd LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/shader-slang/slang
return ---@type vim.lsp.Config
{
    cmd = {
        'slangd',
    },
    filetypes = {
        'hlsl',
        'shaderslang',
    },
    init_options = {
        slang = {
            additionalSearchPaths = {},
            predefinedMacros = {},
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
    },
    root_markers = {
        '.git',
    },
    settings = {},
}