-- /qompassai/Diver/lsp/biome_ls.lua
-- Qompass AI Diver Biome LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://biomejs.dev/editors/introduction/
---@source https://biomejs.dev/reference/configuration/

local biome_filetypes = {
    'astro',
    'cjs',
    'css',
    'graphql',
    'html',
    'javascript',
    'javascriptreact',
    'json',
    'jsonc',
    'mdx',
    'mjs',
    'spajson',
    'svelte',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
    'vue',
}
pcall(vim.api.nvim_del_augroup_by_name, 'BiomeWriteActions')
local formatters = require('formatters')
---@param bufnr integer
---@return vim.lsp.Client?
local function biome_client(bufnr)
    for _, client in
    ipairs(vim.lsp.get_clients({
        bufnr = bufnr,
    }))
    do
        if client.name == 'biome' or client.name == 'biome_ls' then
            return client
        end
    end

    return nil
end
---@param client vim.lsp.Client
---@param bufnr integer
---@param kind string
---@return boolean
local function apply_code_action(client, bufnr, kind)
    local params = {
        context = {
            diagnostics = {},
            only = {
                kind,
            },
        },
        range = {
            start = {
                character = 0,
                line = 0,
            },
            ['end'] = {
                character = 0,
                line = 0,
            },
        },
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
    }
    local response = client:request_sync('textDocument/codeAction', params, 3000, bufnr)

    if response == nil then
        return false
    end

    for _, action in ipairs(response.result or {}) do
        if action.edit ~= nil then
            vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
        end

        local command = action.command or action

        if command.command ~= nil then
            client:exec_cmd(command, {
                bufnr = bufnr,
            })
        end
    end

    return true
end

if formatters.get_stage('biome_write_actions') == nil then
    formatters.register_stage({
        desc = 'Apply Biome fix-all and organize-imports actions',
        filetypes = biome_filetypes,
        name = 'biome_write_actions',
        priority = 850,
        run = function(bufnr)
            local client = biome_client(bufnr)

            if client == nil then
                return true
            end

            apply_code_action(client, bufnr, 'source.fixAll.biome')
            apply_code_action(client, bufnr, 'source.organizeImports.biome')
            return true
        end,
    })
end
return ---@type vim.lsp.Config
{
    before_init = function(_, config)
        local fname = vim.api.nvim_buf_get_name(0)
        if fname == '' then
            return
        end

        if vim.fs.root(fname, {
                'deno.json',
                'deno.jsonc',
                'deno.lock',
            }) then
            return
        end

        local project_root = vim.fs.root(fname, {
            'biome.json',
            'biome.jsonc',
            'bun.lock',
            'bun.lockb',
            'package-lock.json',
            'pnpm-lock.yaml',
            'yarn.lock',
            '.git',
        }) or vim.fn.getcwd()
        local local_cmd = project_root .. '/node_modules/.bin/biome'
        if vim.fn.executable(local_cmd) == 1 then
            config.cmd = {
                local_cmd,
                'lsp-proxy',
            }
        end
    end,
    cmd = {
        'biome',
        'lsp-proxy',
    },
    filetypes = {
        'astro',
        'css',
        'graphql',
        'grit',
        'html',
        'javascript',
        'javascriptreact',
        'json',
        'jsonc',
        'svelte',
        'typescript',
        'typescript.tsx',
        'typescriptreact',
        'vue',
    },
    on_attach = function(client, bufnr)
        local group = vim.api.nvim_create_augroup('BiomeWriteActions', {
            clear = false,
        })
        vim.api.nvim_clear_autocmds({
            buffer = bufnr,
            group = group,
        })
        vim.api.nvim_create_autocmd('BufWritePre', {
            buffer = bufnr,
            callback = function()
                local range_params = vim.lsp.util.make_range_params(0, client.offset_encoding)
                local text_document = vim.lsp.util.make_text_document_params(bufnr)
                ---@type lsp.CodeActionParams
                local params = {
                    context = {
                        diagnostics = {},
                        only = {
                            'quickfix',
                            'source.fixAll',
                            'source.organizeImports',
                        },
                    },
                    range = range_params.range,
                    textDocument = text_document,
                }
                local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/codeAction', params, 3000)
                for _, response in pairs(responses or {}) do
                    for _, action in ipairs(response.result or {}) do
                        if action.edit then
                            vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
                        end
                        local command = action.command or action
                        if command.command then
                            client:exec_cmd(command, {
                                bufnr = bufnr,
                            })
                        end
                    end
                end
                if client.server_capabilities.documentFormattingProvider then
                    vim.lsp.buf.format({
                        async = false,
                        bufnr = bufnr,
                        filter = function(candidate)
                            return candidate.id == client.id
                        end,
                        timeout_ms = 3000,
                    })
                end
            end,
            group = group,
        })
    end,
    root_markers = {
        'biome.json',
        'biome.jsonc',
        'package.json',
        'bun.lock',
        'bun.lockb',
        'package-lock.json',
        'pnpm-lock.yaml',
        'yarn.lock',
        '.git',
    },
    settings = {
        biome = {
            configuration_path = vim.NIL,
            go_to_definition = true,
            inline_config = {
                ['$schema'] = 'https://biomejs.dev/schemas/2.5.14/schema.json',
                assist = {
                    actions = {
                        preset = 'recommended',
                        recommended = true,
                        source = {
                            noDuplicateClasses = 'on',
                            organizeImports = 'on',
                            preset = 'recommended',
                            recommended = true,
                            useSortedAttributes = 'off',
                            useSortedEnumMembers = 'off',
                            useSortedInterfaceMembers = 'off',
                            useSortedKeys = 'off',
                            useSortedPackageJson = 'off',
                            useSortedProperties = 'off',
                            useSortedSelectionSet = 'off',
                            useSortedTypeFields = 'off',
                        },
                    },
                    enabled = true,
                    includes = {
                        '**',
                    },
                },
                css = {
                    assist = {
                        enabled = true,
                    },
                    formatter = {
                        delimiterSpacing = false,
                        enabled = true,
                        indentStyle = 'space',
                        indentWidth = 2,
                        lineEnding = 'lf',
                        lineWidth = 160,
                        quoteStyle = 'double',
                        trailingNewline = true,
                    },
                    globals = {},
                    linter = {
                        enabled = true,
                    },
                    parser = {
                        allowWrongLineComments = false,
                        cssModules = false,
                        tailwindDirectives = true,
                    },
                },
                extends = {},
                files = {
                    ignoreUnknown = false,
                    includes = {
                        '**',
                        '!!**/.git',
                        '!!**/.next',
                        '!!**/build',
                        '!!**/dist',
                        '!!**/node_modules',
                        '!!**/target',
                    },
                    maxSize = 1048576,
                },
                formatter = {
                    attributePosition = 'auto',
                    bracketSameLine = false,
                    bracketSpacing = true,
                    delimiterSpacing = false,
                    enabled = true,
                    expand = 'auto',
                    formatWithErrors = true,
                    includes = {
                        '**',
                    },
                    indentStyle = 'space',
                    indentWidth = 2,
                    lineEnding = 'lf',
                    lineWidth = 160,
                    trailingNewline = true,
                    useEditorconfig = false,
                },
                graphql = {
                    assist = {
                        enabled = true,
                    },
                    formatter = {
                        bracketSpacing = true,
                        enabled = true,
                        indentStyle = 'space',
                        indentWidth = 2,
                        lineEnding = 'lf',
                        lineWidth = 160,
                        quoteStyle = 'double',
                        trailingNewline = true,
                    },
                    linter = {
                        enabled = true,
                    },
                },
                grit = {
                    assist = {
                        enabled = true,
                    },
                    formatter = {
                        enabled = true,
                        indentStyle = 'space',
                        indentWidth = 2,
                        lineEnding = 'lf',
                        lineWidth = 160,
                        trailingNewline = true,
                    },
                    linter = {
                        enabled = true,
                    },
                },
                html = {
                    assist = {
                        enabled = true,
                    },
                    experimentalFullSupportEnabled = false,
                    formatter = {
                        attributePosition = 'auto',
                        bracketSameLine = false,
                        enabled = true,
                        indentScriptAndStyle = false,
                        indentStyle = 'space',
                        indentWidth = 2,
                        lineEnding = 'lf',
                        lineWidth = 160,
                        selfCloseVoidElements = 'never',
                        trailingNewline = true,
                        whitespaceSensitivity = 'css',
                    },
                    linter = {
                        enabled = true,
                    },
                    parser = {
                        interpolation = true,
                        vue = true,
                    },
                },
                javascript = {
                    assist = {
                        enabled = true,
                    },
                    experimentalEmbeddedSnippetsEnabled = false,
                    formatter = {
                        arrowParentheses = 'always',
                        attributePosition = 'auto',
                        bracketSameLine = false,
                        bracketSpacing = true,
                        delimiterSpacing = false,
                        enabled = true,
                        expand = 'auto',
                        indentStyle = 'space',
                        indentWidth = 2,
                        jsxQuoteStyle = 'double',
                        lineEnding = 'lf',
                        lineWidth = 160,
                        operatorLinebreak = 'after',
                        quoteProperties = 'asNeeded',
                        quoteStyle = 'single',
                        semicolons = 'always',
                        trailingCommas = 'all',
                        trailingNewline = true,
                    },
                    globals = {},
                    jsxRuntime = 'transparent',
                    linter = {
                        enabled = true,
                    },
                    parser = {
                        gritMetavariables = false,
                        jsxEverywhere = true,
                        unsafeParameterDecoratorsEnabled = false,
                    },
                    resolver = {
                        experimentalPnpmCatalogs = true,
                    },
                },
                json = {
                    assist = {
                        enabled = true,
                    },
                    formatter = {
                        bracketSpacing = true,
                        delimiterSpacing = false,
                        enabled = true,
                        expand = 'auto',
                        indentStyle = 'space',
                        indentWidth = 2,
                        lineEnding = 'lf',
                        lineWidth = 160,
                        trailingCommas = 'none',
                        trailingNewline = true,
                    },
                    linter = {
                        enabled = true,
                    },
                    parser = {
                        allowComments = false,
                        allowTrailingCommas = false,
                    },
                },
                linter = {
                    domains = {
                        next = 'all',
                        test = 'all',
                    },
                    enabled = true,
                    includes = {
                        '**',
                    },
                    rules = {
                        a11y = {
                            recommended = true,
                        },
                        complexity = {
                            recommended = true,
                        },
                        correctness = {
                            noUndeclaredDependencies = 'error',
                            noUnusedImports = 'error',
                            noUnusedVariables = 'error',
                            recommended = true,
                        },
                        nursery = {
                            noFloatingPromises = 'error',
                            recommended = false,
                        },
                        performance = {
                            recommended = true,
                        },
                        preset = 'recommended',
                        security = {
                            recommended = true,
                        },
                        style = {
                            noInferrableTypes = 'error',
                            noParameterAssign = 'error',
                            noUnusedTemplateLiteral = 'error',
                            noUselessElse = 'error',
                            recommended = true,
                            useAsConstAssertion = 'error',
                            useConst = 'error',
                            useDefaultParameterLast = 'error',
                            useEnumInitializers = 'error',
                            useNumberNamespace = 'error',
                            useSelfClosingElements = 'error',
                            useSingleVarDeclarator = 'error',
                            useTemplate = 'error',
                        },
                        suspicious = {
                            noDuplicateObjectKeys = 'error',
                            noVar = 'error',
                            recommended = true,
                        },
                    },
                },
                overrides = {
                    {
                        includes = {
                            '**/*.jsonc',
                        },
                        json = {
                            formatter = {
                                trailingCommas = 'all',
                            },
                            parser = {
                                allowComments = true,
                                allowTrailingCommas = true,
                            },
                        },
                    },
                    {
                        includes = {
                            '**/*.astro',
                            '**/*.svelte',
                            '**/*.vue',
                        },
                        linter = {
                            rules = {
                                correctness = {
                                    noUnusedImports = 'off',
                                    noUnusedVariables = 'off',
                                },
                                style = {
                                    useConst = 'off',
                                    useImportType = 'off',
                                },
                            },
                        },
                    },
                    {
                        includes = {
                            '**/app.js',
                            'assets/**/*.js',
                            'public/**/*.js',
                        },
                        linter = {
                            rules = {
                                correctness = {
                                    noUnusedImports = 'error',
                                    noUnusedVariables = 'error',
                                },
                                style = {
                                    noInferrableTypes = 'off',
                                },
                            },
                        },
                    },
                },
                plugins = {},
                root = true,
                vcs = {
                    clientKind = 'git',
                    defaultBranch = 'main',
                    enabled = true,
                    root = '.',
                    useIgnoreFile = true,
                },
            },
            require_configuration = false,
        },
    },
    workspace_required = false,
}
