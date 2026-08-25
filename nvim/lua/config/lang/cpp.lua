#!/usr/bin/env lua
-- /qompassai/Diver/lua/config/lang/cpp.lua
-- Qompass AI Diver C++ Config
---@copyright 2026 Qompass AI, All rights reserved
---@see https://clangd.llvm.org/
-- ----------------------------------------
---@class CppModule
---@field compile fun(opts?: table): nil
---@field run fun(): nil
---@field debug fun(): nil
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
local group = augroup('Cpp', {
    clear = true,
})
local usercmd = vim.api.nvim_create_user_command
autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.cpp',
        '*.hpp',
        '*.cc',
        '*.hh',
        '*.cxx',
        '*.hxx',
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
autocmd('BufWritePre', {
    group = group,
    pattern = {
        '*.cpp',
        '*.hpp',
        '*.cc',
        '*.hh',
        '*.cxx',
        '*.hxx',
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
    pattern = { '*.cpp', '*.hpp', '*.cc', '*.hh', '*.cxx', '*.hxx' },
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
usercmd('CppCompile', function()
    local makefile = findfile('Makefile', '.;')
    local cmake = findfile('CMakeLists.txt', '.;')
    if makefile ~= '' then
        jobstart({ 'make' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Compilation successful', INFO)
                    else
                        notify('Compilation failed', ERROR)
                    end
                end)
            end,
        })
    elseif cmake ~= '' then
        jobstart({ 'cmake', '--build', 'build' }, {
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
        local output = fn.expand('%:p:r')
        jobstart({
            'g++',
            '-std=c++20',
            '-Wall',
            '-Wextra',
            fn.expand('%:p'),
            '-o',
            output,
        }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Compiled to ' .. output, INFO)
                    else
                        notify('Compilation failed', ERROR)
                    end
                end)
            end,
        })
    end
end, {})
usercmd('CppRun', function()
    local executable = fn.expand('%:p:r')
    if fn.filereadable(executable) == 1 then
        jobstart({ executable }, { detach = true })
    else
        notify('Executable not found. Compile first with :CppCompile', ERROR)
    end
end, {})

usercmd('CppQuickfix', function()
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
        '*.cpp',
        '*.hpp',
        '*.cc',
        '*.hh',
        '*.cxx',
        '*.hxx',
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
                triggerKind = lsp.protocol.CodeActionTriggerKind.Source,
            },
            apply = true,
            filter = function(_, client_id)
                local client = client_by_id(client_id)
                return client ~= nil and client.name == 'clangd'
            end,
        })
    end,
})

autocmd('BufWritePost', {
    group = group,
    pattern = {
        '*.cpp',
        '*.hpp',
        '*.cc',
        '*.hh',
        '*.cxx',
        '*.hxx',
    },
    callback = function(args)
        jobstart({
            'clang-tidy',
            api.nvim_buf_get_name(args.buf),
            '--',
            '-std=c++20',
            '-Wall',
            '-Wextra',
        }, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if not data then
                    return
                end
                local out = table.concat(data, '')
                if out ~= '' then
                    schedule(function()
                        notify('clang-tidy: ' .. out, INFO)
                    end)
                end
            end,
        })
    end,
})
usercmd('CppCodeAction', function()
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
            return client ~= nil and client.name == 'clangd'
        end,
        apply = true,
    })
end, {})
usercmd('CppRangeAction', function()
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
            return client ~= nil and client.name == 'clangd'
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
        if client and client.name == 'clangd' then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})

usercmd('CppDebug', function()
    local executable = fn.expand('%:p:r')
    if fn.filereadable(executable) == 1 then
        -- Assumes you have nvim-dap configured
        local dap_ok, dap = pcall(require, 'dap')
        if dap_ok then
            dap.run({
                type = 'cppdbg',
                request = 'launch',
                name = 'Debug C++ Program',
                program = executable,
                cwd = '${workspaceFolder}',
                stopAtEntry = false,
            })
        else
            notify('nvim-dap not available', ERROR)
        end
    else
        notify('Executable not found. Compile first with :CppCompile', ERROR)
    end
end, {})

return M