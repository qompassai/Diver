-- /qompassai/Diver/lua/plugins/ui/init.lua
-- Qompass AI Diver UI Plugin Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local specs = {}
local function add(mod)
  local ok, t = pcall(require, mod)
  assert(ok, ('require(%s) failed'):format(mod))
  assert(type(t) == 'table', ('module %s must return a table, got %s'):format(mod, type(t)))
  for _, s in ipairs(t) do
    specs[#specs + 1] = s
  end
end
add('plugins.ui.css')
add('plugins.ui.icons')
add('plugins.ui.md')
add('plugins.ui.bufferline')
add('plugins.ui.noice')
add('plugins.ui.themes')

return specs
