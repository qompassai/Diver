-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Diver Utils Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M        = {}

M.safe_require = require("utils.safe_require").safe_require
M.clipboard    = require("utils.clipboard").setup()
M.environ      = require("utils.environ")
M.ui           = require("utils.ui")
M.dictionary   = {
  path = vim.fn.stdpath("config") .. "/lua/utils/dictionary",
  file = "words.txt",
  load_words = function()
    local dict = vim.fn.stdpath("config") .. "/lua/utils/dictionary/words.txt"
    local f = io.open(dict, "r")
    if not f then
      vim.echo("[Diver] Failed to open dictionary: " .. dict,
        vim.log.levels.WARN)
      return {}
    end
    local t = {}
    for line in f:lines() do t[#t + 1] = line end
    f:close()
    return t
  end,
}

M.lang         = setmetatable({}, {
  __index = function(tbl, key)
    local ok, mod = pcall(require, "utils.lang." .. key)
    if not ok then
      error(("utils.lang: module '%s' not found: %s"):format(key, mod))
    end
    rawset(tbl, key, mod)
    return mod
  end,
})
M.lang.lua     = require("utils.lang.lua")
return M