-- qompassai/Diver/lua/config/cicd/build.lua
-- Qompass AI Diver CICD JSON Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.json_autocmds()
    vim.api.nvim_create_autocmd({'TextChanged', 'InsertLeave'}, {
        pattern = {'*.json', '*.jsonc', '*.json5', '*.jsonl'},
        callback = function()
            if vim.b.lsp_attached then
                vim.lsp.buf.document_highlight()
                vim.diagnostic.reset()
                local client = vim.lsp.get_active_clients({bufnr = 0})[1]
                if client and
                    client.supports_method('textDocument/semanticTokens/full') then
                    pcall(vim.lsp.buf.semantic_tokens_refresh)
                end
            end
        end
    })
end
function M.json_completion(opts)
    local sources = opts.sources or {}
    local has_json_source = vim.tbl_contains(
                                vim.tbl_map(function(s)
            return s.name == 'json'
        end, sources), true)
    if not has_json_source then
        table.insert(sources, {
            name = 'lsp',
            group_index = 1,
            priority = 100,
            filetypes = {'json', 'jsonc', 'json5', 'jsonl'},
            entry_filter = function(entry, ctx)
                local ft = vim.bo[ctx.bufnr].filetype
                return vim.tbl_contains({'json', 'jsonc', 'json5', 'jsonl'}, ft)
            end
        })
    end
    opts.sources = sources
    return opts
end
function M.json_conform(opts)
    opts.formatters_by_ft = vim.tbl_deep_extend('force',
                                                opts.formatters_by_ft or {}, {
        json = {'prettierd', 'jq'},
        jsonc = {'prettierd'},
        json5 = {'prettierd'},
        jsonl = {'jq'}
    })
    opts.formatters = vim.tbl_deep_extend('force', opts.formatters or {}, {
        prettierd = {prepend_args = {'--parser', 'json'}},
        jq = {args = {'--indent', '2'}}
    })
    return opts
end
function M.json_lsp(opts)
    if not opts.servers then opts.servers = {} end
    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    opts.servers.jsonls = {
        capabilities = capabilities,
        filetypes = {'json', 'jsonc', 'json5', 'jsonl'},
        settings = {
            json = {
                schemas = require('schemastore').json.schemas({
                    select = {
                        'package.json', 'tsconfig.json', 'jsconfig.json',
                        '.eslintrc', 'composer.json', 'babelrc.json',
                        'lerna.json', 'GitHub Action', 'AWS CloudFormation'
                    }
                }),
                validate = {enable = true},
                format = {enable = true}
            }
        }
    }
    return opts
end
function M.json_filetype_detection()
    vim.filetype.add({
        extension = {
            json = 'json',
            jsonc = 'jsonc',
            json5 = 'json5',
            jsonl = 'jsonl'
        },
        pattern = {
            ['%.json5$'] = 'json5',
            ['%.jsonl$'] = 'jsonl',
            ['%.jsonc$'] = 'jsonc',
            ['tsconfig.*%.json'] = 'jsonc',
            ['.*rc%.json'] = 'jsonc'
        },
        filename = {
            ['.eslintrc.json'] = 'jsonc',
            ['.babelrc'] = 'jsonc',
            ['.prettierrc'] = 'jsonc',
            ['tsconfig.json'] = 'jsonc',
            ['package.json'] = 'json'
        }
    })
end

function M.json_keymaps(opts)
    opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
        ['<leader>cj'] = {name = '+json'},
        ['<leader>cjf'] = {'<cmd>Format<cr>', 'Format JSON'},
        ['<leader>cjv'] = {
            '<cmd>lua vim.lsp.buf.code_action()<cr>', 'Validate JSON'
        },
        ['<leader>cjs'] = {'<cmd>Telescope schemastore<cr>', 'Schema Store'}
    })
    return opts
end
return M
