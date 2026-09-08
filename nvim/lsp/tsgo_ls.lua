-- /qompassai/Diver/lsp/tsgo.lua
-- Qompass AI Typescript-Go LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- pnpm add -g  @typescript/native-preview@latest
local function path_exists(path)
    return path and vim.uv.fs_stat(path) ~= nil
end
local function is_spfx_root(root)
    if not root or root == '' then
        return false
    end
    return path_exists(root .. '/config/package-solution.json')
        or path_exists(root .. '/config/config.json')
        or path_exists(root .. '/gulpfile.js')
        or path_exists(root .. '/.yo-rc.json')
end
local function get_client_root(client)
    local root = client and client.config and client.config.root_dir or nil
    if type(root) == 'string' then
        return root
    end
    return nil
end
local function notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, {
        title = 'tsgo',
    })
end

return ---@type vim.lsp.Config
{
    cmd = {
        'tsgo',
        '--lsp',
        '--stdio',
    },
    filetypes = {
        'javascript',
        'javascript.jsx',
        'javascriptreact',
        'typescript',
        'typescriptreact',
        'typescript.tsx',
    },
    root_markers = {
        'bun.lockb',
        'bun.lock',
        'config/package-solution.json',
        'config/config.json',
        '.git',
        'gulpfile.js',
        'package.json',
        'package.jsonc',
        'package-lock.json',
        'package-lock.jsonc',
        'pnpm-lock.yaml',
        'tsconfig.json',
        'tsconfig.jsonc',
        'tsconfig.base.json',
        'tsconfig.base.jsonc',
        'jsconfig.json',
        'jsconfig.jsonc',
        'yarn.lock',
        '.yo-rc.json',
    },
    settings = {
        completions = {
            completeFunctionCalls = true,
        },
        diagnostics = {
            ignoredCodes = {},
        },
        implicitProjectConfiguration = {
            checkJs = true,
            --     experimentalDecorators = true,
            --    module = 'esnext',
            --   strictFunctionTypes = true,
            --  strictNullChecks = true,
            --  target = 'ES2020',
        },
        javascript = {
            format = {
                baseIndentSize = 0,
                convertTabsToSpaces = true,
                indentSize = 2,
                indentStyle = 'Smart',
                insertSpaceAfterCommaDelimiter = true,
                insertSpaceAfterConstructor = false,
                insertSpaceAfterFunctionKeywordForAnonymousFunctions = true,
                insertSpaceAfterKeywordsInControlFlowStatements = true,
                insertSpaceAfterOpeningAndBeforeClosingEmptyBraces = false,
                insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces = false,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = true,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
                insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces = false,
                insertSpaceAfterSemicolonInForStatements = true,
                insertSpaceAfterTypeAssertion = false,
                insertSpaceBeforeAndAfterBinaryOperators = true,
                insertSpaceBeforeFunctionParenthesis = false,
                insertSpaceBeforeTypeAnnotation = false,
                newLineCharacter = '\n',
                placeOpenBraceOnNewLineForControlBlocks = false,
                placeOpenBraceOnNewLineForFunctions = false,
                semicolons = 'insert',
                tabSize = 2,
                trimTrailingWhitespace = true,
            },
            implementationsCodeLens = {
                enabled = true,
            },
            inlayHints = {
                includeInlayEnumMemberValueHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayParameterNameHints = 'none',
                includeInlayParameterNameHintsWhenArgumentMatchesName = true,
                includeInlayPropertyDeclarationTypeHints = false,
                includeInlayVariableTypeHints = false,
                includeInlayVariableTypeHintsWhenTypeMatchesName = false,
            },
            preferences = {
                allowIncompleteCompletions = true,
                allowRenameOfImportPath = true,
                allowTextChangesInNewFiles = true,
                autoImportFileExcludePatterns = {},
                autoImportSpecifierExcludeRegexes = {},
                disableSuggestions = false,
                displayPartsForJSDoc = true,
                excludeLibrarySymbolsInNavTo = true,
                generateReturnInDocTemplate = true,
                importModuleSpecifierEnding = 'auto',
                importModuleSpecifierPreference = 'shortest',
                includeAutomaticOptionalChainCompletions = true,
                includeCompletionsForImportStatements = true,
                includeCompletionsForModuleExports = true,
                includeCompletionsWithClassMemberSnippets = true,
                includeCompletionsWithInsertText = true,
                includeCompletionsWithObjectLiteralMethodSnippets = true,
                includeCompletionsWithSnippetText = true,
                includeInlayEnumMemberValueHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayParameterNameHints = 'all',
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                includePackageJsonAutoImports = 'auto',
                interactiveInlayHints = true,
                jsxAttributeCompletionStyle = 'auto',
                lazyConfiguredProjectsFromExternalProject = false,
                maximumHoverLength = 500,
                organizeImportsAccentCollation = true,
                organizeImportsCaseFirst = false,
                organizeImportsCollation = 'ordinal',
                organizeImportsIgnoreCase = 'auto',
                organizeImportsLocale = 'en',
                organizeImportsNumericCollation = false,
                organizeImportsTypeOrder = 'last',
                preferTypeOnlyAutoImports = false,
                providePrefixAndSuffixTextForRename = true,
                provideRefactorNotApplicableReason = true,
                quotePreference = 'single',
                useLabelDetailsInCompletionEntries = true,
            },
            referencesCodeLens = {
                enabled = true,
                showOnAllFunctions = true,
            },
        },
        typescript = {
            format = {
                baseIndentSize = 0,
                convertTabsToSpaces = true,
                indentSize = 2,
                indentStyle = 'Smart',
                insertSpaceAfterCommaDelimiter = true,
                insertSpaceAfterConstructor = false,
                insertSpaceAfterFunctionKeywordForAnonymousFunctions = true,
                insertSpaceAfterKeywordsInControlFlowStatements = true,
                insertSpaceAfterOpeningAndBeforeClosingEmptyBraces = false,
                insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces = false,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = true,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
                insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces = false,
                insertSpaceAfterSemicolonInForStatements = true,
                insertSpaceAfterTypeAssertion = false,
                insertSpaceBeforeAndAfterBinaryOperators = true,
                insertSpaceBeforeFunctionParenthesis = false,
                insertSpaceBeforeTypeAnnotation = false,
                newLineCharacter = '\n',
                placeOpenBraceOnNewLineForControlBlocks = false,
                placeOpenBraceOnNewLineForFunctions = false,
                semicolons = 'insert',
                tabSize = 2,
                trimTrailingWhitespace = true,
            },
            implementationsCodeLens = {
                enabled = true,
            },
            inlayHints = {
                includeInlayEnumMemberValueHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayParameterNameHints = 'all',
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayVariableTypeHintsWhenTypeMatchesName = false,
            },
            jsxCloseTag = {
                enable = true,
                filetypes = {
                    'javascriptreact',
                    'typescriptreact',
                },
            },
            preferences = {
                allowIncompleteCompletions = true,
                allowRenameOfImportPath = true,
                allowTextChangesInNewFiles = true,
                autoImportFileExcludePatterns = {},
                autoImportSpecifierExcludeRegexes = {},
                disableSuggestions = false,
                displayPartsForJSDoc = true,
                excludeLibrarySymbolsInNavTo = true,
                generateReturnInDocTemplate = true,
                importModuleSpecifierEnding = 'auto',
                importModuleSpecifierPreference = 'shortest',
                includeAutomaticOptionalChainCompletions = true,
                includeCompletionsForImportStatements = true,
                includeCompletionsForModuleExports = true,
                includeCompletionsWithClassMemberSnippets = true,
                includeCompletionsWithInsertText = true,
                includeCompletionsWithObjectLiteralMethodSnippets = true,
                includeCompletionsWithSnippetText = true,
                includeInlayEnumMemberValueHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayParameterNameHints = 'all',
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                includePackageJsonAutoImports = 'auto',
                interactiveInlayHints = true,
                jsxAttributeCompletionStyle = 'auto',
                lazyConfiguredProjectsFromExternalProject = false,
                maximumHoverLength = 500,
                organizeImportsAccentCollation = true,
                organizeImportsCaseFirst = false,
                organizeImportsCollation = 'ordinal',
                organizeImportsIgnoreCase = 'auto',
                organizeImportsLocale = 'en',
                organizeImportsNumericCollation = false,
                organizeImportsTypeOrder = 'last',
                preferTypeOnlyAutoImports = false,
                providePrefixAndSuffixTextForRename = true,
                provideRefactorNotApplicableReason = true,
                quotePreference = 'single',
                useLabelDetailsInCompletionEntries = true,
            },
        },
    },
    handlers = {
        ['_typescript.rename'] = function(_, result, ctx)
            local Client = assert(vim.lsp.get_client_by_id(ctx.client_id))
            vim.lsp.util.show_document({
                uri = result.textDocument.uri,
                range = {
                    start = result.position,
                    ['end'] = result.position,
                },
            }, Client.offset_encoding)
            vim.lsp.buf.rename()
            return vim.NIL
        end,
    },
    commands = {
        ['editor.action.showReferences'] = function(command, ctx)
            local Client = assert(vim.lsp.get_client_by_id(ctx.client_id))
            local file_uri, position, references = unpack(command.arguments)
            local quickfix_items = vim.lsp.util.locations_to_items(references --[[@as any]], Client.offset_encoding)
            vim.fn.setqflist({}, ' ', {
                title = command.title,
                items = quickfix_items,
                context = {
                    command = command,
                    bufnr = ctx.bufnr,
                },
            })
            vim.lsp.util.show_document({
                uri = file_uri --[[@as string]],
                range = {
                    start = position --[[@as lsp.Position]],
                    ['end'] = position --[[@as lsp.Position]],
                },
            }, Client.offset_encoding)
            vim.cmd('botright copen')
        end,
    },
    on_attach = function(client, bufnr)
        local root = get_client_root(client)
        local spfx = is_spfx_root(root)
        vim.b[bufnr].qompass_tsgo_spfx = spfx
        vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptSourceAction', function()
            local cap = client.server_capabilities.codeActionProvider
            local kinds = type(cap) == 'table' and cap.codeActionKinds or {}

            local source_actions = vim.tbl_filter(function(action)
                return vim.startswith(action, 'source.')
            end, kinds or {})
            vim.lsp.buf.code_action({
                context = {
                    only = source_actions,
                    diagnostics = {},
                },
            })
        end, {
            desc = 'TypeScript source actions',
        })

        vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptGoToSourceDefinition', function()
            local win = vim.api.nvim_get_current_win()
            local params = vim.lsp.util.make_position_params(win, client.offset_encoding)

            client:exec_cmd({
                command = '_typescript.goToSourceDefinition',
                title = 'Go to source definition',
                arguments = {
                    params.textDocument.uri,
                    params.position,
                },
            }, {
                bufnr = bufnr,
            }, function(err, result)
                if err then
                    vim.notify('Go to source definition failed: ' .. err.message, vim.log.levels.ERROR)
                    return
                end
                if not result or vim.tbl_isempty(result) then
                    vim.notify('No source definition found', vim.log.levels.INFO)
                    return
                end
                vim.lsp.util.show_document(result[1], client.offset_encoding, {
                    focus = true,
                })
            end)
        end, {
            desc = 'Go to source definition',
        })
        if spfx then
            vim.api.nvim_buf_create_user_command(bufnr, 'SpfxServe', function()
                vim.cmd('terminal gulp serve')
            end, {
                desc = 'SPFx gulp serve',
            })
            vim.api.nvim_buf_create_user_command(bufnr, 'SpfxBundle', function(opts)
                local ship = opts.args == 'ship'
                vim.cmd(ship and 'terminal gulp bundle --ship' or 'terminal gulp bundle')
            end, {
                desc = 'SPFx gulp bundle [ship]',
                nargs = '?',
                complete = function()
                    return { 'ship' }
                end,
            })
            vim.api.nvim_buf_create_user_command(bufnr, 'SpfxPackage', function(opts)
                local ship = opts.args == 'ship'
                vim.cmd(ship and 'terminal gulp package-solution --ship' or 'terminal gulp package-solution')
            end, {
                desc = 'SPFx gulp package-solution [ship]',
                nargs = '?',
                complete = function()
                    return {
                        'ship',
                    }
                end,
            })
            vim.api.nvim_buf_create_user_command(bufnr, 'SpfxDoctor', function()
                local lines = {
                    'SPFx root: ' .. (root or 'unknown'),
                    'package-solution.json: ' .. tostring(path_exists((root or '') .. '/config/package-solution.json')),
                    'config.json: ' .. tostring(path_exists((root or '') .. '/config/config.json')),
                    'gulpfile.js: ' .. tostring(path_exists((root or '') .. '/gulpfile.js')),
                    '.yo-rc.json: ' .. tostring(path_exists((root or '') .. '/.yo-rc.json')),
                }
                notify(table.concat(lines, '\n'), vim.log.levels.INFO)
            end, {
                desc = 'Show SPFx detection details',
            })
        end
    end,
}
