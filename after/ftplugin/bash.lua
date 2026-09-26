-- /qompassai/Diver/after/ftplugin/bash.lua
-- Qompass AI Diver After Filetype Bash Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
-- buffer-local: ftplugin files are sourced once per buffer, so a global
-- autocmd here would be re-registered on every bash/sh buffer open and
-- fire N duplicate vim.lsp.buf.format calls on each write (N = buffers
-- opened this session). buffer = 0 matches after/ftplugin/verilog.lua.
api.nvim_create_autocmd('BufWritePre', {
    buffer = 0,
    desc = 'Format shell script on save',
    callback = function(args)
        vim.lsp.buf.format({
            bufnr = args.buf,
            async = true,
        })
    end,
})
