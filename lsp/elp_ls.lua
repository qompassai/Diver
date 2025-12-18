--/qompassai/Diver/lsp/elp.lua
-- Qompass AI Erlang Language Platform (ELP) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'elp',
        'server',
    },
    filetypes = { ---@type string[]
        'erlang',
    },
    root_markers = { ---@type string[]
        'erlang.mk',
        '.git',
        'rebar.config',
    },
}
