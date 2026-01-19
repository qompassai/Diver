-- /qompassai/Diver/lsp/qml_ls.lua
-- Qompass AI QML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'qml-lsp',
    },
    filetypes = { ---@type string[]
        'qml',
        'qmljs',
    },
    settings = { ---@type string[]
        ...,
    },
}
