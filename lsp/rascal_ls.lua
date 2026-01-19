-- /qompassai/Diver/lsp/rascal_ls.lua
-- Qompass AI Rascal LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'rascal-lsp',
    },
    filetypes = {
        'rascal',
        'rsc',
    },
    root_markers = {
        '.git',
        'rascal-project.json',
        'rascal-project.jsonc',
    },
    settings = {
        settings = {
            ['rascal-lsp'] = {
                rascalPath = nil,
                jvmOptions = {
                    '-Xmx2G',
                    '-Drascal.debug=true',
                },
                features = {
                    codeActions = true,
                    completion = true,
                    definitions = true,
                    diagnostics = true,
                    documentSymbols = true,
                    formatting = true,
                    hover = true,
                    references = true,
                    rename = true,
                    workspaceSymbols = true,
                },
                moduleSearchPaths = {
                    vim.fn.stdpath('data') .. '/rascal-lib',
                },
            },
        },
    },
}