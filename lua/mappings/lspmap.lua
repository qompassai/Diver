-- /qompassai/Diver/lua/mappings/lspmap.lua
-- Qompass AI Diver Language Server Protocol (LSP) Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.lspmap'
local M = {}
local api = vim.api
M.rust_editions = {
    ['2021'] = '2021',
    ['2024'] = '2024',
}
M.rust_toolchains = {
    stable = 'stable',
    nightly = 'nightly',
    beta = 'beta',
}
M.rust_default_edition = '2024'
M.rust_default_toolchain = 'nightly'
M.current_edition = M.rust_default_edition
M.current_toolchain = M.rust_default_toolchain
function M.rust_edition(edition)
    if M.rust_editions[edition] then
        M.current_edition = edition
        vim.echo('Rust edition set to ' .. edition, vim.log.levels.INFO)
        vim.cmd('LspRestart')
    else
        vim.echo('Invalid Rust edition: ' .. tostring(edition), vim.log.levels.ERROR)
    end
end

function M.rust_set_toolchain(tc)
    if M.rust_toolchains[tc] then
        M.current_toolchain = tc
        vim.echo('Rust toolchain set to ' .. tc, vim.log.levels.INFO)
        vim.cmd('LspRestart')
    else
        vim.echo('Invalid Rust toolchain: ' .. tostring(tc), vim.log.levels.ERROR)
    end
end
---@alias LspAttachArgs { buf: integer, data: { client_id: integer } }
function M.setup_lspmap() ---@return nil
    local function on_list(options) ---@param options table
        vim.fn.setqflist({}, ' ', options)
        vim.cmd.cfirst()
    end
    function M.on_attach(args) ---@param args LspAttachArgs
        local bufnr = args.buf ---@type integer
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local clients = vim.lsp.get_clients({ bufnr = bufnr }) ---@type vim.lsp.Client[]
        local map = vim.keymap.set
        local opts = {
            buffer = bufnr,
            silent = true,
        }
        map(
            'n',
            'ca',
            vim.lsp.buf.code_action,
            vim.tbl_extend('force', opts, {
                desc = 'Code actions',
            })
        )
        map('n', 'gd', function()
            for _, c in ipairs(clients) do
                if c:supports_method('textDocument/definition') then
                    vim.lsp.buf.definition({
                        loclist = true,
                        on_list = on_list,
                    })
                    return
                end
            end
            vim.echo('No LSP supports textDocument/definition for this buffer', vim.log.levels.WARN)
        end, {
            buffer = bufnr,
            silent = true,
        })
        if vim.lsp.buf.document_color then
            map('n', '<leader>lc', vim.lsp.buf.document_color, {
                buffer = bufnr,
                silent = true,
                desc = 'LSP document color',
            })
        end
        map(
            'n',
            'gs',
            vim.lsp.buf.document_symbol,
            vim.tbl_extend('force', opts, {
                desc = 'Show document symbols',
            })
        )
        map(
            'n',
            'f',
            function()
                if #clients > 0 then
                    vim.lsp.buf.format({
                        async = true,
                        bufnr = bufnr,
                    })
                else
                    vim.echo('No active LSP client with formatting support.', vim.log.levels.WARN)
                end
            end,
            vim.tbl_extend('force', opts, {
                desc = 'Format buffer (LSP if available)',
            })
        )
        map(
            'n',
            'K',
            vim.lsp.buf.hover,
            vim.tbl_extend('force', opts, {
                desc = 'Show hover information',
            })
        )
        map(
            'n',
            'gI',
            vim.lsp.buf.implementation,
            vim.tbl_extend('force', opts, {
                desc = 'Go to implementation',
            })
        )
        map(
            'n',
            '<leader>rn',
            vim.lsp.buf.rename,
            vim.tbl_extend('force', opts, {
                desc = 'Rename symbol',
            })
        )
        map(
            'n',
            '<leader>sr',
            vim.lsp.buf.references,
            vim.tbl_extend('force', opts, {
                desc = ' [s]earch [r]eferences',
            })
        )
        map(
            'n',
            'gw',
            vim.lsp.buf.workspace_symbol,
            vim.tbl_extend('force', opts, {
                desc = 'Show workspace symbols',
            })
        )
        map(
            'n',
            '[d',
            function()
                vim.diagnostic.jump({
                    count = -1,
                })
            end,
            vim.tbl_extend('force', opts, {
                desc = 'Previous diagnostic',
            })
        )
        map(
            'n',
            ']d',
            function()
                vim.diagnostic.jump({
                    count = 1,
                })
            end,
            vim.tbl_extend('force', opts, {
                desc = 'Next diagnostic',
            })
        )
        map(
            'n',
            '<leader>fD',
            function()
                vim.diagnostic.open_float(nil, {
                    scope = 'line',
                })
            end,
            vim.tbl_extend('force', opts, {
                desc = 'Show line diagnostics',
            })
        )
        map('n', '<leader>li', vim.cmd.LspInfo, {
            buffer = bufnr,
            silent = true,
            desc = 'Show LSP info',
        })
        if client and client:supports_method('textDocument/signatureHelp') and vim.lsp.buf.signature_help then
            map(
                'i',
                '<C-k>',
                vim.lsp.buf.signature_help,
                vim.tbl_extend('force', opts, {
                    desc = 'Show signature help',
                })
            )
        end
        map('i', '<C-Space>', function()
            if vim.lsp.completion and vim.lsp.completion.get then
                vim.lsp.completion.get()
                return ''
            end
            return vim.api.nvim_replace_termcodes('<C-x><C-o>', true, false, true)
        end, {
            buffer = bufnr,
            expr = true,
            desc = 'Trigger LSP completion',
        })
        map('i', '<Tab>', function()
            if vim.lsp.inline_completion and vim.lsp.inline_completion.get then
                if not vim.lsp.inline_completion.get() then
                    return '<Tab>'
                end
                return ''
            end
            return '<Tab>'
        end, {
            expr = true,
            desc = 'Accept the current inline completion',
        })
        if vim.bo[bufnr].filetype == 'typescript' or vim.bo[bufnr].filetype == 'typescriptreact' then
            map('n', '<leader>ct', '<Nop>', {
                buffer = bufnr,
                silent = true,
                desc = '+TypeScript',
            })
            map(
                'n',
                '<leader>naw',
                vim.lsp.buf.add_workspace_folder,
                vim.tbl_extend('force', opts, {
                    desc = '[n]vim-LSP [a]dd [w]orkspace folder',
                }) --- In normal mode, press 'Space' + 'n'+ 'w' + 'a' to add the current folder as a workspace.
            )

            map(
                'n',
                '<leader>nrw',
                vim.lsp.buf.remove_workspace_folder,
                vim.tbl_extend('force', opts, {
                    desc = '[n]vim-LSP [r]emove [w]orkspace folder',
                }) --- In normal mode, press 'Space' + 'w' + 'r' to remove the current folder workspace.
            )
            map(
                'n',
                '<leader>nlw',
                function()
                    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                end,
                vim.tbl_extend('force', opts, {
                    desc = '[n]vim-LSP [l]ist [w]orkspace folders',
                }) --- In normal mode, press 'Space' + 'w' + 'l' to list all folders currently in the workspace.
            )
            map(
                'n',
                '<leader>cta',
                vim.lsp.buf.code_action,
                vim.tbl_extend('force', opts, {
                    desc = 'TypeScript code actions',
                })
            )
            map(
                'n',
                '<leader>ctr',
                vim.lsp.buf.rename,
                vim.tbl_extend('force', opts, {
                    desc = 'TypeScript rename symbol',
                })
            )
            map(
                'n',
                '<leader>cti',
                '<cmd>TypescriptOrganizeImports<cr>',
                vim.tbl_extend('force', opts, {
                    desc = 'TypeScript organize imports',
                })
            )
            map(
                'n',
                '<leader>ctd',
                '<cmd>TypescriptGoToSourceDefinition<cr>',
                vim.tbl_extend('force', opts, {
                    desc = 'TypeScript go to source definition',
                })
            )
            map(
                'n',
                '<leader>ctt',
                '<cmd>TypescriptAddMissingImports<cr>',
                vim.tbl_extend('force', opts, {
                    desc = 'TypeScript add missing imports',
                })
            )
            local ok, _ = pcall(require, 'telescope.builtin')
            if ok then
                map(
                    'n',
                    '<leader>cts',
                    '<cmd>lua require(\'telescope.builtin\').lsp_document_symbols()<cr>',
                    vim.tbl_extend('force', opts, {
                        desc = 'TypeScript document symbols (Telescope)',
                    })
                )
  api.nvim_create_user_command('RustEdition', function(o)
        M.rust_edition(o.args)
    end, {
        nargs = 1,
        complete = function()
            return vim.tbl_keys(M.rust_editions)
        end,
    })
    api.nvim_create_user_command('RustToolchain', function(o)
        M.rust_set_toolchain(o.args)
    end, {
        nargs = 1,
        complete = function()
            return vim.tbl_keys(M.rust_toolchains)
        end,
    })
                map('n', '<leader>re', function()
                    vim.ui.select(vim.tbl_keys(M.rust_editions), {
                        prompt = 'Select Rust edition',
                    }, M.rust_edition)
                end, {
                    desc = 'Rust: select edition',
                })

                map('n', '<leader>rt', function()
                    vim.ui.select(vim.tbl_keys(M.rust_toolchains), {
                        prompt = 'Select Rust toolchain',
                    }, M.rust_set_toolchain)
                end, {
                    desc = 'Rust: select toolchain',
                })
            end
        end
    end
end

return M
--]]
--[[local registry = require('mason-registry')

function M.setup_masonmap()
    ---@return table<string, string[]>
    function M.get_language_map()
        if not registry.get_all_package_specs then
            return {}
        end
        ---@type table<string, string[]>
        local languages = {}
        for _, pkg_spec in ipairs(registry.get_all_package_specs()) do
            for _, language in ipairs(pkg_spec.languages) do
                language = language:lower()
                if not languages[language] then
                    languages[language] = {}
                end
                table.insert(languages[language], pkg_spec.name)
            end
        end
        return languages
    end
end
--]]