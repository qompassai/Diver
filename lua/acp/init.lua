-- /qompassai/Diver/lua/acp/init.lua
-- Qompass AI ACP Entry Point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Wires the Agent Client Protocol modules (registry, rpc, protocol,
-- session, permissions, store, ui, commands, health) and the unrelated
-- Agent Context Protocol module (context.lua) into one setup() entrypoint.
-- Nothing in this file does I/O at require-time; commands.lua registers
-- the actual user commands, and every session is spawned lazily on demand.

local api = vim.api

local M = {}

local group

---@param opts? table Reserved for future options; currently unused.
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'acp.setup expects a table or nil')

    require('acp.commands')

    if group then
        return
    end
    group = api.nvim_create_augroup('AcpLifecycle', { clear = true })
    api.nvim_create_autocmd('VimLeavePre', {
        group = group,
        callback = function()
            require('acp.session').stop_all()
        end,
        desc = 'Stop all ACP agent sessions on exit',
    })
end

return M
