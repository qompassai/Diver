-- /qompassai/Diver/lua/config/lang/zig.lua
-- Qompass AI Diver Zig Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version 5.1, JIT
local api = vim.api
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local code_action = vim.lsp.buf.code_action
local get = vim.diagnostic.get
local jobstart = vim.fn.jobstart
local lsp = vim.lsp
local fn = vim.fn
local header = require('utils.docs.docs')
local group = augroup('Zig', {
    clear = true,
})
local uv = vim.uv
local usercmd = vim.api.nvim_create_user_command
autocmd('BufNewFile', {
    group = group,
    pattern = { '*.zig' },
    callback = function()
        local lines = api.nvim_buf_get_lines(0, 0, 1, false)
        if lines[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '//')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})
autocmd('BufWritePre', {
    group = group,
    pattern = { '*.zig', '*.zon' },
    callback = function(args)
        local diagnostics = get(args.buf)
        code_action({
            context = {
                diagnostics = diagnostics,
                only = {
                    'source.organizeImports',
                    'source.fixAll',
                },
                triggerKind = lsp.protocol.CodeActionTriggerKind.Source,
            },
            apply = true,
            filter = function(_, client_id)
                local client = lsp.get_client_by_id(client_id)
                return client ~= nil and client.name == 'z_ls'
            end,
        })
    end,
})
autocmd('BufWritePost', {
    group = group,
    pattern = '*.zig',
    callback = function(args)
        jobstart({
            'zlint',
            api.nvim_buf_get_name(args.buf),
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
usercmd('ZigTest', function()
    jobstart({ 'zig', 'test', fn.expand('%:p') }, { detach = true })
end, {})
usercmd('ZigQuickfix', function()
    local diagnostics = get(0)
    code_action({
        context = {
            diagnostics = diagnostics,
            only = { 'quickfix' },
            triggerKind = lsp.protocol.CodeActionTriggerKind.Invoked,
        },
        apply = true,
    })
end, {})
usercmd('ZigCodeAction', function()
    local diagnostics = get(0)
    code_action({
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
            local client = lsp.get_client_by_id(client_id)
            return client ~= nil and client.name == 'z_ls'
        end,
        apply = true,
    })
end, {})
usercmd('ZigRangeAction', function()
    local bufnr = 0
    local diagnostics = get(bufnr)
    local start_pos = api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = api.nvim_buf_get_mark(bufnr, '>')
    code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
                'refactor.extract',
            },
        },
        range = {
            start = { start_pos[1], start_pos[2] },
            ['end'] = { end_pos[1], end_pos[2] },
        },
        filter = function(_, client_id)
            local client = lsp.get_client_by_id(client_id)
            return client ~= nil and client.name == 'z_ls'
        end,
        apply = false,
    })
end, { range = true })

autocmd('FileType', {
    group = augroup('ziggy_schema', { clear = true }),
    pattern = 'ziggy_schema',
    callback = function()
        local cwd = uv and uv.cwd() or fn.getcwd()
        if not cwd then
            return
        end
        lsp.start({
            name = 'Ziggy LSP',
            cmd = { 'ziggy', 'lsp', '--schema' },
            root_dir = cwd,
        })
    end,
})
return M