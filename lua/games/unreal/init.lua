-- /qompassai/Diver/lua/games/unreal/init.lua
-- Qompass AI Unreal Native Tooling
local M = {}
M.actions = require('games.unreal.actions')
M.commands = require('games.unreal.commands')

M.config = require('games.unreal.config')
M.util = require('games.unreal.util')
function M.setup()
    M.commands.setup()
end
M.run_action_by_id = M.actions.run_action_by_id

M.show_menu = M.actions.show_menu

return M
