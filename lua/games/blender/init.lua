-- /qompassai/Diver/lua/games/blender/init.lua
-- Qompass AI Blender Native Tooling
-- Native Blender tooling: headless still/turntable rendering,
-- glTF/FBX export, sprite-sheet baking with a JSON manifest, and
-- batch runs over .blend directories -- all through `blender -b`,
-- no plugin. (Engine wiring into games/init.lua happens in a later
-- integration pass; see the track report for the snippet.)
local M = {}
M.actions = require('games.blender.actions')
M.batch = require('games.blender.batch')
M.commands = require('games.blender.commands')

M.config = require('games.blender.config')
M.export = require('games.blender.export')
M.health = require('games.blender.health')
M.render = require('games.blender.render')
M.sprites = require('games.blender.sprites')
M.versions = require('games.blender.versions')

function M.setup()
    M.commands.setup()
end
M.run_action_by_id = M.actions.run_action_by_id

M.show_menu = M.actions.show_menu

return M
