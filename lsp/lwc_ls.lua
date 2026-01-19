-- /qompassai/Diver/lsp/lwc_ls.lua
-- Qompass AI Lightning Web Components (LWC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'lwc-language-server',
        '--stdio',
    },
    filetypes = {
        'javascript',
        'html',
    },
    init_options = {
        embeddedLanguages = {
            javascript = true,
        },
    },
    root_markers = {
        'sfdx-project.json',
    },
    settings = {},
}