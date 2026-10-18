-- /qompassai/Diver/lua/games/aseprite/init.lua
-- Qompass AI Aseprite Native Tooling
-- Native Aseprite tooling: launch the editor against the current
-- sprite, batch-export sheets/sequences/GIFs, and run headless Lua
-- scripts through Aseprite's own `-b`/`--script` CLI -- no plugin.
local M = {}
M.actions = require('games.aseprite.actions')
M.commands = require('games.aseprite.commands')

M.config = require('games.aseprite.config')
M.util = require('games.aseprite.util')

function M.setup()
    M.commands.setup()
end
M.run_action_by_id = M.actions.run_action_by_id

M.show_menu = M.actions.show_menu

return M
