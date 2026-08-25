-- /qompassai/Diver/lsp/dart_ls.lua
-- Qompass AI Dart LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'dart',
        'language-server',
        '--protocol=lsp',
    },
    filetypes = {
        'dart',
    },
    root_markers = {
        'pubspec.yaml',
    },
    init_options = {
        onlyAnalyzeProjectsWithOpenFiles = true,
        suggestFromUnimportedLibraries = true,
        closingLabels = true,
        outline = true,
        flutterOutline = true,
    },
    settings = {
        dart = {
            completeFunctionCalls = true,
            showTodos = true,
        },
    },
}
