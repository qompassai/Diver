-- /qompassai/Diver/lua/mappings/init.lua
-- Diver Mappings init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
M.setup = function()
  local mapping_files = {
    "aimap", --Rose.nvim
    "cicdmap",
    "datamap",
    "ddxmap", -- None-ls diag, nvim-dap, trouble.nvim
    "disable",
    "genmap",
    "langmap",
    "lintmap",
    "mojomap",
    "navmap",
    "pymap",
    "rustmap",
  }
  for _, name in ipairs(mapping_files) do
    local ok, mod = pcall(require, "mappings." .. name)
    if not ok then
      vim.notify("Failed to load: " .. name, vim.log.levels.WARN)
      goto continue
    end
    local custom_setup_fn = "setup_" .. name
    local default_setup_fn = "setup"
    if type(mod[custom_setup_fn]) == "function" then
      mod[custom_setup_fn]()
    elseif type(mod[default_setup_fn]) == "function" then
      mod[default_setup_fn]()
    else
      vim.notify(
        string.format("Mapping '%s' has neither %s() nor %s()", name, custom_setup_fn, default_setup_fn),
        vim.log.levels.WARN
      )
    end
    ::continue::
  end
end
return M
