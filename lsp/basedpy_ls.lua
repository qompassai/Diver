-- #################################################################
-- /qompassai/Diver/lsp/basedpy_ls.lua
-- Qompass AI Diver Native BasedPyright LSP Config
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################
---@source https://docs.basedpyright.com/latest/configuration/language-server-settings/
local api = vim.api

local function default_python_path()
    local candidates = vim.fn.has('win32') == 1
            and {
                'python.exe',
                'python3.exe',
                'py.exe',
            }
        or {
            'python3',
            'python',
        }
    for _, name in ipairs(candidates) do
        local path = vim.fn.exepath(name)
        if path ~= '' then
            return path
        end
    end
    return 'python3'
end

---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach(client, bufnr)
    require('config.core.lsp').on_attach(client, bufnr)

    api.nvim_buf_create_user_command(bufnr, 'BasedPyReanalyze', function()
        if client:is_stopped() then
            return
        end
        client:notify('workspace/didChangeConfiguration', {
            settings = client.settings,
        })
    end, {
        desc = 'Ask BasedPyright to reload settings and reanalyze',
        force = true,
    })

    api.nvim_buf_create_user_command(bufnr, 'LspPyrightSetPythonPath', function(command)
        if client:is_stopped() then
            vim.notify('BasedPyright is no longer attached', vim.log.levels.WARN)
            return
        end
        local candidate = vim.fn.expand(command.args)
        if vim.fn.executable(candidate) ~= 1 then
            vim.notify('Python executable not found: ' .. candidate, vim.log.levels.ERROR)
            return
        end
        local path = vim.fn.exepath(candidate)
        if path == '' then
            vim.notify('Cannot resolve Python executable', vim.log.levels.ERROR)
            return
        end
        local settings = vim.tbl_deep_extend('force', client.settings or {}, {
            python = { pythonPath = path },
        })
        client.settings = settings
        client.config.settings = settings
        client:notify('workspace/didChangeConfiguration', {
            settings = settings,
        })
    end, {
        desc = 'Set Python interpreter for this BasedPyright workspace',
        nargs = 1,
        complete = 'file',
        force = true,
    })
end

---@type vim.lsp.Config
return {
    cmd = {
        'basedpyright-langserver',
        '--stdio',
    },
    filetypes = {
        'python',
    },
    root_markers = {
        'pyrightconfig.json',
        'pyproject.toml',
        'setup.py',
        'setup.cfg',
        'requirements.txt',
        'Pipfile',
        '.git',
    },
    settings = {
        python = {
            pythonPath = default_python_path(),
        },
        basedpyright = {
            disableLanguageServices = false,
            disableOrganizeImports = true,
            disableTaggedHints = false,
            analysis = {
                autoFormatStrings = true,
                autoImportCompletions = true,
                autoSearchPaths = true,
                diagnosticMode = 'openFilesOnly',
                diagnosticSeverityOverrides = {
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
                    reportIncompatibleMethodOverride = 'error',
                    reportIncompatibleVariableOverride = 'error',
                    reportIncompleteStub = 'information',
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
                    reportTypeCommentUsage = 'warning',
                    reportTypedDictNotRequiredAccess = 'warning',
                    reportUnannotatedClassAttribute = 'warning',
                    reportUnboundVariable = 'error',
                    reportUndefinedVariable = 'error',
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
                stubPath = 'typings',
                typeCheckingMode = 'standard',
                useLibraryCodeForTypes = true,
                useTypingExtensions = true,
            },
        },
    },
    on_attach = on_attach,
}
