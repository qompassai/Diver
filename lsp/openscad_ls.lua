-- /qompassai/Diver/lsp/openscad_ls.lua
-- Qompass AI OpenSCAD LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/Leathong/openscad-LSP
-- cargo install openscad-lsp
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'openscad-lsp',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'openscad',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
