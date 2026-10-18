-- /qompassai/Diver/lsp/gdshader_ls.lua
-- Qompass AI GDShader LSP Spec
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
