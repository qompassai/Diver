-- /qompassai/Diver/lsp/solargraph_ls.lua
-- Qompass AI Solargraph LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- References:  https://solargaraph.org/
---@type vim.lsp.Config
return {
    cmd = {
        'solargraph', ---@type string[]
        'stdio',
    },
    settings = {
        solargraph = {
            diagnostics = true, ---@type boolean
        },
    },
    init_options = {
        formatting = true,
    },
    filetypes = { ---@type string[]
        'ruby',
    },
    root_markers = { ---@type string[]
        'Gemfile',
        '.git',
    },
}
