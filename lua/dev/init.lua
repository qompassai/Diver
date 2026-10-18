-- /qompassai/diver/lua/dev/init.lua
-- Qompass AI Dev Utils Init
local M = {}
local android = require('dev.apps.android')
local apps = require('dev.apps')
local sf = require('dev.sf')
-- dev/vulkan.lua (leaf utilities) shadows dev/vulkan/init.lua (the suite)
-- in the require search order, so name the suite explicitly.
local vulkan = require('dev.vulkan.init')
function M.setup()
    require('dev.ansible').setup()
    require('dev.audio')
    require('dev.book').setup()
    require('dev.bootdev').setup()
    require('dev.bsp')
    require('dev.docs').setup()
    require('dev.git').setup()
    require('dev.jj').setup()
    require('dev.scip')
    require('dev.test').setup()
    android.setup()
    apps.setup()
    sf.setup()
    vulkan.setup()
end

return M
