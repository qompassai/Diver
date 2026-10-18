-- /qompassai/Diver/lua/games/unreal/commands.lua
-- Qompass AI Unreal Commands
---@module 'games.unreal.commands'
local shared_util = require('games.shared.util')
local actions = require('games.unreal.actions')
local M = {}

function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end
function M.setup_commands()

    vim.api.nvim_create_user_command('Unreal', function()
        actions.show_menu()
    end, { desc = 'Open Unreal action menu' })
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('UnrealAction', function(opts)
        actions.run_action_by_id(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run an Unreal action by id',
    })

    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Unreal' .. shared_util.snake_to_pascal(action.id)
        vim.api.nvim_create_user_command(command_name, function()
            actions.run_action(action)
        end, { desc = action.label })
    end
end
function M.setup_keymaps()
    local map = vim.keymap.set
    map('n', '<leader>geb', actions.build_project, {
        desc = 'Unreal: Build',
    })
    map('n', '<leader>gec', actions.cook_only, {
        desc = 'Unreal: Cook only',
    })
    map('n', '<leader>gee', actions.open_editor, {
        desc = 'Unreal: Open editor',
    })
    map('n', '<leader>geg', actions.generate_project_files, {
        desc = 'Unreal: Generate project files',
    })
    map('n', '<leader>gek', actions.package_plugin, {
        desc = 'Unreal: Package editor plugin',
    })
    map('n', '<leader>gel', actions.open_logs, {
        desc = 'Unreal: Open logs',
    })
    map('n', '<leader>gep', actions.package_project, {
        desc = 'Unreal: Package',
    })
    map('n', '<leader>ges', actions.bootstrap_engine_checkout, {
        desc = 'Unreal: Bootstrap fresh engine checkout',
    })
end

return M
