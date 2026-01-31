-- /qompassai/Diver/lua/config/lang/bash.lua
-- Qompass AI Diver Bash Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local header = require('utils.docs')
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
return M