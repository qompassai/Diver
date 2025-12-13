-- /qompassai/Diver/lsp/ruby-lsp.lua
-- Qompass AI Ruby LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['ruby-lsp'] = {
    cmd = { 'ruby-lsp' },
    filetypes = { 'ruby', 'eruby' },
    root_markers = { 'Gemfile', '.git' },
    init_options = {
        enabledFeatures = {
            codeActions = true,
            codeLens = true,
            completion = true,
            definition = true,
            diagnostics = true,
            documentHighlights = true,
            documentLink = true,
            documentSymbols = true,
            foldingRanges = true,
            formatting = true,
            hover = true,
            inlayHint = true,
            onTypeFormatting = true,
            selectionRanges = true,
            semanticHighlighting = true,
            signatureHelp = true,
            typeHierarchy = true,
            workspaceSymbol = true,
        },
        featuresConfiguration = {
            inlayHint = {
                implicitHashValue = true,
                implicitRescue = true,
            },
            indexing = {
                excludedPatterns = {
                    'log/**',
                    'tmp/**',
                    'vendor/**',
                    'node_modules/**',
                    'public/**',
                },
                includedPatterns = {
                    'app/**',
                    'config/**',
                    'lib/**',
                    'test/**',
                    'spec/**',
                },
                excludedGems = {
                    'bootsnap',
                    'sass-rails',
                },
                excludedMagicComments = {
                    'frozen_string_literal:true',
                },
                formatter = 'auto',
                linters = {},
                experimentalFeaturesEnabled = false,
            },
            addonSettings = {
                ['Ruby LSP Rails'] = {
                    enablePendingMigrationsPrompt = false,
                },
            },
        },
    },
}
