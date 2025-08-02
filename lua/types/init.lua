-- /qompassai/Diver/lua/types/init.lua
-- Qompass AI Types Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
----------------------------------------
local M = {}
vim.schedule(function()
  local ok, scandir = pcall(require, "plenary.scandir")
  if not ok then
    vim.notify("Failed to load plenary.scandir", vim.log.levels.WARN)
    return
  end
  local function load_dir(mod_path, prefix)
    local result = {}
    for _, file in ipairs(scandir.scan_dir(mod_path, { depth = 1 })) do
      local name = vim.fn.fnamemodify(file, ":t:r")
      result[name] = require(prefix .. "." .. name)
    end
    return result
  end
  local types_path = vim.fn.stdpath("config") .. "/lua/types"
  M.config         = load_dir(types_path .. "/config", "types.config")
  M.edu            = load_dir(types_path .. "/edu", "types.edu")
  M.lang           = load_dir(types_path .. "/lang", "types.lang")
  M.mappings       = load_dir(types_path .. "/mappings", "types.mappings")
  M.ui             = load_dir(types_path .. "/ui", "types.ui")
  M.core           = load_dir(types_path .. "/core", "types.core")
  M.cicd           = load_dir(types_path .. "/cicd", "types.cicd")
end)
return M
