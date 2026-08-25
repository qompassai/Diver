-- /qompassai/Diver/lua/plugins/ui/init.lua
-- Qompass AI Diver UI Plugin Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type (string|vim.pack.Spec)[]
local specs = {}
---@param mod string
local function add(mod)
  local ok, result = pcall(require, mod)

  if not ok then
    error(('Failed to load %q:\n%s'):format(mod, result), 2)
  end

  if type(result) ~= 'table' then
    error(('Module %q must return a list of plugin specs; received %s'):format(mod, type(result)), 2)
  end

  if not vim.islist(result) then
    error(('Module %q returned a table, but it is not a list of plugin specs'):format(mod), 2)
  end

  for index, spec in ipairs(result) do
    local spec_type = type(spec)

    if spec_type ~= 'string' and spec_type ~= 'table' then
      error(('Module %q spec #%d must be a string or vim.pack.Spec; received %s'):format(mod, index, spec_type), 2)
    end

    specs[#specs + 1] = spec
  end
end

add('plugins.ui.css')
add('plugins.ui.icons')
add('plugins.ui.md')

return specs