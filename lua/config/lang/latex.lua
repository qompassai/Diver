-- /qompassai/Diver/lua/config/lang/latex.lua
-- Qompass AI Diver LaTeX Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = { '*.tex', '*.ltx' },
    callback = function(args)
        vim.lsp.buf.format({ bufnr = args.buf, async = false })
        if vim.fn.executable('latexindent') == 1 or vim.fn.executable('latexindent.pl') == 1 then
            local bin = vim.fn.executable('latexindent') == 1 and 'latexindent' or 'latexindent.pl'
            vim.fn.jobstart({ bin, '-w', vim.api.nvim_buf_get_name(args.buf) }, {
                stdout_buffered = true,
                stderr_buffered = true,
                on_stderr = function(_, data, _)
                    if not data then
                        return
                    end
                    local out = table.concat(data, '')
                    if out ~= '' then
                        vim.schedule(function()
                            vim.notify('latexindent: ' .. out, vim.log.levels.WARN)
                        end)
                    end
                end,
            })
        end
    end,
})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = { '*.tex', '*.ltx' },
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
vim.api.nvim_create_user_command('TexBuild', function()
    vim.fn.jobstart({
        'latexmk',
        '-pdf',
        vim.fn.expand('%:p'),
    }, {
        detach = true,
    })
end, {})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = '*.tex',
    callback = function(args)
        vim.lsp.buf.format({
            bufnr = args.buf,
            async = false,
        })
    end,
})
vim.api.nvim_create_user_command('TexQuickfix', function()
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
    pattern = { '*.tex', '*.ltx' },
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
                -- adapt to whatever you use: "texlab", "ltex", etc.
                return client ~= nil and (client.name == 'texlab' or client.name == 'ltex')
            end,
        })
    end,
})
vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.tex',
    callback = function(args)
        if vim.fn.executable('chktex') == 0 then
            return
        end
        vim.fn.jobstart({ 'chktex', '-q', vim.api.nvim_buf_get_name(args.buf) }, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data, _)
                if not data then
                    return
                end
                local out = table.concat(data, '')
                if out ~= '' then
                    vim.schedule(function()
                        vim.notify('chktex: ' .. out, vim.log.levels.INFO)
                    end)
                end
            end,
        })
    end,
})
vim.api.nvim_create_user_command('TexCodeAction', function()
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
            return client ~= nil and (client.name == 'texlab' or client.name == 'ltex')
        end,
        apply = true,
    })
end, {})
vim.api.nvim_create_user_command('TexRangeAction', function()
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
            return client ~= nil and (client.name == 'texlab' or client.name == 'ltex')
        end,
        apply = false,
    })
end, { range = true })
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and (client.name == 'texlab' or client.name == 'ltex') then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})
