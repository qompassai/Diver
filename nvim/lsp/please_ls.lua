-- /qompassai/Diver/lsp/please_ls.lua
-- Qompass AI Please LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/thought-machine/please
--curl -s https://get.please.build | bash
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'plz',
        'tool',
        'lps',
    },
    filetypes = { ---@type string[]
        'bzl',
    },
    root_markers = { ---@type string[]
        '.plzconfig',
    },
}
