-- /qompassai/Diver/lua/ai/rose/commands.lua
-- Rose* user commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The user-facing command surface for native Rose. Registration is
-- idempotent (force = true) and collision-free: every name is prefixed
-- with Rose. The rose module is injected so this file never requires
-- ai.rose.init at the top level.

local M = {}

M.names = {
    'RoseAsk',
    'RoseAgent',
    'RoseCheck',
    'RoseFlow',
    'RoseStop',
}

-- Register (or re-register) the Rose* commands against the given rose module.
---@param rose table the ai.rose entrypoint module
function M.register(rose)
    assert(type(rose) == 'table', 'commands.register: rose module must be a table')
    for _, item in ipairs({
        { 'RoseAsk', rose.ask, 'Ask the configured model (local Ollama by default)' },
        { 'RoseAgent', rose.agent, 'Run planner, coder, validation and reviewer' },
        { 'RoseFlow', rose.flow, 'Run the explicit Flow MCP workflow' },
    }) do
        vim.api.nvim_create_user_command(item[1], function(args)
            item[2](args.args ~= '' and args.args or nil)
        end, { nargs = '*', desc = item[3], force = true })
    end
    vim.api.nvim_create_user_command('RoseCheck', function(args)
        rose.check(args.args ~= '' and args.args or nil)
    end, {
        nargs = '?',
        desc = 'Run required named validation checks',
        force = true,
        complete = function()
            local names = vim.tbl_keys(rose.options and rose.options.checks or {})
            table.sort(names)
            return names
        end,
    })
    vim.api.nvim_create_user_command('RoseStop', function()
        rose.stop()
    end, { desc = 'Cancel Rose requests and close MCP/Flow bridges', force = true })
end

--- Remove every Rose* command this module registers.
function M.unregister()
    for _, name in ipairs(M.names) do
        pcall(vim.api.nvim_del_user_command, name)
    end
end

return M
