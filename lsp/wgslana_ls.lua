-- /qompassai/Diver/lsp/wgslana_ls.lua
-- Qompass AI WGSL Analyzer LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://github.com/wgsl-analyzer/wgsl-analyzer
-- cargo install --git https://github.com/wgsl-analyzer/wgsl-analyzer wgsl-analyzer
---@type vim.lsp.Config
return {
    capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), {
        experimental = {
            snippetTextEdit = true,
            codeActionGroup = true,
            localDocs = true,
            serverStatusNotification = true,
            hoverActions = true,
            hoverRange = true,
            moveItem = true,
            workspaceSymbolScopeKindFiltering = true,
            commands = {
                commands = {},
            },
            colorDiagnosticOutput = true,
        },
    }),
    cmd = {
        'wgsl-analyzer',
    },
    filetypes = {
        'wgsl',
    },
    init_options = {
        ['wgsl-analyzer'] = {
            diagnostics = {
                enable = true,
                experimental = {
                    enable = true,
                },
                disabled = {
                    --'type-mismatch'
                },
            },
        },
    },
    root_markers = {
        '.git',
    },
    settings = {
        diagnostics = {
            enable = true,
            experimental = {
                enable = true,
            },
            disabled = {},
        },
    },
}
