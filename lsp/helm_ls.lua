-- /qompassai/Diver/lsp/helm_ls.lua
-- Qompass AI Helm LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['helm_ls'] = {
    cmd = {
        'helm_ls',
        'serve',
    },
    filetypes = { 'helm', 'yaml.helm-values' },
    root_markers = { 'Chart.yaml' },
    capabilities = {
        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true,
            },
        },
    },
}
