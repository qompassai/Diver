-- /qompassai/Diver/lua/games/redot/init.lua
-- Qompass AI Redot Native Tooling
local factory = require('games.shared.godot_engine')
return factory.new({
    binaries = {
        'redot4',
        'redot',
        'Redot',
        'Redot_v4',
    },
    command_prefix = 'Redot',
    env_names = {
        'NVIM_REDOT_BIN',
        'REDOT_BIN',
        'REDOT4_BIN',
    },
    leader = '<leader>gr',
    name = 'Redot',
    output_filetype = 'redot-output',
    root_markers = {
        'project.godot',
    },
})
