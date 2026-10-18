-- /qompassai/lua/dev/apps/android/init.lua
-- Qompass AI Init
local M = {}
M.actions = require('dev.apps.android.actions')
M.bsp = require('dev.apps.android.bsp')
M.commands = require('dev.apps.android.commands')
M.config = require('dev.apps.android.config')
M.devices = require('dev.apps.android.devices')
M.doctor = require('dev.apps.android.doctor')
M.fdroid = require('dev.apps.android.fdroid')
M.gradle = require('dev.apps.android.gradle')
M.matrix = require('dev.apps.android.matrix')
M.output = require('dev.apps.android.output')
M.recent = require('dev.apps.android.recent')
M.subsystems = require('dev.apps.android.subsystems')
M.ui = require('dev.apps.android.ui')
M.util = require('dev.apps.android.util')
M.run_action_by_id = M.actions.run_action_by_id

function M.setup()
    M.commands.setup()
end

M.show_menu = M.actions.show_menu
return M
