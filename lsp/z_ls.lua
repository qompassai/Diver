-- /qompassai/Diver/lsp/z_ls.lua
-- Qompass AI ZLS LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://raw.githubusercontent.com/zigtools/zls/master/schema.json
return ---@type vim.lsp.Config
{
    cmd = {
        'zls',
        '--enable-stderr-logs',
    },
    filetypes = {
        'zig',
        'ziggy',
        'zine',
        'zon',
    },
    root_markers = {
        'build.zig',
        'build.zig.zon',
        '.git',
    },
    settings = {
        zls = {
            build_on_save_args = {
                'check',
                'test',
            },
            build_runner_path = {},
            builtin_path = {},
            completion_label_details = true,
            enable_argument_placeholders = true,
            enable_ast_check_diagnostics = true,
            enable_autofix = true,
            enable_build_on_save = false,
            enable_import_embedfile_argument_completions = true,
            enable_imports_on_completion = true,
            enable_inlay_hints = true,
            enable_snippets = true,
            force_autofix = true,
            global_cache_path = {},
            highlight_global_var_declarations = true,
            inlay_hints = {
                parameter_names = true,
                variable_names = true,
                builtin = true,
                type_names = true,
            },
            inlay_hints_exclude_single_argument = true,
            inlay_hints_hide_redundant_param_names = false,
            inlay_hints_hide_redundant_param_names_last_token = false,
            inlay_hints_show_builtin = true,
            inlay_hints_show_parameter_name = true,
            inlay_hints_show_struct_literal_field_type = true,
            inlay_hints_show_variable_type_hints = true,
            operator_completions = true,
            prefer_ast_check_as_child_process = true,
            semantic_tokens = 'full',
            skip_std_references = false,
            warn_style = true,
            zig_exe_path = '/usr/bin/zig',
        },
    },
}
