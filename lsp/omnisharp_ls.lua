-- /qompassai/Diver/lsp/omnisharp_ls.lua
-- Qompass AI OmniSharp Roslyn LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://github.com/omnisharp/omnisharp-roslyn
---@type vim.lsp.Config
return {
    cmd = {
        'omnisharp',
        '-z',
        '--hostPID',
        tostring(vim.fn.getpid()),
        'DotNet:enablePackageRestore=false',
        '--encoding',
        'utf-8',
        '--languageserver',
    },
    filetypes = { ---@type string[]
        'cs',
        'vb',
    },
    init_options = {},
    capabilities = {
        workspace = {
            workspaceFolders = false, ---@type boolean
        },
    },
    root_markers = { ---@type string[]
        '*.sln',
        '*.csproj',
        'omnisharp.json',
        'omnisharp.jsonc',
        'function.json',
        'function.jsonc',
    },
    settings = {
        FormattingOptions = {
            EnableEditorConfigSupport = true,
            OrganizeImports = nil,
        },
        MsBuild = {
            LoadProjectsOnDemand = nil,
        },
        RoslynExtensionsOptions = {
            EnableAnalyzersSupport = nil,
            EnableImportCompletion = nil,
            AnalyzeOpenDocumentsOnly = nil,
            EnableDecompilationSupport = nil,
        },
        RenameOptions = {
            RenameInComments = nil,
            RenameOverloads = nil,
            RenameInStrings = nil,
        },
        Sdk = {
            IncludePrereleases = true,
        },
    },
}
