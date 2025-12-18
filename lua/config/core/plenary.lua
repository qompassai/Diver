-- /qompassai/Diver/lua/config/core/plenary.lua
-- Qompass AI Plenary Utility Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@meta
---@module 'config.core.plenary'
local M = {}
require('types.core.plenary')
function M.collect_nls_sources()
  local scandir = require('plenary.scandir')
  local Path = require('plenary.path')
  local lang_path = vim.fn.stdpath('config') .. '/lua/config/lang'
  local global_need_check = nil
  local files = scandir.scan_dir(lang_path, {
    depth = 1,
    add_dirs = false
  })
  local nls_sources = {}
  for _, file_path in ipairs(files) do
    local file = Path:new(file_path)
    local lang, mod_name
    if type(file) == 'table' and type(file.stem) == 'function' and type(file.make_relative) == 'function' then
      lang = file:stem()
      mod_name = file:make_relative(vim.fn.stdpath('config') .. '/lua/'):gsub('%.lua$', ''):gsub('/', '.')
    else
      vim.notify('Invalid Path object for ' .. tostring(file_path), vim.log.levels.WARN)
      goto continue
    end
    local ok, mod = pcall(require, mod_name)
    if not ok or type(mod) ~= 'table' then
      vim.notify('Could not require module: ' .. tostring(mod_name), vim.log.levels.WARN)
    else
      local fn_name = lang .. '_nls'
      local nls_fn = mod[fn_name]
      local need_check = mod.need_check
      if need_check == nil then
        need_check = global_need_check
      end
      if need_check ~= false and type(nls_fn) == 'function' then
        local success, sources = pcall(nls_fn, need_check)
        if success and type(sources) == 'table' then
          vim.list_extend(nls_sources, sources)
        else
          vim.notify('Failed to call ' .. fn_name .. ' in ' .. mod_name, vim.log.levels.WARN)
        end
      end
    end
    ::continue::
  end
  return nls_sources
end

return M