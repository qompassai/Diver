-- /qompassai/Diver/lua/config/ui/html.lua
-- Qompass AI Diver HTML Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
---@param opts? table
---@return cmp.ConfigSchema
function M.html_cmp(opts)
    opts = opts or {}
    local cmp = require('cmp')
    local Protocol = require('vim.lsp.protocol')
    local htmx_items = {
        {
            label = 'hx-get',
            insertText = 'hx-get="${1:url}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-post',
            insertText = 'hx-post="${1:url}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-put',
            insertText = 'hx-put="${1:url}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-delete',
            insertText = 'hx-delete="${1:url}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-trigger',
            insertText = 'hx-trigger="${1:event}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-swap',
            insertText = 'hx-swap="${1:innerHTML}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-target',
            insertText = 'hx-target="${1:selector}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-select',
            insertText = 'hx-select="${1:selector}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-confirm',
            insertText = 'hx-confirm="${1:message}"',
            kind = Protocol.CompletionItemKind.Property
        }, {
            label = 'hx-indicator',
            insertText = 'hx-indicator="${1:selector}"',
            kind = Protocol.CompletionItemKind.Property
        }
    }
    return {
        sources = cmp.config.sources({
            {name = 'luasnip'}, {name = 'nvim_lsp'}, {name = 'path'},
            {name = 'buffer', keyword_length = 3}, {name = 'codeium'},
            {name = 'html_custom', option = {items = htmx_items}}
        })
    }
end
---@param opts? table
---@return table[]
function M.html_nls(opts)
    opts = opts or {}
    local nls = require('none-ls')
    local nlsb = nls.builtins
    local utils = require('none-ls.utils')
    local prettierConfig = {
        prefer_local = 'node_modules/.bin',
        cwd = utils.root_pattern('.prettierrc', '.prettierrc.json',
                                 '.prettierrc.yml', '.prettierrc.yaml',
                                 '.prettierrc.json5', '.prettierrc.js',
                                 '.prettierrc.cjs', 'prettier.config.js',
                                 'prettier.config.cjs', 'package.json')
    }
    return {
        nlsb.formatting.prettierd.with(vim.tbl_extend('force', prettierConfig, {
            filetypes = {'html'},
            runtime_condition = function()
                return utils.executable('prettierd')
            end
        })),
        nlsb.formatting.prettier.with(vim.tbl_extend('force', prettierConfig, {
            filetypes = {'html'},
            runtime_condition = function()
                return not utils.executable('prettierd')
            end
        }))
    }
end
---@param opts? table
function M.html_lsp(opts)
    opts = opts or {}
    local lsp = require('lspconfig')
    lsp.html.setup({
        on_attach = opts.on_attach,
        capabilities = opts.capabilities,
        filetypes = {'html', 'handlebars', 'htmldjango', 'blade', 'erb', 'ejs'},
        init_options = {
            configurationSection = {'html', 'css'},
            embeddedLanguages = {css = true, javascript = true},
            provideFormatter = true
        }
    })
    lsp.emmet_ls.setup({
        on_attach = opts.on_attach,
        capabilities = opts.capabilities,
        filetypes = {
            'html', 'javascriptreact', 'typescriptreact', 'haml', 'xml', 'xsl',
            'pug', 'slim', 'erb', 'vue', 'svelte'
        }
    })
end
---@param opts? table
function M.html_preview(opts)
    opts = opts or {}
    local livepreview = require('livepreview.config')
    livepreview.set(vim.tbl_extend('force', {
        port = 8090,
        browser_cmd = 'firefox-developer-edition',
        auto_start = true,
        refresh_delay = 150,
        allowed_file_types = {'html', 'markdown', 'asciidoc', 'svg'}
    }, opts))
end
---@param opts? table
function M.html_conform(opts)
    opts = opts or {}
    return {
        formatters_by_ft = {
            html = {'prettierd'},
            htmldjango = {'prettierd'},
            blade = {'prettierd'}
        },
        format_on_save = {timeout_ms = 500, lsp_fallback = true}
    }
end
---@param opts? table
---@return table
function M.html_setup(opts)
    opts = opts or {}
    return {
        cmp = M.html_cmp(opts),
        nls = M.html_nls(opts),
        lsp = function(lsp_opts)
            M.html_lsp(vim.tbl_extend('force', opts, lsp_opts or {}))
        end,
        treesitter = M.html_treesitter(opts),
        lint = M.html_lint(opts),
        emmet = M.html_emmet(opts),
        preview = M.html_preview(opts),
        conform = M.html_conform(opts)
    }
end
return M
