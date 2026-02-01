-- /qompassai/Diver/lsp/fish_ls.lua
-- Qompass AI Fish LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/ndonfris/fish-lsp

return ---@type vim.lsp.Config
{
    cmd = {
        'fish-lsp',
        'start',
    },
    filetypes = {
        'fish',
    },
    root_markers = {
        'config.fish',
        '.git',
    },
    settings = {
        fish_lsp = {
            fish_lsp_all_indexed_paths = {
                '$__fish_config_dir',
                '$__fish_data_dir',
            },
            fish_lsp_allow_fish_wrapper_functions = true,
            fish_lsp_commit_characters = {
                '\t',
                ';',
                ' ',
            },
            fish_lsp_diagnostic_disable_error_codes = {
                4004,
                7001,
            },
            fish_lsp_disabled_handlers = {},
            fish_lsp_enable_experimental_diagnostics = true,
            fish_lsp_enabled_handlers = {},
            fish_lsp_fish_path = 'fish',
            fish_lsp_ignore_paths = {
                '**/.git/**',
                '**/__pycache__/**',
                '**/build/**',
                '**/containerized/**',
                '**/dist/**',
                '**/docker/**',
                '**/node_modules/**',
                '**/target/**',
                '**/vendor/**',
            },
            fish_lsp_log_file = '', -- Set to '/tmp/fish_lsp.log' for debugging
            fish_lsp_log_level = 'info',
            fish_lsp_max_background_files = 10000,
            fish_lsp_max_diagnostics = 0,
            fish_lsp_max_workspace_depth = 3,
            fish_lsp_modifiable_paths = {
                '$__fish_config_dir',
            },
            fish_lsp_prefer_builtin_fish_commands = false,
            fish_lsp_require_autoloaded_functions_to_have_description = true,
            fish_lsp_show_client_popups = false,
            fish_lsp_single_workspace_support = false,
            fish_lsp_strict_conditional_command_warnings = false,
        },
    },
}
