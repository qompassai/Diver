-- /qompassai/Diver/lsp/roslyn_ls.lua
-- Qompass AI Roslyn LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['roslyn_ls'] = {
    name = 'roslyn_ls',
    offset_encoding = 'utf-8',
    cmd = {
        'Microsoft.CodeAnalysis.LanguageServer',
        '--logLevel',
        'Information',
        '--extensionLogDirectory',
        '--stdio',
    },
    filetypes = {
        'cs',
    },
    commands = {
        ['roslyn.client.completionComplexEdit'] = function(command, ctx)
            local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
            local args = command.arguments or {}
            local uri, edit = args[1], args[2]
            ---@diagnostic disable: undefined-field
            if uri and edit and edit.newText and edit.range then
                local workspace_edit = {
                    changes = {
                        [uri.uri] = {
                            {
                                range = edit.range,
                                newText = edit.newText,
                            },
                        },
                    },
                }
                vim.lsp.util.apply_workspace_edit(workspace_edit, client.offset_encoding)
            else
                vim.notify(
                    'roslyn_ls: completionComplexEdit args not understood: ' .. vim.inspect(args),
                    vim.log.levels.WARN
                )
            end
            ---@diagnostic enable: undefined-field
        end,
    },
    settings = {
        ['csharp|background_analysis'] = {
            dotnet_analyzer_diagnostics_scope = 'fullSolution',
            dotnet_compiler_diagnostics_scope = 'fullSolution',
        },
        ['csharp|inlay_hints'] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
            dotnet_enable_inlay_hints_for_indexer_parameters = true,
            dotnet_enable_inlay_hints_for_literal_parameters = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
            dotnet_enable_inlay_hints_for_other_parameters = true,
            dotnet_enable_inlay_hints_for_parameters = true,
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
        },
        ['csharp|symbol_search'] = {
            dotnet_search_reference_assemblies = true,
        },
        ['csharp|completion'] = {
            dotnet_show_name_completion_suggestions = true,
            dotnet_show_completion_items_from_unimported_namespaces = true,
            dotnet_provide_regex_completions = true,
        },
        ['csharp|code_lens'] = {
            dotnet_enable_references_code_lens = true,
        },
    },
}
