-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Diver Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
M.clipboard = require('utils.clipboard').setup()
M.ddx = require('utils.ddx')
M.docs = require('utils.docs')
M.safe_require = require('utils.safe_require').safe_require
M.ui = require('utils.ui')
M.dictionary = {
    path = vim.fn.stdpath('config') .. '/lua/utils/dictionary',
    file = 'words.txt',
    load_words = function()
        local dict = vim.fn.stdpath('config') .. '/lua/utils/dictionary/words.txt'
        local f = io.open(dict, 'r')
        if not f then
            vim.echo('Failed to open dictionary: ' .. dict, vim.log.levels.WARN)
            return {}
        end
        local t = {}
        for line in f:lines() do
            t[#t + 1] = line
        end
        f:close()
        return t
    end,
}
return M
