-- /qompassai/Diver/lua/games/init.lua
-- Qompass AI Games Native Tooling Init
local function safe_require(module)
    local ok, result = pcall(require, module)
    if not ok then
        vim.notify('Failed to load ' .. module .. ': ' .. tostring(result), vim.log.levels.WARN)
        return nil
    end
    return result
end

local M = {}

M.aseprite = safe_require('games.aseprite')
M.blender = safe_require('games.blender')
M.godot = safe_require('games.godot')
M.love2d = safe_require('games.love2d')
M.redot = safe_require('games.redot')
M.robocode = safe_require('games.robocode')
M.tic80 = safe_require('games.tic80')
M.unity = safe_require('games.unity')
M.unreal = safe_require('games.unreal')
M.voidsprite = safe_require('games.voidsprite')

local engines = {
    {
        key = 'aseprite',
        label = 'Aseprite',
    },
    {
        key = 'blender',
        label = 'Blender',
    },
    {
        key = 'godot',
        label = 'Godot',
    },
    {
        key = 'love2d',
        label = 'LÖVE2D',
    },
    {
        key = 'redot',
        label = 'Redot',
    },
    {
        key = 'robocode',
        label = 'Robocode',
    },
    {
        key = 'tic80',
        label = 'TIC-80',
    },
    {
        key = 'unity',
        label = 'Unity',
    },
    {
        key = 'unreal',
        label = 'Unreal',
    },
    {
        key = 'voidsprite',
        label = 'Voidsprite',
    },
}

function M.setup()
    for _, engine in ipairs(engines) do
        local mod = M[engine.key]
        if mod and mod.setup then
            mod.setup()
        end
    end

    vim.api.nvim_create_user_command('Games', function()
        M.show_menu()
    end, {
        desc = 'Open a combined Aseprite/Blender/Godot/LÖVE2D/Redot/Robocode/TIC-80/Unity/Unreal/'
            .. 'Voidsprite action menu',
    })

    vim.api.nvim_create_user_command('GamesDoctor', function()
        vim.cmd('checkhealth games')
    end, {
        desc = "Report every engine's resolved binary/root (Aseprite/Blender/Godot/LÖVE2D/Redot/"
            .. 'Robocode/TIC-80/Unity/Unreal/Voidsprite)',
    })

    vim.keymap.set('n', '<Space>gd', function()
        vim.cmd('checkhealth games')
    end, {
        desc = "Games: report every engine's resolved binary/root",
    })
end

function M.show_menu()
    local combined = {}

    for _, engine in ipairs(engines) do
        local mod = M[engine.key]
        if mod and mod.actions and mod.actions.get_actions then
            for _, action in ipairs(mod.actions.get_actions()) do
                combined[#combined + 1] = {
                    id = engine.key .. ':' .. action.id,
                    label = action.label,
                    group = engine.label,
                    run = action.run,
                }
            end
        end
    end
    require('games.shared.ui').select_root_menu(combined, function(action)
        action.run()
    end, {
        group_order = {
            'Aseprite',
            'Blender',
            'Godot',
            'LÖVE2D',
            'Redot',
            'Robocode',
            'TIC-80',
            'Unity',
            'Unreal',
            'Voidsprite',
        },
        prompt = 'Select a games action:',
    })
end

return M
