-- /qompassai/Diver/lsp/z_ls.lua
-- Qompass AI ZLS LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['z_ls'] = {
    cmd = {
        'zls',
        '--config-path',
        os.getenv('HOME') .. '/.config/zls/zls.jsonc',
        '--enable-stderr-logs',
    },
    filetypes = {
        'zig',
        'zon',
        'ziggy',
        'zine',
    },
    root_markers = {
        'build.zig',
        'build.zig.zon',
        '.git',
    },
    settings = {
        zls = {
            enable_ast_check_diagnostics = true,
            enable_build_on_save = true,
            enable_inlay_hints = true,
            inlay_hints = {
                parameter_names = true,
                variable_names = true,
                builtin = true,
                type_names = true,
            },
        },
    },
}
