-- /qompassai/Diver/lua/games/aseprite/commands.lua
-- Qompass AI Aseprite Commands
---@module 'games.aseprite.commands'
local actions = require('games.aseprite.actions')
local shared_util = require('games.shared.util')
local M = {}
function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end
function M.setup_commands()
    vim.api.nvim_create_user_command('Aseprite', function()
        actions.show_menu()
    end, { desc = 'Open Aseprite action menu' })
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('AsepriteAction', function(opts)
        actions.run_action_by_id(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run an Aseprite action by id',
    })

    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Aseprite' .. shared_util.snake_to_pascal(action.id)
        vim.api.nvim_create_user_command(command_name, function()
            actions.run_action(action)
        end, { desc = action.label })
    end
end

function M.setup_keymaps()
    local map = vim.keymap.set
    map('n', '<leader>gaP', actions.build_sprite_prompt, {
        desc = 'Aseprite: Build AI sprite prompt',
    })
    map('n', '<leader>gab', actions.batch_import, {
        desc = 'Aseprite: Batch import AI art directory',
    })
    map('n', '<leader>gae', actions.open_in_editor, {
        desc = 'Aseprite: Open editor',
    })
    map('n', '<leader>gag', actions.export_gif, {
        desc = 'Aseprite: Export GIF',
    })
    map('n', '<leader>gai', actions.import_art, {
        desc = 'Aseprite: Import AI art → clean sprite',
    })
    map('n', '<leader>gan', actions.new_sprite, {
        desc = 'Aseprite: New sprite',
    })
    map('n', '<leader>gap', actions.export_palette, {
        desc = 'Aseprite: Export palette (.gpl)',
    })
    map('n', '<leader>gar', actions.run_script, {
        desc = 'Aseprite: Run script',
    })
    map('n', '<leader>gas', actions.export_sprite_sheet, {
        desc = 'Aseprite: Export sprite sheet',
    })
    map('n', '<leader>gat', actions.export_sheet_type_preset, {
        desc = 'Aseprite: Export tileset (choose sheet type)',
    })
    map('n', '<leader>gay', actions.sync_palette_to_user_config, {
        desc = 'Aseprite: Sync palette to user config',
    })
end
return M
