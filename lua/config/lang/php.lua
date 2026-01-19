-- /qompassai/Diver/lua/config/lang/php.lua
-- Qompass AI Diver PHP Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------
---@meta
---@module 'config.lang.php'
local M = {}
vim.api.nvim_create_user_command('PhpStan', function()
    if vim.fn.executable('phpstan') == 1 then
        vim.cmd('!phpstan analyse')
    else
        vim.echo('phpstan not found in PATH', vim.log.levels.ERROR)
    end
end, {
    desc = 'Run PHPStan analysis',
})
vim.api.nvim_create_user_command('Pint', function()
    if vim.fn.executable('pint') == 1 then
        vim.cmd('!pint')
    else
        vim.echo('pint not found in PATH', vim.log.levels.ERROR)
    end
end, {
    desc = 'Run Laravel Pint formatter',
})
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client_id = args.data and args.data.client_id
        if not client_id then
            return
        end
        local client = vim.lsp.get_client_by_id(client_id)
        if not client then
            return
        end
        if client:supports_method('textDocument/foldingRange') then
            local win = vim.api.nvim_get_current_win()
            vim.wo[win][0].foldexpr = 'v:lua.vim.lsp.foldexpr()'
        end
    end,
})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.php',
        '*.phtml',
    },
    callback = function()
        vim.lsp.buf.format()
    end,
})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.php',
        '*.phtml',
    },
    callback = function()
        vim.lsp.buf.code_action({
            context = {
                diagnostics = {},
                only = { 'source.fixAll' },
            },
            apply = true,
        })
    end,
})
vim.api.nvim_create_user_command('PhpTest', function()
    vim.fn.jobstart({
        'phpunit',
        vim.fn.expand('%:p'),
    }, {
        detach = true,
    })
end, {})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = '*.php',
    callback = function(args)
        vim.lsp.buf.format({
            bufnr = args.buf,
            async = false,
        })
    end,
})
vim.api.nvim_create_user_command('PhpQuickfix', function()
    local diagnostics = vim.diagnostic.get(0)
    vim.lsp.buf.code_action({
        context = {
            diagnostics = diagnostics,
            only = { 'quickfix' },
            triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
        },
        apply = true,
    })
end, {})

vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.php',
        '*.phtml',
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
                return client ~= nil and (client.name == 'intelephense' or client.name == 'phpactor')
            end,
        })
    end,
})
vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.php',
    callback = function(args)
        vim.fn.jobstart({
            'php',
            '-l',
            vim.api.nvim_buf_get_name(args.buf),
        }, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data, _)
                if not data then
                    return
                end
                local out = table.concat(data, '')
                if out ~= '' then
                    vim.schedule(function()
                        vim.notify('php -l: ' .. out, vim.log.levels.INFO)
                    end)
                end
            end,
            on_stderr = function(_, data, _)
                if not data then
                    return
                end
                local out = table.concat(data, '')
                if out ~= '' then
                    vim.schedule(function()
                        vim.notify('php -l (err): ' .. out, vim.log.levels.WARN)
                    end)
                end
            end,
        })
    end,
})
vim.api.nvim_create_user_command('PhpCodeAction', function()
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
            return client ~= nil and (client.name == 'intelephense' or client.name == 'phpactor')
        end,
        apply = true,
    })
end, {})
vim.api.nvim_create_user_command('PhpRangeAction', function()
    local bufnr = 0
    local diagnostics = vim.diagnostic.get(bufnr)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')

    vim.lsp.buf.code_action({
        context = {
            diagnostics = diagnostics,
            only = { 'quickfix', 'refactor.extract' },
        },
        range = {
            start = { start_pos[1], start_pos[2] },
            ['end'] = { end_pos[1], end_pos[2] },
        },
        filter = function(_, client_id)
            local client = vim.lsp.get_client_by_id(client_id)
            return client ~= nil and (client.name == 'intelephense' or client.name == 'phpactor')
        end,
        apply = false,
    })
end, { range = true })
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and (client.name == 'intelephense' or client.name == 'phpactor') then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})

function M.php_dap()
    local dap = require('dap')
    dap.adapters.php = {
        type = 'executable',
        command = 'node',
        args = {
            os.getenv('HOME') .. '/.local/share/vscode-php-debug/out/phpDebug.js',
        },
    }
    dap.configurations.php = {
        {
            type = 'php',
            request = 'launch',
            name = 'Listen for Xdebug',
            port = 9003,
            pathMappings = {
                ['/var/www/html'] = '${workspaceFolder}',
            },
        },
    }
end

return M
