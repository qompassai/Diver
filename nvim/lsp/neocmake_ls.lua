-- /qompassai/Diver/lsp/neocmake_ls.lua
-- Qompass AI Neocmake LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'neocmakelsp',
        'stdio',
    },
    filetypes = { ---@type string[]
        'cmake',
    },
    init_options = {
        format = {
            enable = true,
        },
        lint = {
            enable = true,
        },
        scan_cmake_in_package = true,
    },
    root_markers = { ---@type string[]
        '.neocmake.toml',
        'CMakeLists.txt',
        'CMakeCache.txt',
        'build',
        '.git',
    },
}
