#!/usr/bin/env lua
-- /qompassai/Diver/lua/config/lang/toml.lua
-- Qompass AI Diver TOML Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local group = api.nvim_create_augroup('TOML', {
    clear = true,
})
local header = require('utils.docs.docs')
api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = { '*.toml' },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local hdr = header.make_header(filepath, '#')
        api.nvim_buf_set_lines(0, 0, 0, false, hdr)
        vim.cmd('normal! G')
    end,
})
return M