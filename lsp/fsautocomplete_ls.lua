-- /qompassai/Diver/lsp/fsautocomplete_ls.lua
-- Qompass AI F# AutoComplete LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'fsautocomplete',
        '--adaptive-lsp-server-enabled',
    },
    filetypes = {
        'fsharp',
    },
    init_options = {
        AutomaticWorkspaceInit = true,
    },
    root_markers = {
        '*.fsproj',
        '.git',
        '*.sln',
    },
    settings = {
        FSharp = {
            EnableReferenceCodeLens = true,
            ExternalAutocomplete = true,
            InterfaceStubGeneration = true,
            InterfaceStubGenerationObjectIdentifier = 'this',
            InterfaceStubGenerationMethodBody = 'failwith "Not Implemented"',
            keywordsAutocomplete = true,
            Linter = true,
            RecordStubGeneration = true,
            RecordStubGenerationBody = 'failwith "Not Implemented"',
            ResolveNamespaces = true,
            SimplifyNameAnalyzer = true,
            UnusedOpensAnalyzer = true,
            UnusedDeclarationsAnalyzer = true,
            UnionCaseStubGeneration = true,
            UnionCaseStubGenerationBody = 'failwith "Not Implemented"',
            UseSdkScripts = true,
        },
    },
}