-- /qompassai/Diver/lsp/syntax_tree.lua
-- Qompass AI Syntax Tree LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://ruby-syntax-tree.github.io/syntax_tree/
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'stree',
        'lsp',
    },
    filetypes = { ---@type string[]
        'ruby',
    },
    root_markers = { ---@type string[]
        'Gemfile',
        '.git',
        '.streerc',
    },
}
