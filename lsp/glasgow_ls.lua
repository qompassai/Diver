-- /qompassai/Diver/lsp/glasgow_ls.lua
-- Qompass AI WebGPU Shading Language (WGSL) Glasgow LSP Spec
-- Reference: https://github.com/nolanderc/glasgow
-- cargo install glasgow
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
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
