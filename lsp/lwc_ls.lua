-- /qompassai/Diver/lsp/lwc_ls.lua
-- Qompass AI Lightning Web Components (LWC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------

return ---@type vim.lsp.Config
{
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
        'sfdx-project.jsonc',
    },
    settings = {},
}
