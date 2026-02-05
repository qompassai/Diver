#!/usr/bin/env lua
-- /qompassai/Diver/lua/config/lang/kotlin.lua
-- Qompass AI Diver Kotlin Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local api = vim.api
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local client_by_id = vim.lsp.get_client_by_id
local code_action = vim.lsp.buf.code_action
local findfile = vim.fn.findfile
local ERROR = vim.log.levels.ERROR
local get = vim.diagnostic.get
local INFO = vim.log.levels.INFO
local jobstart = vim.fn.jobstart
local lsp = vim.lsp
local notify = vim.notify
local schedule = vim.schedule
local fn = vim.fn
local header = require('utils.docs.docs')
local group = augroup('Kotlin', {
    clear = true,
})
local usercmd = vim.api.nvim_create_user_command
autocmd('BufNewFile', {
    group = group,
    pattern = { '*.kt', '*.kts' },
    callback = function()
        local lines = api.nvim_buf_get_lines(0, 0, 1, false) ---@type string[]
        if lines[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p') ---@type string
        local hdr = header.make_header(filepath, '//')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})

autocmd('BufWritePre', {
    group = group,
    pattern = {
        '*.kt',
        '*.kts',
    },
    callback = function(args) ---@param args {buf: integer, file: string, match: string}
        lsp.buf.format({
            bufnr = args.buf,
            async = false,
        })
    end,
})

autocmd('BufWritePre', {
    group = group,
    pattern = {
        '*.kt',
        '*.kts',
    },
    callback = function()
        code_action({
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

usercmd('KotlinTest', function()
    local gradle_file = findfile('build.gradle.kts', '.;')
    if gradle_file ~= '' then
        jobstart({
            'gradle',
            'test',
            '--tests',
            fn.expand('%:t:r'),
        }, {
            detach = true,
        })
    else
        jobstart({
            'kotlinc',
            fn.expand('%:p'),
            '-include-runtime',
            '-d',
            '/tmp/kotlin-test.jar',
            '&&',
            'kotlin',
            '/tmp/kotlin-test.jar',
        }, {
            detach = true,
        })
    end
end, {})

usercmd('KotlinQuickfix', function()
    local diagnostics = get(0)
    code_action({
        context = {
            diagnostics = diagnostics,
            only = {
                'quickfix',
            },
            triggerKind = lsp.protocol.CodeActionTriggerKind.Invoked,
        },
        apply = true,
    })
end, {})

autocmd('BufWritePre', {
    group = group,
    pattern = {
        '*.kt',
        '*.kts',
    },
    callback = function(args)
        local diagnostics = get(args.buf)
        code_action({
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
                local client = client_by_id(client_id)
                return client ~= nil and client.name == 'kotlin_ls'
            end,
        })
    end,
})

autocmd('BufWritePost', {
    group = group,
    pattern = {
        '*.kt',
        '*.kts',
    },
    callback = function(args)
        jobstart({
            'ktlint',
            vim.api.nvim_buf_get_name(args.buf),
        }, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if not data then
                    return
                end
                local out = table.concat(data, '')
                if out ~= '' then
                    schedule(function()
                        notify('ktlint: ' .. out, INFO)
                    end)
                end
            end,
        })
    end,
})

usercmd('KotlinCodeAction', function()
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
            local client = client_by_id(client_id)
            return client ~= nil and client.name == 'kotlin_ls'
        end,
        apply = true,
    })
end, {})
usercmd('KotlinRangeAction', function()
    local bufnr = 0
    local diagnostics = get(bufnr)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
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
            local client = client_by_id(client_id)
            return client ~= nil and client.name == 'kotlin_ls'
        end,
        apply = false,
    })
end, {
    range = true,
})

autocmd('LspAttach', {
    group = group,
    callback = function(args)
        local client = client_by_id(args.data.client_id)
        if client and client.name == 'kotlin_ls' then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})

usercmd('KotlinRun', function()
    local gradle_file = findfile('build.gradle.kts', '.;')
    if gradle_file ~= '' then
        jobstart({
            'gradle',
            'run',
        }, { detach = true })
    else
        jobstart({
            'kotlinc',
            fn.expand('%:p'),
            '-include-runtime',
            '-d',
            '/tmp/kotlin-run.jar',
            '&&',
            'kotlin',
            '/tmp/kotlin-run.jar',
        }, { detach = true })
    end
end, {})

usercmd('KotlinBuild', function()
    local gradle_file = findfile('build.gradle.kts', '.;')
    if gradle_file ~= '' then
        jobstart({
            'gradle',
            'build',
        }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Build successful', INFO)
                    else
                        notify('Build failed', ERROR)
                    end
                end)
            end,
        })
    else
        jobstart({
            'kotlinc',
            fn.expand('%:p'),
            '-include-runtime',
            '-d',
            fn.expand('%:p:r') .. '.jar',
        }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Build successful', INFO)
                    else
                        notify('Build failed', ERROR)
                    end
                end)
            end,
        })
    end
end, {})

return M
