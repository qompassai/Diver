-- /qompassai/Diver/lua/config/lang/ruby.lua
-- Qompass AI Diver Ruby Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
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
local group = augroup('Ruby', {
    clear = true,
})
local usercmd = vim.api.nvim_create_user_command
api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.rb',
    },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local shebang = '#!/usr/bin/env ruby'
        local hdr = header.make_header(filepath, '#')
        local lines = { shebang, '' }
        vim.list_extend(lines, hdr)
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})
autocmd('BufNewFile', {
    group = group,
    pattern = { '*.rb' },
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

autocmd('FileType', {
    group = group,
    pattern = 'ruby',
    callback = function(args)
        local bufnr = args.buf
        vim.bo[bufnr].tabstop = 2
        vim.bo[bufnr].shiftwidth = 2
        vim.bo[bufnr].expandtab = true
        vim.bo[bufnr].commentstring = '# %s'
    end,
})

autocmd('BufWritePre', {
    group = group,
    pattern = {
        '*.rb',
        '*.rake',
        'Gemfile',
        'Rakefile',
        'config.ru',
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
                return client ~= nil and (client.name == 'ruby_lsp' or client.name == 'solargraph')
            end,
        })
    end,
})

autocmd('BufWritePost', {
    group = group,
    pattern = {
        '*.rb',
        '*.rake',
        'Gemfile',
        'Rakefile',
    },
    callback = function(args)
        local rubocop = findfile('.rubocop.yml', '.;') --[[@as string]]
        if rubocop ~= '' then
            jobstart({
                'rubocop',
                '--format',
                'emacs',
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
                            notify('rubocop: ' .. out, INFO)
                        end)
                    end
                end,
            })
        end
    end,
})

usercmd('RubyRun', function()
    local current_file = fn.expand('%:p')
    jobstart({
        'ruby',
        current_file,
    }, { detach = true })
end, {})

usercmd('RubyTest', function()
    local current_file = fn.expand('%:p')
    local gemfile = findfile('Gemfile', '.;') --[[@as string]]

    if gemfile ~= '' then
        -- Check if using rspec or minitest
        local rspec_dir = fn.finddir('spec', '.;')
        if rspec_dir ~= '' then
            jobstart({
                'bundle',
                'exec',
                'rspec',
                current_file,
            }, { detach = false })
        else
            jobstart({
                'bundle',
                'exec',
                'ruby',
                current_file,
            }, { detach = false })
        end
    else
        jobstart({
            'ruby',
            current_file,
        }, { detach = false })
    end
end, {})

usercmd('RubyIRB', function()
    cmd('terminal irb')
end, {})
usercmd('RubyPry', function()
    cmd('terminal pry')
end, {})
usercmd('RubyRubocop', function()
    local current_file = fn.expand('%:p')
    jobstart({
        'rubocop',
        '--auto-correct',
        current_file,
    }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('RuboCop auto-correct successful', INFO)
                    vim.cmd('e!')
                else
                    notify('RuboCop auto-correct failed', ERROR)
                end
            end)
        end,
    })
end, {})
usercmd('RubyGems', function()
    jobstart({ 'bundle', 'install' }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('Bundle install successful', INFO)
                else
                    notify('Bundle install failed', ERROR)
                end
            end)
        end,
    })
end, {})

usercmd('RubyQuickfix', function()
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
usercmd('RubyCodeAction', function()
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
            return client ~= nil and (client.name == 'ruby_lsp' or client.name == 'solargraph')
        end,
        apply = true,
    })
end, {})
usercmd('RubyRangeAction', function()
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
            return client ~= nil and (client.name == 'ruby_lsp' or client.name == 'solargraph')
        end,
        apply = false,
    })
end, {
    range = true,
})
return M