-- /qompassai/lua/dev/apps/android/commands.lua
-- Qompass AI Commands
---@module 'dev.apps.android.commands'
local M = {}
local actions = require('dev.apps.android.actions')
local api = vim.api
local map = vim.keymap.set
function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end

function M.setup_commands()
    local action_list = actions.get_actions()

    api.nvim_create_user_command('Android', function()
        actions.show_menu()
    end, {
        desc = 'Open Android action menu',
    })

    api.nvim_create_user_command('AndroidAction', function(opts)
        actions.run_action_by_id(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return actions.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run an Android action by id',
    })
    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Android' .. actions.snake_to_pascal(action.id)

        api.nvim_create_user_command(command_name, function()
            actions.run_action(action)
        end, {
            desc = action.label,
        })
    end
end

function M.setup_keymaps()
    map('n', '<leader>ab', function()
        actions.run_action_by_id('build_release')
    end, {
        desc = 'Android: Build release',
    })

    map('n', '<leader>ac', function()
        actions.run_action_by_id('clean')
    end, {
        desc = 'Android: Clean project',
    })

    map('n', '<leader>ad', function()
        actions.run_action_by_id('doctor')
    end, {
        desc = 'Android: Run doctor',
    })

    map('n', '<leader>ae', function()
        actions.run_action_by_id('start_emulator')
    end, {
        desc = 'Android: Start emulator',
    })

    map('n', '<leader>ar', function()
        actions.run_action_by_id('run_debug')
    end, {
        desc = 'Android: Run debug',
    })

    map('n', '<leader>as', function()
        actions.run_action_by_id('capture_screen')
    end, {
        desc = 'Android: Capture screen',
    })

    map('n', '<leader>ax', function()
        actions.run_action_by_id('stop_emulator')
    end, {
        desc = 'Android: Stop emulator',
    })
end
return M
