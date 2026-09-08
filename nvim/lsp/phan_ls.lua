-- /qompassai/Diver/lsp/phan_ls.lua
-- Qompass AI Diver Phan LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'phan',
        '-m',
        'json',
        '--no-color',
        '--no-progress-bar',
        '-x',
        '-u',
        '-S',
        '--language-server-on-stdin',
        '--allow-polyfill-parser',
    },
    filetypes = {
        'php',
    },
    root_markers = {
        'composer.json',
        '.git',
    },
    settings = { ---@source https://github.com/phan/phan/wiki/Phan-Config-Settings
        phan = {
            analyzed_file_extensions = {
                'htm',
                'html',
                'php',
            },
            consistent_hashing_file_order = true,
            directory_list = {},
            exclude_analysis_directory_list = {},
            exclude_file_list = {},
            skip_slow_php_options_warning = {},
        },
    },
}
