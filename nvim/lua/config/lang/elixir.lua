-- /qompassai/Diver/lua/config/lang/elixir.lua
-- Qompass AI Diver Elixir Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version 5.1, JIT
local api = vim.api
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local client_by_id = vim.lsp.get_client_by_id
local cmd = vim.cmd
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
local group = augroup('Elixir', {
    clear = true,
})
local usercmd = vim.api.nvim_create_user_command
autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.ex',
        '*.exs',
        '*.eex',
        '*.heex',
        '*.leex',
    },
    callback = function()
        local lines = api.nvim_buf_get_lines(0, 0, 1, false) ---@type string[]
        if lines[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p') ---@type string
        local hdr = header.make_header(filepath, '#')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        cmd('normal! G')
    end,
})
autocmd('BufWritePre', {
    group = group,
    pattern = {
        '*.ex',
        '*.exs',
        '*.eex',
        '*.heex',
        '*.leex',
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
        '*.ex',
        '*.exs',
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
usercmd('ElixirCompile', function()
    local mix_file = findfile('mix.exs', '.;')
    if mix_file ~= '' then
        jobstart({
            'mix',
            'compile',
        }, {
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
    else
        jobstart({
            'elixirc',
            fn.expand('%:p'),
        }, {
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
    end
end, {})

usercmd('ElixirTest', function()
    local mix_file = findfile('mix.exs', '.;')
    if mix_file ~= '' then
        local current_file = fn.expand('%:p')
        if current_file:match('_test%.exs$') then
            jobstart({
                'mix',
                'test',
                current_file,
            }, {
                detach = false,
            })
        else
            jobstart({
                'mix',
                'test',
            }, {
                detach = false,
            })
        end
    else
        notify('No mix.exs found', ERROR)
    end
end, {})
usercmd('ElixirRun', function()
    local mix_file = findfile('mix.exs', '.;')
    if mix_file ~= '' then
        jobstart({
            'mix',
            'run',
        }, { detach = true })
    else
        jobstart({
            'elixir',
            fn.expand('%:p'),
        }, { detach = true })
    end
end, {})

usercmd('ElixirIex', function()
    local mix_file = findfile('mix.exs', '.;')
    if mix_file ~= '' then
        cmd('terminal iex -S mix')
    else
        cmd('terminal iex')
    end
end, {})
usercmd('ElixirQuickfix', function()
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
        '*.ex',
        '*.exs',
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
                return client ~= nil and client.name == 'elixirls'
            end,
        })
    end,
})
autocmd('BufWritePost', {
    group = group,
    pattern = {
        '*.ex',
        '*.exs',
    },
    callback = function(args)
        local mix_file = findfile('mix.exs', '.;')
        if mix_file ~= '' then
            jobstart({
                'mix',
                'credo',
                'suggest',
                '--format=oneline',
                api.nvim_buf_get_name(args.buf),
            }, {
                stdout_buffered = true,
                on_stdout = function(_, data, _)
                    if not data then
                        return
                    end
                    local out = table.concat(data, '')
                    if out ~= '' and not out:match('^%s*$') then
                        schedule(function()
                            notify('credo: ' .. out, INFO)
                        end)
                    end
                end,
            })
        end
    end,
})
usercmd('ElixirCodeAction', function()
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
            return client ~= nil and client.name == 'elixirls'
        end,
        apply = true,
    })
end, {})
usercmd('ElixirRangeAction', function()
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
            return client ~= nil and client.name == 'elixirls'
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
        if client and client.name == 'elixirls' then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})
usercmd('ElixirFormat', function()
    local mix_file = findfile('mix.exs', '.;')
    if mix_file ~= '' then
        jobstart({
            'mix',
            'format',
            fn.expand('%:p'),
        }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Formatted successfully', INFO)
                        cmd('e!')
                    else
                        notify('Format failed', ERROR)
                    end
                end)
            end,
        })
    else
        notify('No mix.exs found', ERROR)
    end
end, {})
usercmd('ElixirDeps', function()
    jobstart({ 'mix', 'deps.get' }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('Dependencies fetched', INFO)
                else
                    notify('Failed to fetch dependencies', ERROR)
                end
            end)
        end,
    })
end, {})
return M