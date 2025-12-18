-- /qompassai/Diver/lsp/helm_ls.lua
-- Qompass AI Helm LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'helm_ls',
        'serve',
    },
    filetypes = { ---@type string[]
        'helm',
        'yaml.helm-values',
    },
    root_markers = { ---@type string[]
        'Chart.yaml',
    },
    capabilities = {
        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true,
            },
        },
    },
}
