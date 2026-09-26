-- /qompassai/Diver/lua/ai/a2a/init.lua
-- Qompass AI A2A Entry Point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Wires the Agent2Agent console modules (agent_card, client, tasks,
-- fanout, ui, sdks, commands) into one setup() entrypoint. Nothing in this
-- file does I/O at require-time; commands.lua registers the actual
-- user commands, tasks are dispatched lazily on demand, and every
-- in-flight task is canceled on VimLeavePre so no agent is orphaned
-- when the editor exits.

local api = vim.api

local M = {}

local group

---@param opts? table Reserved for future options; currently unused.
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'a2a.setup expects a table or nil')

    require('ai.a2a.commands')
    require('ai.a2a.sdks').setup()

    if group then
        return
    end
    group = api.nvim_create_augroup('A2aLifecycle', { clear = true })
    api.nvim_create_autocmd('VimLeavePre', {
        group = group,
        callback = function()
            require('ai.a2a.tasks').cancel_all()
        end,
        desc = 'Cancel all A2A agent tasks on exit',
    })
end

return M
