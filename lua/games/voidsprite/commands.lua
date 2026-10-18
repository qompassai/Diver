-- /qompassai/Diver/lua/games/voidsprite/commands.lua
-- Qompass AI Voidsprite Commands
--- User commands for voidsprite: `:Voidsprite` menu, `:VoidspriteAction
--- <id>`, and one `:Voidsprite<Id>` per action.
---@module 'games.voidsprite.commands'

local actions = require('games.voidsprite.actions')
local shared_util = require('games.shared.util')

local M = {}

function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end

function M.setup_commands()
    vim.api.nvim_create_user_command('Voidsprite', function()
        actions.show_menu()
    end, { desc = 'Open Voidsprite action menu' })
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('VoidspriteAction', function(cmd_opts)
        actions.run_action_by_id(cmd_opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run a Voidsprite action by id',
    })

    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Voidsprite' .. shared_util.snake_to_pascal(action.id)
        vim.api.nvim_create_user_command(command_name, function()
            actions.run_action(action)
        end, { desc = action.label })
    end
end

function M.setup_keymaps()
    local map = vim.keymap.set
    map('n', '<leader>gve', actions.open_in_editor, {
        desc = 'Voidsprite: Open in editor',
    })
    map('n', '<leader>gvi', actions.import_into_tic80, {
        desc = 'Voidsprite: Import PNG sprite sheet into TIC-80 cart',
    })
    map('n', '<leader>gvm', actions.show_menu, {
        desc = 'Voidsprite: Action menu',
    })
end

return M
