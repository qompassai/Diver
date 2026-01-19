-- /qompassai/Diver/lsp/ruby-lsp.lua
-- Qompass AI Diver Ruby LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@param client vim.lsp.Client
local function add_ruby_deps_command(client, bufnr) ---@param bufnr integer
    local enabled = client.config and client.config.init_options and client.config.init_options.enabledFeatures
    if not enabled then
        return
    end
    vim.api.nvim_buf_create_user_command(bufnr, 'RubyLspDeps', function()
        print('Ruby LSP deps for buffer ' .. bufnr)
    end, {
        desc = 'Show Ruby LSP dependencies',
    })
end
return ---@type vim.lsp.Config
{
    cmd = {
        'ruby-lsp',
    },
    filetypes = { ---@type string[]
        'ruby',
        'eruby',
    },
    root_markers = { ---@type string[]
        'Gemfile',
        '.git',
    },
    init_options = { ---@type table[]
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
        },
        indexing = {
            excludedPatterns = { ---@type string[]
                'log/**',
                'tmp/**',
                'vendor/**',
                'node_modules/**',
                'public/**',
            },
            includedPatterns = { ---@type string[]
                'app/**',
                'config/**',
                'lib/**',
                'test/**',
                'spec/**',
            },
            excludedGems = { ---@type string[]
                'bootsnap',
                'sass-rails',
            },
            excludedMagicComments = { ---@type string[]
                'frozen_string_literal:true',
                'compiled:true',
            },
            formatter = 'auto', ---@type string
            linters = { ---@type string[]
                'rubocop',
            },
            experimentalFeaturesEnabled = true, ---@type boolean
        },
        addonSettings = {
            ['Ruby LSP Rails'] = {
                enablePendingMigrationsPrompt = true, ---@type boolean
            },
        },
    },
    ---@param client vim.lsp.Client
    on_attach = function(client, bufnr) ---@param bufnr integer
        add_ruby_deps_command(client, bufnr)
    end,
}
