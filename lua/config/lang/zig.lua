-- /qompassai/Diver/lua/config/lang/zig.lua
-- Qompass AI Diver Zig Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
local fn = vim.fn
local header = require('utils.docs')
local group = api.nvim_create_augroup('Zig', {
    clear = true,
})
api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = { '*.zig' },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '//')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})
api.nvim_create_autocmd('BufWritePre', {
    group = group,
    pattern = {
        '*.zig',
        '*.zon',
    },
    callback = function()
        vim.lsp.buf.format()
    end,
})
api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.zig',
        '*.zon',
    },
    callback = function()
        vim.lsp.buf.code_action({
            context = {
                diagnostics = {},
                only = {
                    'source.fixAll',
                },
            },
            apply = true,
        })
    end,
})
api.nvim_create_user_command('ZigTest', function()
    vim.fn.jobstart({
        'zig',
        'test',
        vim.fn.expand('%:p'),
    }, {
        detach = true,
    })
end, {})

vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = '*.zig',
    callback = function(args)
        vim.lsp.buf.format({
            bufnr = args.buf,
            async = false,
        })
    end,
})
vim.api.nvim_create_user_command('ZigQuickfix', function()
    local diagnostics = vim.diagnostic.get(0)
    vim.lsp.buf.code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
            },
            triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
        },
        apply = true,
    })
end, {})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.zig',
        '*.zon',
    },
    callback = function(args)
        local diagnostics = vim.diagnostic.get(args.buf)
        vim.lsp.buf.code_action({
            context = {
                diagnostics = diagnostics,
                only = {
                    'source.organizeImports',
                    'source.fixAll',
                },
                triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Source,
            },
            apply = true,
            filter = function(_, client_id)
                local client = vim.lsp.get_client_by_id(client_id)
                return client ~= nil and client.name == 'z_ls'
            end,
        })
    end,
})
vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.zig',
    callback = function(args)
        vim.fn.jobstart({
            'zlint',
            vim.api.nvim_buf_get_name(args.buf),
        }, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if not data then
                    return
                end
                local out = table.concat(data, '')
                if out ~= '' then
                    vim.schedule(function()
                        vim.notify('zlint: ' .. out, vim.log.levels.INFO)
                    end)
                end
            end,
        })
    end,
})
vim.api.nvim_create_user_command('ZigCodeAction', function()
    local diagnostics = vim.diagnostic.get(0)
    vim.lsp.buf.code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
                'refactor',
                'source.organizeImports',
                'source.fixAll',
            },
        },
        filter = function(_, client_id)
            local client = vim.lsp.get_client_by_id(client_id)
            return client ~= nil and client.name == 'z_ls'
        end,
        apply = true,
    })
end, {})
vim.api.nvim_create_user_command('ZigRangeAction', function()
    local bufnr = 0
    local diagnostics = vim.diagnostic.get(bufnr)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
    vim.lsp.buf.code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
                'refactor.extract',
            },
        },
        range = {
            start = {
                start_pos[1],
                start_pos[2],
            },
            ['end'] = {
                end_pos[1],
                end_pos[2],
            },
        },
        filter = function(_, client_id)
            local client = vim.lsp.get_client_by_id(client_id)
            return client ~= nil and client.name == 'z_ls'
        end,
        apply = false,
    })
end, {
    range = true,
})
api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'z_ls' then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})
vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('ziggy_schema', {}),
    pattern = 'ziggy_schema',
    callback = function()
        vim.lsp.start({
            name = 'Ziggy LSP',
            cmd = {
                'ziggy',
                'lsp',
                '--schema',
            },
            root_dir = vim.uv.cwd(),
        })
    end,
})
