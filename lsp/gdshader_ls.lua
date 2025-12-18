-- /qompassai/Diver/lsp/gdshader_ls.lua
-- Qompass AI GDShader LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'gdshader-lsp',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'gdshader',
        'gdshaderinc',
    },
    root_markers = { ---@type string[]
        'project.godot',
    },
}
