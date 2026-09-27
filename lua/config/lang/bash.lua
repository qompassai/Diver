-- /qompassai/Diver/lua/config/lang/bash.lua
-- Qompass AI Diver Bash Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local formatters = require('formatters')
local header = require('research.docs')
local group = api.nvim_create_augroup('Bash', {
    clear = true,
})
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufReadPost' }, {
    group = group,
    pattern = {
        '*.sh',
        '*.bash',
        '*/bin/*',
    },
    callback = function()
        vim.notify('bash template fired', vim.log.levels.INFO)
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local shebang = '#!/usr/bin/env bash'
        local hdr = header.make_header(filepath, '#')
        local lines = { shebang, '' }
        vim.list_extend(lines, hdr)
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})
-- Migrated from after/ftplugin/bash.lua: a buffer-local BufWritePre there
-- was re-registered for every shell buffer; as a pipeline stage it is
-- registered once here. filetypes = { 'sh' } matches the ftplugin trigger.
formatters.register_stage({
    name = 'bash_lsp_format',
    priority = 400,
    filetypes = { 'sh' },
    desc = 'Format shell scripts with the attached LSP client before save',
    run = function(bufnr)
        vim.lsp.buf.format({
            bufnr = bufnr,
            async = true,
        })
    end,
})
return M
