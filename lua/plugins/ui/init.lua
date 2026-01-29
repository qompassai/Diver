-- /qompassai/Diver/lua/plugins/ui/init.lua
-- Qompass AI Diver UI Plugin Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    require('plugins.ui.css'),
    require('plugins.ui.icons'),
    require('plugins.ui.md'),
    require('plugins.ui.line'),
    require('plugins.ui.bufferline'),
    require('plugins.ui.noice'),
    require('plugins.ui.themes'),
}

--[[

local specs = {}
local function add(mod)
  local ok, t = pcall(require, mod)
  assert(ok, ('require(%s) failed'):format(mod))
  assert(type(t) == 'table', ('module %s must return a table, got %s'):format(mod, type(t)))
  for _, s in ipairs(t) do
    specs[#specs + 1] = s
  end
end
add('plugins.ui.icons')
add('plugins.ui.md')
add('plugins.ui.line')
add('plugins.ui.bufferline')
add('plugins.ui.noice')
add('plugins.ui.themes')
add('plugins.ui.css')
return specs


--]]