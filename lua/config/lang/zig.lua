-- zig.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_user_command('ZigTest', function() ---Zig
    vim.fn.jobstart({ 'zig', 'test', vim.fn.expand('%:p') }, {
        detach = true,
    })
end, {})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = '*.zig',
    callback = function(args)
        vim.lsp.buf.format({ bufnr = args.buf, async = false })
    end,
})
vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.zig',
    callback = function(args)
        vim.fn.jobstart({ 'zlint', vim.api.nvim_buf_get_name(args.buf) }, {
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
