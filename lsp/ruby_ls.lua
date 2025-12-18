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
    vim.api.nvim_buf_create_user_command(bufnr, 'ShowRubyDeps', function(opts) ---@param opts { args: string }
        local params = vim.lsp.util.make_text_document_params()
        local showAll = opts.args == 'all'
        vim.lsp.buf_request(bufnr, 'rubyLsp/workspace/dependencies', params, function(err, result)
            if err then
                vim.notify('Error showing deps: ' .. err.message, vim.log.levels.ERROR)
                return
            end
            local qf_list = {} ---@type { text: string, filename: string }[]
            for _, item in ipairs(result or {}) do
                if showAll or item.dependency then
                    table.insert(qf_list, {
                        text = string.format('%s (%s) - %s', item.name, item.version, item.dependency),
                        filename = item.path,
                    })
                end
            end
            vim.fn.setqflist(qf_list)
            vim.cmd('copen')
        end)
    end, {
        nargs = '?',
        complete = function()
            return { 'all' }
        end,
    })
end
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
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
    init_options = { ---@type table
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
