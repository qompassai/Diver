-- /qompassai/Diver/lsp/tsc_ls.lua
-- Qompass AI TypeScript Native LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'tsc',
        '--lsp',
        '--stdio',
    },
    filetypes = {
        'javascript',
        'javascriptreact',
        'typescript',
        'typescriptreact',
    },
    root_markers = {
        '.git',
        'bun.lock',
        'bun.lockb',
        'package-lock.json',
        'pnpm-lock.yaml',
        'yarn.lock',
    },
    settings = {
        ['js/ts'] = {
            customConfigFileName = '',
            format = {
                enabled = true,
            },
            inlayHints = {
                parameterNames = {
                    enabled = 'none',
                },
            },
            organizeImports = {
                accentCollation = true,
                caseFirst = 'default',
                locale = 'en',
                numericCollation = false,
                sort = 'auto',
                typeOrder = 'auto',
                unicodeCollation = 'ordinal',
            },
            preferences = {
                autoImportEntrypointDirectorySearch = false,
                importModuleSpecifier = 'shortest',
                importModuleSpecifierEnding = 'auto',
                jsxAttributeCompletionStyle = 'auto',
                quoteStyle = 'auto',
            },
            reportStyleChecksAsWarnings = true,
            suggest = {
                autoClosingTags = {
                    enabled = true,
                },
                autoImports = true,
                includeCompletionsForImportStatements = true,
                jsdoc = {
                    enabled = true,
                    generateReturns = true,
                },
            },
            validate = {
                enabled = true,
            },
            workspaceSymbols = {
                excludeLibrarySymbols = true,
                scope = 'allOpenProjects',
            },
        },
    },
}
