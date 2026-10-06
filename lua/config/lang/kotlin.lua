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
local formatters = require('formatters')
local modernize = require('config.lang.modernize')
local ERROR = vim.log.levels.ERROR
local get = vim.diagnostic.get
local INFO = vim.log.levels.INFO
local jobstart = vim.fn.jobstart
local lsp = vim.lsp
local notify = vim.notify
local schedule = vim.schedule
local fn = vim.fn
local header = require('research.docs')
local group = augroup('Kotlin', {
    clear = true,
})
---Create a buffer-local user command when a kotlin buffer opens.
---Lang commands only exist in buffers of their own language: they never
---pollute `:` completion elsewhere.
---@param name string command name
---@param fn function|string command implementation
---@param opts? table nvim_create_user_command options
local function usercmd(name, fn, opts)
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'kotlin',
        desc = ('Buffer-local command: %s'):format(name),
        callback = function(args)
            vim.api.nvim_buf_create_user_command(args.buf, name, fn, opts or {})
        end,
    })
end
autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.kt',
        '*.kts',
    },
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
formatters.register_stage({
    name = 'kotlin_lsp_format',
    priority = 415,
    patterns = {
        '*.kt',
        '*.kts',
    },
    desc = 'Format Kotlin sources with the attached LSP client before save',
    run = function(bufnr) ---@param bufnr integer
        lsp.buf.format({
            bufnr = bufnr,
            async = false,
        })
    end,
})
formatters.register_stage({
    name = 'kotlin_fixall',
    priority = 416,
    patterns = {
        '*.kt',
        '*.kts',
    },
    desc = 'Apply source.fixAll code actions to Kotlin sources before save',
    run = function()
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
formatters.register_stage({
    name = 'kotlin_organize_imports',
    priority = 417,
    patterns = {
        '*.kt',
        '*.kts',
    },
    desc = 'Organize imports in Kotlin sources before save',
    run = function(bufnr)
        local diagnostics = get(bufnr)
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


local REPLACEMENTS = {
}

---Modernize deprecated kotlin syntax in the current buffer.
function M.modernize()
    modernize.buffer('kotlin', REPLACEMENTS, 'kotlin')
end

return M
