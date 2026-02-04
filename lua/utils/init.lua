-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Diver Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
require('utils.ddx')
M.docs = require('utils.docs')
M.media = require('utils.media')
M.ux = require('utils.ux')
require('utils.mail')
require('utils.ui')
M.dictionary = {
  path = vim.fn.stdpath('config') .. '/lua/utils/docs/dictionary',
  file = 'words.txt',
  load_words = function()
    local dict = vim.fn.stdpath('config') .. '/lua/utils/docs/dictionary/words.txt'
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