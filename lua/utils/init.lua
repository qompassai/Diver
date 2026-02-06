-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Diver Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {} ---@version JIT
local function safe_require(module)
  local ok, result = pcall(require, module)
  if not ok then
    vim.notify('Failed to load ' .. module .. ': ' .. tostring(result), vim.log.levels.WARN)
    return nil
  end
  return result
end
M.blue = safe_require('utils.blue')
M.ddx = safe_require('utils.ddx')
M.docs = safe_require('utils.docs')
M.media = safe_require('utils.media')
M.red = safe_require('utils.red')
M.ux = safe_require('utils.ux')
M.dictionary = {
  path = vim.fn.stdpath('config') .. '/lua/utils/docs/dictionary',
  file = 'words.txt',
  load_words = function()
    local dict = vim.fn.stdpath('config') .. '/lua/utils/docs/dictionary/words.txt'
    local f = io.open(dict, 'r')
    if not f then
      vim.notify('Failed to open dictionary: ' .. dict, vim.log.levels.WARN)
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