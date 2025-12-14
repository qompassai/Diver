-- /qompassai/Diver/lsp/emmylua_ls.lua
-- Qompass AI Emmyluals Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
for _, client in ipairs(vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })) do
    if client.name == 'emmylua_ls' then
        return
    end
end
vim.lsp.config['emmylua_ls'] = {
    cmd = {
        'emmylua_ls',
    },
    filetypes = {
        'lua',
        'luau',
    },
    root_markers = {
        '.emmylua.json',
        '.emmyrc.json',
        '.luarc.json',
        '.luarc.json',
        '.luacheckrc',
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
                enable = true,
                globals = {
                    'jit',
                    'require',
                    'use',
                    'vim',
                },
                severity = {
                    ['deprecated'] = 'Error',
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
                shortStringSearch = false,
            },
            reformat = {
                externalTool = nil,
                externalToolRangeFormat = nil,
                useDiff = false,
            },
            runtime = {
                version = 'LuaJIT',
                requireLikeFunction = {
                    'import',
                    'load',
                    'dofile',
                },
                frameworkVersions = {},
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
            },
            semanticTokens = {
                enable = true,
            },
            signature = {
                detailSignatureHelper = true,
            },
            strict = {
                requirePath = false,
                typeCall = false,
                arrayIndex = true,
                metaOverrideFileDefine = true,
                docBaseConstMatchBaseType = true,
            },
            telemetry = {
                enable = false,
            },
            workspace = {
                ignoreDir = {
                    'build',
                    'node_modules',
                    'dist',
                },
                ignoreGlobs = {},
                library = {
                    vim.api.nvim_get_runtime_file('', true),
                    vim.env.VIMRUNTIME,
                    '${3rd}/busted/library',
                    '${3rd}/luv/library',
                    '${3rd}/luassert/library',
                    '${3rd}/lazy.nvim/library',
                    '${3rd}/neodev.nvim/types/nightly',
                    '${3rd}/blink.cmp/library',
                    vim.fn.expand('$HOME') .. '/.config/nvim/lua/',
                },
                workspaceRoots = {},
                encoding = 'utf-8',
                moduleMap = {},
                preloadFileSize = 10000,
                reindexDuration = 5000,
                enableReindex = false,
            },
        },
    },
    on_attach = function(client, bufnr)
        client.server_capabilities.documentFormattingProvider = false
    end,
}
