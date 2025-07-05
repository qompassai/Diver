-- ~/.config/nvim/lua/config/core/plenary.lua
-- Qompass AI Plenary Utility Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}

function M.collect_nls_sources()
  local scandir = require("plenary.scandir")
  local Path = require("plenary.path")
  local lang_path = vim.fn.stdpath("config") .. "/lua/config/lang"
  local files = scandir.scan_dir(lang_path, { depth = 1, add_dirs = false })
  local nls_sources = {}
  for _, file_path in ipairs(files) do
    local file = Path:new(file_path)
    local mod_name = file:make_relative(vim.fn.stdpath("config") .. "/lua/")
                        :gsub("%.lua$", ""):gsub("/", ".")
    local ok, mod = pcall(require, mod_name)
    if ok and type(mod) == "table" then
      local lang = file:stem()
      local fn_name = lang .. "_nls"
      local nls_fn = mod[fn_name]
      if type(nls_fn) == "function" then
        local success, sources = pcall(nls_fn)
        if success and type(sources) == "table" then
          vim.list_extend(nls_sources, sources)
        else
          vim.notify("Failed to call " .. fn_name .. " in " .. mod_name, vim.log.levels.WARN)
        end
      end
    else
      vim.notify("Could not require module: " .. mod_name, vim.log.levels.WARN)
    end
  end
  return nls_sources
end
return M
