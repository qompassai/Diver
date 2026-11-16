-- /qompassai/Diver/lua/games/wasm4/commands.lua
-- Qompass AI WASM-4 Commands
--- User commands for WASM-4: `:Wasm4` menu, `:Wasm4Action <id>`, one
--- `:Wasm4<Id>` per action, plus argument-taking `:Wasm4Run` and
--- `:Wasm4Png2Src` variants force-registered after the generated ones
--- (the legacy-command pattern from games.tic80.commands).
---@module 'games.wasm4.commands'

local actions = require('games.wasm4.actions')
local shared_util = require('games.shared.util')

local M = {}

---Convert an action id to PascalCase for the generated command names.
---shared_util.snake_to_pascal leaves the first letter lowercase (its
---`^` anchor sits inside the capture group, so it never matches),
---which would name these `:Wasm4build` etc.; convert locally so the
---generated names are the documented `:Wasm4<Id>` forms.
---@param id string Action id in snake_case.
---@return string id in PascalCase.
local function pascal_case(id)
    local pascal = id:gsub('_(%l)', function(letter)
        return letter:upper()
    end)
    return (pascal:gsub('^%l', string.upper))
end

function M.setup()
    M.setup_commands()
    M.setup_keymaps()
end

function M.setup_commands()
    vim.api.nvim_create_user_command('Wasm4', function()
        actions.show_menu()
    end, { desc = 'Open WASM-4 action menu' })
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command('Wasm4Action', function(cmd_opts)
        actions.run_action_by_id(cmd_opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return shared_util.get_action_ids(action_list, arg_lead)
        end,
        desc = 'Run a WASM-4 action by id',
    })

    for i = 1, #action_list do
        local action = action_list[i]
        local command_name = 'Wasm4' .. pascal_case(action.id)
        vim.api.nvim_create_user_command(command_name, function()
            actions.run_action(action)
        end, { desc = action.label })
    end

    -- Argument-taking variants: force replaces the generated commands
    -- of the same name so both spellings keep one behavior.
    vim.api.nvim_create_user_command('Wasm4Png2Src', function(cmd_opts)
        actions.png2src(cmd_opts.fargs)
    end, {
        nargs = '*',
        complete = 'file',
        force = true,
        desc = 'WASM-4: convert sprite PNGs to source code',
    })

    vim.api.nvim_create_user_command('Wasm4Run', function(cmd_opts)
        local target = cmd_opts.args
        if target == '' then
            actions.run_cart()
        else
            actions.run_cart(vim.fn.expand(target))
        end
    end, {
        nargs = '?',
        complete = 'file',
        force = true,
        desc = 'WASM-4: run a built cart; defaults to the current project cart',
    })
end

function M.setup_keymaps()
    local map = vim.keymap.set
    map('n', '<leader>gwb', function()
        actions.build_cart()
    end, {
        desc = 'WASM-4: Build cart',
    })
    map('n', '<leader>gwm', actions.show_menu, {
        desc = 'WASM-4: Action menu',
    })
    map('n', '<leader>gwr', function()
        actions.run_cart()
    end, {
        desc = 'WASM-4: Run cart',
    })
    map('n', '<leader>gww', actions.watch_cart, {
        desc = 'WASM-4: Watch (rebuild + web runtime)',
    })
end

return M
