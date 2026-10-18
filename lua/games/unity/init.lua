-- /qompassai/Diver/lua/games/unity/init.lua
-- Qompass AI Unity Native Tooling
-- Native Unity tooling: resolves the Hub-installed Editor version
-- matching ProjectSettings/ProjectVersion.txt, then launches, builds
-- (-batchmode -executeMethod), tests, and reimports without a plugin.
local M = {}
M.actions = require('games.unity.actions')
M.commands = require('games.unity.commands')

M.config = require('games.unity.config')
M.util = require('games.unity.util')

function M.setup()
    M.commands.setup()
end
M.run_action_by_id = M.actions.run_action_by_id

M.show_menu = M.actions.show_menu

return M
