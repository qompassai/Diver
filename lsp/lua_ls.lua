-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Diver Lua_ls LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'lua-language-server',
    },
    filetypes = {
        'lua',
        'luau',
    },
    init_options = {},
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        '.emmyrc.json',
        '.git',
        'luacheckrc',
        '.luacheckrc',
        '.luarc.json',
        'luarc.json',
        '.luarc.jsonc',
        'luarc.jsonc',
        '.luarc.json5',
        'selene.toml',
        'selene.yml',
        '.stylua.toml',
        'stylua.toml',
    },
    settings = {
        Lua = {
            addonManager = {
                enable = false,
                repositoryBranch = '',
                repositoryPath = '',
            },
            codeLens = {
                enable = true,
            },
            completion = {
                autoRequire = true,
                callSnippet = 'Both',
                displayContext = 1,
                enable = true,
                keywordSnippet = 'Both',
                postfix = '@',
            },
            diagnostics = {
                disable = {
                    'lowercase-global',
                    'duplicate-index',
                    'duplicate-set-field',
                    'duplicate-doc-alias',
                    'duplicate-doc-field',
                },
                disableScheme = {
                    'git',
                },
                enable = true,
                globals = {
                    'agutils', ---wp
                    'assert',
                    'AsyncEventHook', ---wp
                    'bit32', ---wp
                    'buildDefaultChannelVolumes', ---wp
                    'client',
                    'Client',
                    'Conf', ---wp
                    'config', ---wp
                    'Constraint',
                    'Core',
                    'cutils', ---wp
                    'describe',
                    'EventInterest', ---wp
                    'Feature', ---wp
                    'Features', ---wp
                    'findAssociatedLinkGroupNode', ---wp
                    'formKey', ---wp
                    'futils', ---wp
                    'getStoredStreamProps', ---wp
                    'GLib', ---wp
                    'group', ---wp
                    'group_loopback_modules', ---wp
                    'ImplMetadata', ---wp
                    'Interest', ---wp
                    'it',
                    'items', ---wp
                    'jit',
                    'Json', ---wp
                    'JsonUtils', ---wp
                    'LocalModule', ---wp
                    'LazyVim', ---lazyvim
                    'Log', ---wp
                    'lutils', ---wp
                    'node_directions',
                    'ObjectManager', ---wp
                    'onLinkGroupPortsStateChanged', ---wp
                    'os_getenv', ---luarocks
                    'Plugin', ---wp
                    'Pod', ---wp
                    'ProcUtils', ---wp
                    'PW_AUDIO_NAMESPACE', ---wp
                    'reconfigureAudioAdapters', ---wp
                    'require',
                    'restore_stream_hook', ---wp
                    'route_settings_metadata_changed_hook', ---wp
                    'rs_metadata', ---wp
                    'saveStreamProps', ---wp
                    'Script', ---wp
                    'SessionItem', ---wp
                    'Settings', ---wp
                    'SimpleEventHook', ---wp
                    'sources', ---wp
                    'state', ---wp
                    'State', ---wp
                    'state_table',
                    'store_stream_props_hook', ---wp
                    'store_stream_target_hook', ---wp
                    'toggleState', ---wp
                    'use',
                    'vim',
                },
                groupFileStatus = {
                    ambiguity = 'Any',
                    await = 'Any',
                    -- codestyle      = 'Opened',
                    duplicate = 'Any',
                    global = 'Any',
                    luadoc = 'Any',
                    redefined = 'Any',
                    strict = 'Any',
                    --strong = 'Opened',
                    ['type-check'] = 'Any',
                    unused = 'Any',
                },
                groupSeverity = {
                    ambiguity = 'Warning',
                    await = 'Warning',
                    -- codestyle      = 'Information',
                    duplicate = 'Warning',
                    global = 'Error',
                    luadoc = 'Warning',
                    redefined = 'Warning',
                    strict = 'Warning',
                    --strong = 'Warning',
                    ['type-check'] = 'Error',
                    unbalanced = 'Warning',
                    unused = 'Hint',
                },
                ignoredFiles = 'Disable',
                libraryFiles = 'Opened',
                neededFileStatus = {
                    deprecated = 'Any',
                    ['unused-local'] = 'Any',
                    ['unused-function'] = 'Any',
                    ['unused-vararg'] = 'Any',
                },
                severity = {
                    ['action-after-return'] = 'Warning',
                    ['ambiguity-1'] = 'Warning',
                    ['err-assign-as-eq'] = 'Error',
                    ['err-comment-prefix'] = 'Error',
                    deprecated = 'Warning',
                    ['unicode-name'] = 'Hint',
                    ['undefined-doc-class'] = 'Warning',
                    ['undefined-field'] = 'Error',
                    ['unused-local'] = 'Hint',
                    ['unused-varar'] = 'Hint',
                },
                unusedLocalExclude = {
                    '_*',
                },
                workspaceDelay = 3000,
                workspaceEvent = 'OnChange',
                workspaceRate = 100,
            },
            doc = {
                regengine = 'lua',
            },
            format = { ---@source https://luals.github.io/wiki/settings/#format
                enable = true,
                defaultConfig = {
                    align_array_table = true,
                    align_call_args = true,
                    align_chain_expr = 'none',
                    align_continuous_assign_statement = true,
                    align_continuous_inline_comment = true,
                    align_continuous_line_space = 2,
                    align_continuous_rect_table_field = true,
                    align_continuous_similar_call_args = false,
                    align_function_params = true,
                    align_if_branch = false,
                    allow_non_indented_comments = false,
                    auto_collapse_lines = false,
                    break_all_list_when_line_exceed = false,
                    break_before_braces = false,
                    call_arg_parentheses = 'keep',
                    continuation_indent = 4,
                    detect_end_of_line = true,
                    end_of_line = 'auto',
                    end_statement_with_semicolon = 'keep',
                    ignore_space_after_colon = false,
                    ignore_spaces_inside_function_call = false,
                    indent_size = 2,
                    indent_style = 'space',
                    insert_final_newline = false,
                    keep_indents_on_empty_lines = false,
                    line_space_after_comment = 'none',
                    line_space_after_do_statement = 'none',
                    line_space_after_expression_statement = 'keep',
                    line_space_after_for_statement = 'keep',
                    line_space_after_function_statement = 'fixed(2)',
                    line_space_after_if_statement = 'keep',
                    line_space_after_local_or_assign_statement = 'keep',
                    line_space_after_repeat_statement = 'keep',
                    line_space_after_while_statement = 'keep',
                    line_space_around_block = 'fixed(1)',
                    max_line_length = 120,
                    never_indent_before_if_condition = false,
                    never_indent_comment_on_if_branch = false,
                    quote_style = 'single',
                    remove_call_expression_list_finish_comma = false,
                    space_after_comma = true,
                    space_after_comma_in_for_statement = false,
                    space_after_comment_dash = false,
                    space_around_assign_operator = false,
                    space_around_logical_operator = false,
                    space_around_math_operator = false,
                    space_around_table_append_operator = false,
                    space_around_table_field_list = false,
                    space_before_attribute = false,
                    space_before_closure_open_parenthesis = false,
                    space_before_function_call_open_parenthesis = false,
                    space_before_function_call_single_arg = 'none',
                    space_before_function_open_parenthesis = false,
                    space_before_inline_comment = 'keep',
                    space_before_open_square_bracket = false,
                    space_inside_function_call_parentheses = false,
                    space_inside_function_param_list_parentheses = false,
                    space_inside_square_brackets = false,
                    table_separator_style = 'none',
                    tab_width = 2,
                    trailing_table_separator = 'keep',
                },
            },
            hint = { ---@source https://luals.github.io/wiki/settings/#hint
                arrayIndex = 'Enable',
                await = true,
                awaitPropagate = true,
                enable = true,
                semicolon = 'All',
                setType = true,
                paramName = 'All',
                paramType = true,
                setType = true,
            },
            hover = { ---@source https://luals.github.io/wiki/settings/#hover
                enable = true,
                enumsLimit = 10,
                expandAlias = true,
                previewFields = 100,
                viewNumber = true,
                viewString = true,
                viewStringMax = 1000,
            },
            language = { ---@source https://luals.github.io/wiki/settings/#language
                completeAnnotation = true,
                fixIndent = true,
            },
            misc = { ---@source https://luals.github.io/wiki/settings/#misc
                executables = {},
                parameters = {},
            },
            runtime = {
                fileEncoding = 'utf8',
                meta = '${version} ${language} ${encoding}',
                nonstandardSymbol = {
                    '//',
                    '/**/',
                    'continue',
                },
                path = {
                    'lua/?.lua',
                    'lua/?/init.lua',
                },
                pathStrict = false,
                unicodeName = false,
                version = 'LuaJIT',
            },
            semantic = {
                annotation = true,
                enable = true,
                keyword = true,
                variable = true,
            },
            signatureHelp = {
                enable = true,
            },
            spell = { ---@source https://luals.github.io/wiki/settings/#spell
                dict = {},
            },
            --   telemetry = {
            --       enable = false,
            --   },
            type = { ---@source https://luals.github.io/wiki/settings/#type
                castNumberToInteger = false,
                checkTableShape = true,
                inferParamType = true,
                inferTableSize = 200,
                weakNilCheck = false,
                weakUnionCheck = false,
            },
            typeFormat = { ---@source https://luals.github.io/wiki/settings/#typeformat
                enable = true,
                config = {
                    auto_complete_end = 'true',
                    auto_complete_table_sep = 'true',
                    format_line = 'true',
                },
            },
            window = { ---@source https://luals.github.io/wiki/settings/#window
                progressBar = true,
                statusBar = true,
            },
            workspace = { ---@source https://luals.github.io/wiki/settings/#workspace
                checkThirdParty = 'Apply',
                ignoreDir = {
                    'build',
                    'node_modules',
                    vim.fn.expand('$XDG_DATA_HOME') .. '/nvim/runtime/**',
                    vim.fs.normalize('~/.GH/Qompass/Diver/'),
                    vim.fs.normalize('~/.GH/Qompass/Lua/'),
                    '.vscode',
                },
                ignoreSubmodules = true,
                library = {
                    vim.api.nvim_get_runtime_file('', true),
                    vim.fn.stdpath('config') .. '/lua',
                    vim.env.VIMRUNTIME,
                    '${3rd}/busted/library',
                    '${3rd}/luv/library',
                    '${3rd}/neodev.nvim/types/nightly',
                    '${3rd}/luassert/library',
                    '${3rd}/lazy.nvim/library',
                    '${3rd}/blink.cmp/library',
                },
                maxPreload = 5000,
                preloadFileSize = 500,
                useGitIgnore = true,
                userThirdParty = {},
            },
        },
    },
}
