-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Diver Utils Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
M.safe_require = require('utils.safe_require').safe_require
M.ui = require('utils.ui')
M.dictionary = {
    path = vim.fn.stdpath('config') .. '/lua/utils/dictionary',
    file = 'words.txt',
    load_words = function()
        local dict_path = vim.fn.stdpath('config') ..
                              '/lua/utils/dictionary/words.txt'
        local lines = {}
        local f = io.open(dict_path, 'r')
        if not f then
            vim.notify('[Diver] Failed to open dictionary: ' .. dict_path,
                       vim.log.levels.WARN)
            return {}
        end
        for line in f:lines() do table.insert(lines, line) end
        f:close()
        return lines
    end
}
return M
