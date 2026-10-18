-- /qompassai/Diver/lua/games/robocode/commands.lua
-- Qompass AI Robocode Commands
---@module 'games.robocode.commands'
-- User commands and keymaps for games.robocode. Wires the action list
-- from actions.lua into :Robocode* commands and <leader>gc* keymaps
-- (<leader>gr* belongs to Redot; gc = robocode's "code").
local actions = require('games.robocode.actions')
local shared_util = require('games.shared.util')

local M = {}

function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end

function M.setup_commands()
    vim.api.nvim_create_user_command('Robocode', function()
        actions.show_menu()
    end, { desc = 'Open Robocode action menu' })

    vim.api.nvim_create_user_command('RobocodeBattle', function()
        actions.run_battle()
    end, { desc = 'Pick robots and run a headless battle' })

    vim.api.nvim_create_user_command('RobocodeGUI', function()
        actions.open_gui()
    end, { desc = 'Open the Robocode GUI' })

    vim.api.nvim_create_user_command('RobocodeNew', function()
        actions.new_robot()
    end, { desc = 'Scaffold a new robot from the Robocode template and compile it' })

    vim.api.nvim_create_user_command('RobocodeStop', function()
        actions.stop_battle()
    end, { desc = 'Stop the running battle or GUI' })
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('RobocodeAction', function(opts)
        actions.run_action_by_id(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run a Robocode action by id',
    })
end

function M.setup_keymaps()
    local map = vim.keymap.set
    map('n', '<leader>gcb', actions.run_battle, { desc = 'Robocode: Run battle' })
    map('n', '<leader>gcd', actions.doctor, { desc = 'Robocode: Doctor' })
    map('n', '<leader>gcg', actions.open_gui, { desc = 'Robocode: Open GUI' })

    map('n', '<leader>gcn', actions.new_robot, { desc = 'Robocode: New robot' })
    map('n', '<leader>gcs', actions.stop_battle, { desc = 'Robocode: Stop battle' })
end

return M
