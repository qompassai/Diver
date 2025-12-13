-- /qompassai/Diver/lsp/glasgow_ls.lua
-- Qompass AI WebGPU Shading Language (WGSL) Glasgow LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------------------------
-- Reference: https://github.com/nolanderc/glasgow
-- cargo install glasgow
vim.lsp.config['glasgow_ls'] = {
    cmd = {
        'glasgow',
    },
    filetypes = {
        'wgsl',
    },
    root_markers = {
        'Cargo.toml',
        '.git',
        'package.json',
        'package.jsonc',
        'pnpm-lock.yaml',
        'yarn.lock',
    },
    settings = {},
}
