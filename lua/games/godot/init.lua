-- /qompassai/Diver/lua/games/godot/init.lua
-- Qompass AI Godot Native Tooling
-- Native Godot 4 tooling: editor/project-manager launch, running the
-- project or the current scene, headless script checks, and
-- release/debug export -- all without an external plugin.
local factory = require('games.shared.godot_engine')

return factory.new({
    binaries = { 'godot4', 'godot', 'Godot', 'Godot_v4' },
    command_prefix = 'Godot',
    env_names = { 'NVIM_GODOT_BIN', 'GODOT_BIN', 'GODOT4_BIN' },
    leader = '<leader>gg',
    name = 'Godot',
    output_filetype = 'godot-output',
    root_markers = { 'project.godot' },
})
