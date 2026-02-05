-- /qompassai/Diver/lua/config/lang/nix.lua
-- Qompass AI Diver Nix Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
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
local group = augroup('Nix', {
    clear = true,
})
local usercmd = vim.api.nvim_create_user_command
autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.nix',
    },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '#')
        local lines = {}
        vim.list_extend(lines, hdr)
        local filename = fn.expand('%:t')
        if filename == 'flake.nix' then
            vim.list_extend(lines, {
                '{',
                '  description = "";',
                '',
                '  inputs = {',
                '    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";',
                '  };',
                '',
                '  outputs = { self, nixpkgs, ... }: {',
                '    ',
                '  };',
                '}',
            })
        elseif filename == 'default.nix' then
            vim.list_extend(lines, {
                '{ pkgs ? import <nixpkgs> { } }:',
                '',
                'pkgs.mkDerivation {',
                '  pname = "";',
                '  version = "0.1.0";',
                '',
                '  src = ./.;',
                '}',
            })
        elseif filename == 'shell.nix' then
            vim.list_extend(lines, {
                '{ pkgs ? import <nixpkgs> { } }:',
                '',
                'pkgs.mkShell {',
                '  buildInputs = with pkgs; [',
                '    ',
                '  ];',
                '}',
            })
        end
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        if filename == 'flake.nix' or filename == 'default.nix' or filename == 'shell.nix' then
            cmd('normal! gg')
            fn.search('""\\|pname = ""')
        else
            cmd('normal! G')
        end
    end,
})
autocmd('FileType', {
    group = group,
    pattern = 'nix',
    callback = function(args)
        local bufnr = args.buf
        vim.bo[bufnr].tabstop = 2
        vim.bo[bufnr].shiftwidth = 2
        vim.bo[bufnr].softtabstop = 2
        vim.bo[bufnr].expandtab = true
        vim.bo[bufnr].commentstring = '# %s'
    end,
})
autocmd('BufWritePre', {
    group = group,
    pattern = { '*.nix', 'flake.nix', 'default.nix', 'shell.nix' },
    callback = function(args)
        local diagnostics = get(args.buf)
        code_action({
            context = {
                diagnostics = diagnostics,
                only = { 'source.organizeImports', 'source.fixAll' },
                triggerKind = lsp.protocol.CodeActionTriggerKind.Automatic,
            },
            apply = true,
            filter = function(_, client_id)
                local client = client_by_id(client_id)
                return client ~= nil and (client.name == 'nixd' or client.name == 'nil_ls' or client.name == 'statix')
            end,
        })
    end,
})
autocmd('BufWritePost', {
    group = group,
    pattern = { '*.nix', 'flake.nix', 'default.nix', 'shell.nix' },
    callback = function(args)
        if fn.executable('statix') == 1 then
            jobstart({ 'statix', 'check', api.nvim_buf_get_name(args.buf) }, {
                stdout_buffered = true,
                on_stdout = function(_, data, _)
                    if not data then
                        return
                    end
                    local out = table.concat(data, '')
                    if out ~= '' and not out:match('^%s*$') and not out:match('No issues found') then
                        schedule(function()
                            notify('statix: ' .. out, INFO)
                        end)
                    end
                end,
            })
        end
    end,
})
usercmd('NixBuild', function()
    local flake = findfile('flake.nix', '.;')
    if flake ~= '' then
        jobstart({ 'nix', 'build' }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Nix build successful', INFO)
                    else
                        notify('Nix build failed', ERROR)
                    end
                end)
            end,
        })
    else
        local current_file = fn.expand('%:p')
        jobstart({ 'nix-build', current_file }, {
            on_exit = function(_, code, _)
                schedule(function()
                    if code == 0 then
                        notify('Nix build successful', INFO)
                    else
                        notify('Nix build failed', ERROR)
                    end
                end)
            end,
        })
    end
end, {})
usercmd('NixFlakeCheck', function()
    jobstart({ 'nix', 'flake', 'check' }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('Nix flake check passed', INFO)
                else
                    notify('Nix flake check failed', ERROR)
                end
            end)
        end,
    })
end, {})
usercmd('NixFlakeUpdate', function()
    jobstart({ 'nix', 'flake', 'update' }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('Nix flake updated', INFO)
                    cmd('e!')
                else
                    notify('Nix flake update failed', ERROR)
                end
            end)
        end,
    })
end, {})
usercmd('NixFormat', function()
    local current_file = fn.expand('%:p')
    local formatter = 'nixfmt'
    if fn.executable('nixfmt-rfc-style') == 1 then
        formatter = 'nixfmt-rfc-style'
    elseif fn.executable('nixfmt') == 1 then
        formatter = 'nixfmt'
    elseif fn.executable('alejandra') == 1 then
        formatter = 'alejandra'
    else
        notify('No Nix formatter found (nixfmt/alejandra)', ERROR)
        return
    end
    jobstart({
        formatter,
        current_file,
    }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('Nix format successful', INFO)
                    cmd('e!')
                else
                    notify('Nix format failed', ERROR)
                end
            end)
        end,
    })
end, {})
usercmd('NixStatix', function()
    local current_file = fn.expand('%:p')
    if fn.executable('statix') ~= 1 then
        notify('statix not found', ERROR)
        return
    end
    jobstart({ 'statix', 'fix', current_file }, {
        on_exit = function(_, code, _)
            schedule(function()
                if code == 0 then
                    notify('statix fix successful', INFO)
                    cmd('e!')
                else
                    notify('statix fix failed', ERROR)
                end
            end)
        end,
    })
end, {})
usercmd('NixRepl', function()
    local flake = findfile('flake.nix', '.;')
    if flake ~= '' then
        cmd('terminal nix repl')
        vim.defer_fn(function()
            api.nvim_feedkeys(':load-flake .\n', 't', false)
        end, 100)
    else
        cmd('terminal nix repl')
    end
end, {})
usercmd('NixShell', function()
    local shell_nix = findfile('shell.nix', '.;')
    if shell_nix ~= '' then
        cmd('terminal nix-shell')
    else
        cmd('terminal nix shell')
    end
end, {})
usercmd('NixEval', function()
    local current_file = fn.expand('%:p')
    jobstart({ 'nix-instantiate', '--eval', '--strict', current_file }, {
        stdout_buffered = true,
        on_stdout = function(_, data, _)
            if not data then
                return
            end
            local out = table.concat(data, '\n')
            schedule(function()
                notify('Nix eval:\n' .. out, INFO)
            end)
        end,
        on_exit = function(_, code, _)
            if code ~= 0 then
                schedule(function()
                    notify('Nix eval failed', ERROR)
                end)
            end
        end,
    })
end, {})
usercmd('NixQuickfix', function()
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
usercmd('NixCodeAction', function()
    local diagnostics = get(0)
    code_action({
        context = {
            diagnostics = diagnostics,
            only = { 'quickfix', 'refactor', 'source.organizeImports', 'source.fixAll' },
        },
        filter = function(_, client_id)
            local client = client_by_id(client_id)
            return client ~= nil and (client.name == 'nixd' or client.name == 'nil_ls' or client.name == 'statix')
        end,
        apply = true,
    })
end, {})
usercmd('NixRangeAction', function()
    local bufnr = 0
    local diagnostics = get(bufnr)
    local start_pos = api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = api.nvim_buf_get_mark(bufnr, '>')
    code_action({
        context = {
            diagnostics = diagnostics,
            only = { 'quickfix', 'refactor.extract' },
        },
        range = {
            start = { start_pos[1], start_pos[2] },
            ['end'] = { end_pos[1], end_pos[2] },
        },
        filter = function(_, client_id)
            local client = client_by_id(client_id)
            return client ~= nil and (client.name == 'nixd' or client.name == 'nil_ls' or client.name == 'statix')
        end,
        apply = false,
    })
end, {
    range = true,
})
return M