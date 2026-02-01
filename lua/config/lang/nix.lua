-- /qompassai/Diver/lua/config/lang/nix.lua
-- Qompass AI Diver Nix Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
local M = {}
---@class NixPaths
local Nix = {}
local g = vim.g
---@param name string Executable name
---@return string|nil
function Nix.find_bin(name)
    local search_paths = {
        g.nix_user_profile .. '/bin/' .. name,
        g.nix_per_user_profile .. '/bin/' .. name,
        '/nix/var/nix/profiles/default/bin/' .. name,
        '/run/current-system/sw/bin/' .. name,
    }
    for _, path in ipairs(search_paths) do
        if vim.fn.executable(path) == 1 then
            return path
        end
    end
    return nil
end
--- Find library in Nix profiles
---@param name string
---@return string|nil
function Nix.find_lib(name)
    local search_paths = {
        g.nix_user_profile .. '/lib/' .. name,
        '/nix/var/nix/profiles/default/lib/' .. name,
        '/run/current-system/sw/lib/' .. name,
    }
    for _, path in ipairs(search_paths) do
        if vim.fn.filereadable(path) == 1 then
            return path
        end
    end
    return nil
end
--- Check if running on NixOS
---@return boolean
function Nix.is_nixos()
    return vim.fn.filereadable('/etc/NIXOS') == 1 or vim.fn.isdirectory('/run/current-system') == 1
end
--- Get Nix channel for current user
---@return string|nil
function Nix.get_channel()
    local channel_path = vim.fn.expand('~/.nix-channels')
    if vim.fn.filereadable(channel_path) == 1 then
        local channels = vim.fn.readfile(channel_path)
        if #channels > 0 then
            return channels[1]:match('^%S+')
        end
    end
    return nil
end
_G.Nix = Nix
---@param opts? table
function M.nix_autocmds(opts) ---@return nil|string[]
    opts = opts or {}
    vim.api.nvim_create_user_command('SetNixFormatter', function(args)
        vim.g.nix_formatter = args.args
    end, {
        nargs = 1,
        complete = function()
            return {
                'alejandra',
                'nixfmt',
                'nixpkgs-fmt',
            }
        end,
    })
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'nix',
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.conceallevel = 2
    end,
})

vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.nix',
    },
    callback = function(args)
        vim.lsp.buf.format({
            bufnr = args.buf,
            async = true,
        })
    end,
})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.nix',
    },
    callback = function(args)
        local diagnostics = vim.diagnostic.get(args.buf)
        vim.lsp.buf.code_action({
            context = {
                diagnostics = diagnostics,
                only = {
                    'source.fixAll',
                    'source.organizeImports',
                },
                triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Source,
            },
            apply = true,
            filter = function(_, client_id)
                local client = vim.lsp.get_client_by_id(client_id)
                return client ~= nil and (client.name == 'nil_ls' or client.name == 'nixd')
            end,
        })
    end,
})
vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = {
        '*.nix',
    },
    callback = function(args)
        if vim.fn.executable('alejandra') == 0 then
            return
        end

        vim.fn.jobstart({
            'alejandra',
            vim.api.nvim_buf_get_name(args.buf),
        }, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stderr = function(_, data, _)
                if not data then
                    return
                end
                local out = table.concat(data, '')
                if out ~= '' then
                    vim.schedule(function()
                        vim.notify('alejandra: ' .. out, vim.log.levels.WARN)
                    end)
                end
            end,
        })
    end,
})
vim.api.nvim_create_user_command('NixQuickfix', function()
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
        filter = function(_, client_id)
            local client = vim.lsp.get_client_by_id(client_id)
            return client ~= nil and (client.name == 'nil_ls' or client.name == 'nixd')
        end,
    })
end, {})
vim.api.nvim_create_user_command('NixCodeAction', function()
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
            return client ~= nil and (client.name == 'nil_ls' or client.name == 'nixd')
        end,
        apply = true,
    })
end, {})
vim.api.nvim_create_user_command('NixRangeAction', function()
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
            return client ~= nil and (client.name == 'nil_ls' or client.name == 'nixd')
        end,
        apply = true,
    })
end, {
    range = true,
})
vim.api.nvim_create_user_command('NixCheck', function()
    vim.fn.jobstart({
        'nix',
        'flake',
        'check',
    }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stderr = function(_, data, _)
            if not data then
                return
            end
            local out = table.concat(data, '')
            if out ~= '' then
                vim.schedule(function()
                    vim.notify('nix flake check: ' .. out, vim.log.levels.WARN)
                end)
            end
        end,
    })
end, {})

---@param opts? table
function M.nix_cfg(opts)
    opts = opts
end

return M
