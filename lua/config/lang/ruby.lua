-- /qompassai/Diver/lua/config/lang/ruby.lua
-- Qompass AI Diver Ruby Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local header = require('utils.docs')
local group = api.nvim_create_augroup('Ruby', {
    clear = true,
})
api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.rb',
    },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local shebang = '#!/usr/bin/env ruby'
        local hdr = header.make_header(filepath, '#')
        local lines = { shebang, '' }
        vim.list_extend(lines, hdr)
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.rb',
        '*.rake',
        'Gemfile',
        'Rakefile',
    },
    callback = function(args)
        vim.lsp.buf.format({
            async = true,
            bufnr = args.buf,
            filter = function(client)
                return client.name == 'ruby-lsp'
            end,
        })
    end,
})
return M
