-- /qompassai/Diver/lsp/gdshader_ls.lua
-- Qompass AI GDShader LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['gdshader_ls'] = {
    cmd = {
        'gdshader-lsp',
        '--stdio',
    },
    filetypes = {
        'gdshader',
        'gdshaderinc',
    },
    root_markers = {
        'project.godot',
    },
}
