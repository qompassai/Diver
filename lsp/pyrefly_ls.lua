-- /qompassai/Diver/lsp/pyrefly_ls.lua
-- Qompass AI Pyrefly LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'pyrefly',
        'lsp',
    },
    filetypes = {
        'python',
    },
    on_attach = require('config.core.lsp').on_attach,
    pythonPath = '/usr/bin/python3',
    root_markers = {
        '.git',
        'mypy.ini',
        'pyproject.toml',
        'pyrefly.toml',
        'requirements.txt',
        'setup.cfg',
        'setup.py',
    },
    settings = {
        pyrefly = {
            displayTypeErrors = 'force-on',
            disableLanguageServices = false,
            extraPaths = {},
            analysis = {
                diagnosticMode = 'workspace',
                importFormat = 'absolute',
                inlayHints = {
                    callArgumentNames = 'off',
                    functionReturnTypes = true,
                    pytestParameters = true,
                    variableTypes = true,
                },
                showHoverGoToLinks = true,
            },
            disabledLanguageServices = {
                codeAction = false,
                completion = false,
                definition = false,
                declaration = false,
                documentHighlight = false,
                documentSymbol = false,
                hover = false,
                implementation = false,
                inlayHint = false,
                references = false,
                rename = false,
                semanticTokens = false,
                signatureHelp = false,
                typeDefinition = false,
            },
        },
    },

    on_exit = function(code, _, _)
        vim.echo('Closing Pyrefly LSP exited with code: ' .. code, vim.log.levels.INFO)
    end,
}