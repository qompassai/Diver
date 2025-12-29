-- /qompassai/Diver/lsp/basedpy_ls.lua
-- Qompass AI Based Pyright (BasedPy) LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local function set_python_path(command) ---@param command { args: string }
    local path = command.args
    local clients = vim.lsp.get_clients({
        bufnr = vim.api.nvim_get_current_buf(),
        name = 'basedpyright',
    })
    for _, client in ipairs(clients) do
        if client.settings then
            ---@diagnostic disable-next-line:param-type-mismatch
            client.settings.python = vim.tbl_deep_extend('force', client.settings.python or {}, {
                pythonPath = path,
            })
        else
            client.config.settings = vim.tbl_deep_extend('force', client.config.settings or {}, {
                python = {
                    pythonPath = path,
                },
            })
        end
        client:notify('workspace/didChangeConfiguration', {
            settings = nil,
        })
    end
end
return ---@type vim.lsp.Config
{
    cmd = {
        'basedpyright-langserver',
        '--stdio',
    },
    filetypes = {
        'python',
    },
    root_markers = {
        '.git',
        'pyproject.toml',
        'setup.py',
        'setup.cfg',
        'requirements.txt',
        'Pipfile',
        'pyrightconfig.json',
        '.pyrightconfig.json',
        'pyrightconfig.jsonc',
        '.pyrightconfig.jsonc',
    },
    settings = {
        basedpyright = {
            analysis = {
                autoFormatStrings = true,
                autoImportCompletions = true,
                autoSearchPaths = true,
                diagnosticMode = 'openFilesOnly',
                diagnosticSeverityOverrides = {},
                executionEnvironments = {
                    {
                        extraPaths = {
                            'src',
                        },
                        pythonVersion = '3.13',
                        pythonPlatform = 'Linux',
                        reportPrivateUsage = 'warning',
                        reportMissingTypeStubs = 'warning',
                        root = 'src',
                    },
                    {
                        root = 'tests',
                        pythonVersion = '3.13',
                        pythonPlatform = 'Linux',
                        extraPaths = {
                            'src',
                            'tests/e2e',
                        },
                        reportUnusedVariable = 'none',
                        reportUnusedFunction = 'none',
                        reportUnnecessaryCast = 'none',
                    },
                    {
                        root = 'scripts',
                        pythonVersion = '3.13',
                        pythonPlatform = 'Linux',
                        extraPaths = {
                            'src',
                        },
                    },
                    {
                        root = '.',
                    },
                },
                fileEnumerationTimeout = 10,
                inlayHints = {
                    callArgumentNames = true,
                    callArgumentNamesMatching = true,
                    functionReturnTypes = true,
                    genericTypes = true,
                    variableTypes = true,
                },
                logLevel = 'Information',
                reportAbstractUsage = 'error',
                reportAny = 'error',
                reportArgumentType = 'error',
                reportAssertAlwaysTrue = 'warning',
                reportAssertTypeFailure = 'error',
                reportAssignmentType = 'error',
                reportCallInDefaultInitializer = 'warning',
                reportCallIssue = 'error',
                reportConstantRedefinition = 'warning',
                reportDeprecated = 'warning',
                reportDuplicateImport = 'warning',
                reportGeneralTypeIssues = 'error',
                reportIgnoreCommentWithoutRule = 'warning',
                reportImplicitAbstractClass = 'warning',
                reportImplicitRelativeImport = 'error',
                reportImportCycles = 'information',
                reportIncompleteStub = 'information',
                reportIncompatibleMethodOverride = 'error',
                reportIncompatibleVariableOverride = 'error',
                reportInconsistentConstructor = 'error',
                reportInconsistentOverload = 'error',
                reportIndexIssue = 'error',
                reportInvalidCast = 'error',
                reportInvalidStringEscapeSequence = 'warning',
                reportInvalidStubStatement = 'warning',
                reportInvalidTypeArguments = 'error',
                reportInvalidTypeForm = 'error',
                reportInvalidTypeVarUse = 'error',
                reportMatchNotExhaustive = 'warning',
                reportMissingImports = 'none',
                reportMissingModuleSource = 'none',
                reportMissingParameterType = 'warning',
                reportMissingSuperCall = 'warning',
                reportMissingTypeArgument = 'warning',
                reportMissingTypeStubs = 'warning',
                reportNoOverloadImplementation = 'error',
                reportOperatorIssue = 'error',
                reportOptionalCall = 'error',
                reportOptionalContextManager = 'error',
                reportOptionalIterable = 'error',
                reportOptionalMemberAccess = 'error',
                reportOptionalOperand = 'error',
                reportOptionalSubscript = 'error',
                reportOverlappingOverload = 'error',
                reportPossiblyUnboundVariable = 'error',
                reportPrivateImportUsage = 'warning',
                reportPrivateLocalImportUsage = 'warning',
                reportPrivateUsage = 'warning',
                reportRedeclaration = 'error',
                reportReturnType = 'error',
                reportSelfClsParameterName = 'warning',
                reportShadowedImports = 'warning',
                reportTypedDictNotRequiredAccess = 'warning',
                reportTypeCommentUsage = 'warning',
                reportUnannotatedClassAttribute = 'warning',
                reportUndefinedVariable = 'error',
                reportUnboundVariable = 'error',
                reportUnhashable = 'error',
                reportUninitializedInstanceVariable = 'warning',
                reportUnknownArgumentType = 'warning',
                reportUnknownLambdaType = 'warning',
                reportUnknownMemberType = 'warning',
                reportUnknownParameterType = 'warning',
                reportUnknownVariableType = 'warning',
                reportUnnecessaryCast = 'information',
                reportUnnecessaryComparison = 'information',
                reportUnnecessaryContains = 'information',
                reportUnnecessaryIsInstance = 'information',
                reportUnnecessaryTypeIgnoreComment = 'information',
                reportUnreachable = 'error',
                reportUnsafeMultipleInheritance = 'warning',
                reportUnsupportedDunderAll = 'warning',
                reportUntypedBaseClass = 'warning',
                reportUntypedClassDecorator = 'warning',
                reportUntypedFunctionDecorator = 'warning',
                reportUntypedNamedTuple = 'warning',
                reportUnusedCallResult = 'warning',
                reportUnusedClass = 'warning',
                reportUnusedCoroutine = 'warning',
                reportUnusedExcept = 'information',
                reportUnusedExpression = 'information',
                reportUnusedFunction = 'warning',
                reportUnusedImport = 'warning',
                reportUnusedParameter = 'warning',
                reportUnusedVariable = 'warning',
                stubPath = 'typings',
                typeCheckingMode = 'standard',
                typeshedPaths = {
                    '/usr/lib/python3.13/site-packages',
                },
                useLibraryCodeForTypes = true,
                useTypingExtensions = true,
            },
            -- configFilePath = vim.fn.getcwd(),
            disableLanguageServices = false,
            disableOrganizeImports = false,
            disableTaggedHints = false,
            failOnWarnings = false,
            python = {
                pythonPath = '/usr/bin/python3.13',
            },
        },
    },
    on_attach = function(client, bufnr)
        vim.api.nvim_buf_create_user_command(bufnr, 'BasedPyReanalyze', function()
            client:notify('workspace/didChangeConfiguration', {
                settings = client.config.settings,
            })
        end, {
            desc = 'Force basedpyright to re-read configuration',
        })
        vim.api.nvim_buf_create_user_command(bufnr, 'LspPyrightOrganizeImports', function()
            local params = {
                command = 'basedpyright.organizeimports',
                arguments = {
                    vim.uri_from_bufnr(bufnr),
                },
            }
            client:request('workspace/executeCommand', params, nil, bufnr)
        end, {
            desc = 'Organize Imports',
        })
        vim.api.nvim_buf_create_user_command(bufnr, 'LspPyrightSetPythonPath', set_python_path, {
            desc = 'Reconfigure basedpyright python path',
            nargs = 1,
            complete = 'file',
        })
        if client:supports_method('textDocument/formatting') then
            vim.api.nvim_create_autocmd('BufWritePre', {
                buffer = bufnr,
                callback = function()
                    vim.lsp.buf.format({
                        bufnr = bufnr,
                        filter = function(c)
                            return c.name == 'basedpyright'
                        end,
                    })
                end,
            })
        end
    end,
}
