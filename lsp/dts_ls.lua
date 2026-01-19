-- /qompassai/Diver/lsp/dts_ls.lua
-- Qompass AI Device Tree Source (DTS) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/igor-prusov/dts-lsp
-- cargo install --git https://github.com/igor-prusov/dts-lsp
---@type vim.lsp.Config
return {
    cmd = {
        'dts-lsp',
    },
    filetypes = {
        'dts',
        'dtsi',
        'overlay',
    },
    root_markers = {
        '.git',
    },
    settings = {
        devicetree = {
            defaultBindingType = 'Zephyr',
            defaultZephyrBindings = {
                os.getenv('HOME') .. '/.local/share/zephyrproject/zephyr/dts/bindings',
            },
            defaultIncludePaths = {
                os.getenv('HOME') .. '/.local/share/zephyrproject/zephyr/dts',
                os.getenv('HOME') .. '/.local/share/zephyrproject/zephyr/include',
            },
        },
    },
}