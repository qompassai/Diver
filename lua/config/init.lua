-- /qompassai/Diver/lua/config/init.lua
-- Qompass AI Diver Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@module 'config.init'
---@class ConfigInitModule
---@field config fun(opts?: table): nil
local M = {}
---@param opts? table
---@return nil
function M.config(opts)
  opts = opts or {}
  local verbose = opts.debug or false
  local function safe_require(name)
    local ok, mod = pcall(require, name)
    if not ok then
      if verbose then
        vim.notify(string.format('[Diver] Failed to load %s: %s', name,
          mod), vim.log.levels.ERROR)
      end
      return nil
    end
    if verbose then
      vim.notify(string.format('[Diver] Loaded %s', name),
        vim.log.levels.INFO)
    end
    return mod
  end
  safe_require('config.options')
  safe_require('config.autocmds')
  local keys = safe_require('config.keymaps')
  if keys and keys.setup then keys.setup() end
  safe_require('config.lazy')
  if opts.core ~= false then
    local core = safe_require('config.core')
    if core and core.core_config then core.core_config(opts) end
  end
	if opts.cicd ~= false then
    local cicd = safe_require('config.cicd')
    if cicd and cicd.cicd_config then cicd.cicd_config(opts) end
  end
	 if opts.cloud ~= false then
    local cloud = safe_require('config.cloud')
    if cloud and cloud.cloud_config then cloud.cloud_config(opts) end
  end
	 if opts.edu ~=false then
    local edu = safe_require('config.edu')
    if edu and edu.edu_config then edu.edu_config(opts) end
  end
  if opts.lang ~= false then
    local lang = safe_require('config.lang')
    if lang and lang.lang_config then lang.lang_config(opts) end
  end
	  if opts.nav ~= false then
    local nav = safe_require('config.nav')
    if nav and nav.nav_config then nav.nav_config(opts) end
  end
  if opts.ui ~= false then
    local ui = safe_require('config.ui')
    if ui and ui.ui_config then ui.ui_config(opts) end
  end

end

return M
