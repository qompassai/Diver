-- /qompassai/Diver/lua/config/lang/scala.lua
-- Qompass AI Diver Scala Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local header = require('utils.docs')
local group = api.nvim_create_augroup('Scala', {
    clear = true,
})
local function buf_is_empty()
    return api.nvim_buf_get_lines(0, 0, 1, false)[1] == ''
end
api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.scala',
    },
    callback = function()
        if not buf_is_empty() then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '//')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})
api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.sc',
    },
    callback = function()
        if not buf_is_empty() then
            return
        end
        local filepath = fn.expand('%:p')
        local shebang = '#!/usr/bin/env -S scala-cli shebang'
        local hdr = header.make_header(filepath, '//')
        local lines = { shebang, '' }
        vim.list_extend(lines, hdr)
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})
return M