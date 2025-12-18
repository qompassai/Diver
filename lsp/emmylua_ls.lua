-- /qompassai/Diver/lsp/emmylua_ls.lua
-- Qompass AI Emmyluals Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'emmylua_ls',
        '--communication',
        'stdio',
        '--log-level',
        'debug',
        '--log-path',
        '/home/phaedrus/.local/share/emmylua_ls/logs',
        '--editor',
        'neovim',
    },
    filetypes = {
        'lua',
        'luau',
    },
    root_markers = {
        '.luarc.json',
        '.emmyrc.json',
        '.luacheckrc',
        '.git',
    },
    settings = {
        Emmylua = {
            codeAction = {
                insertSpace = false,
            },
            codeLens = {
                enable = true,
            },
            completion = {
                enable = true,
                autoRequire = true,
                autoRequireFunction = 'require',
                autoRequireNamingConvention = 'keep',
                autoRequireSeparator = '.',
                callSnippet = 'Both',
                postfix = '@',
                baseFunctionIncludesName = true,
                displayContext = 4,
                keywordSnippet = 'Both',
            },
            diagnostics = {
                disable = {
                    'lowercase-global',
                    'unused-local',
                },
                enable = false,
                enables = {
                    'deprecated',
                    --'unused',
                    -- 'unused-local',
                },
                globals = {
                    'jit',
                    'require',
                    'use',
                    'vim',
                },
                severity = {
                    ['deprecated'] = 'error',
                    --['missing-return']   = 'warning',
                    -- ['undefined-field']  = 'error',
                    -- ['undefined-global'] = 'warning',
                    ['unused'] = 'hint',
                },
                unusedLocalExclude = {
                    '_*',
                },
            },
            doc = {
                syntax = 'md',
            },
            documentColor = {
                enable = true,
            },
            format = {
                defaultConfig = {
                    align_continuous_assign_statement = true,
                    indent_size = '4',
                    indent_style = 'space',
                    quote_style = 'ForceSingle',
                    trailing_table_separator = 'never',
                },
                enable = true,
            },
            hint = {
                enable = true,
                paramHint = true,
                indexHint = true,
                localHint = true,
                overrideHint = true,
                metaCallHint = true,
            },
            hover = {
                enable = true,
            },
            inlineValues = {
                enable = true,
            },
            references = {
                enable = true,
                fuzzySearch = true,
                shortStringSearch = true,
            },
            reformat = {
                externalTool = {
                    program = 'stylua',
                    args = { '-s', '-' },
                    stdin = true,
                },
                externalToolRangeFormat = nil,
                useDiff = false,
            },
            runtime = {
                frameworkVersions = {},
                requireLikeFunction = {
                    'import',
                    'load',
                    'dofile',
                },
                extensions = {
                    '.lua',
                    '.luau',
                },
                requirePattern = {
                    '?.lua',
                    '?/init.lua',
                },
                classDefaultCall = {
                    functionName = 'new',
                    forceNonColon = false,
                    forceReturnSelf = true,
                },
                nonstandardSymbol = {
                    'continue',
                },
                special = {
                    errorf = 'error',
                },
                version = 'LuaJIT',
            },
            semanticTokens = {
                enable = true,
            },
            signature = {
                detailSignatureHelper = true,
            },
            strict = {
                arrayIndex = true,
                docBaseConstMatchBaseType = true,
                metaOverrideFileDefine = true,
                requirePath = true,
                typeCall = true,
            },
            telemetry = {
                enable = false,
            },
            workspace = {
                checkThirdParty = false,
                ignoreDir = {
                    'build',
                    'node_modules',
                    'dist',
                    '.git',
                },
                ignoreGlobs = {},
                library = {
                    vim.env.VIMRUNTIME,
                    vim.fn.stdpath('config') .. '/lua',
                },
                workspaceRoots = {
                    vim.fn.stdpath('config') .. '/lua',
                },
                encoding = 'utf-8',
                moduleMap = {},
                preloadFileSize = 50000,
                reindexDuration = 50000,
                enableReindex = true,
            },
        },
    },
    workspace_required = false,
}
