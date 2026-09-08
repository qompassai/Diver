-- /qompassai/Diver/lsp/idris2_ls.lua
-- Qompass AI Idris2 LSP SPec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return { ---@type vim.lsp.Config
    cmd = {
        'idris2-lsp',
    },
    filetypes = {
        'idris2',
        'idr',
        'lidr',
    },
    root_markers = {
        'idris2.toml',
        'idris2.yaml',
        '.ipkg',
        '.git',
    },
    settings = {
        idris2Lsp = {
            fullNamespace = false,
            logFile = vim.fn.stdpath('cache') .. '/idris2-lsp.log',
            logSeverity = 'Debug',
            longActionTimeout = 5000,
            maxCodeActionResults = 5,
            showImplicits = true,
            showMachineNames = false,
        },
    },
}
