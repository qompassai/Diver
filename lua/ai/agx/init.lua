-- /qompassai/Diver/lua/ai/agx/init.lua
-- Qompass AI agx Trace Inspector Entry Point (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Wires the agx agent-trace inspector (commands only). Nothing runs at
-- require-time; :Agx opens the TUI lazily in a terminal split.

local M = {}

local configured = false

---@param opts? table Reserved for future options; currently unused.
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'agx.setup expects a table or nil')
    if configured then
        return
    end
    configured = true
    require('ai.agx.commands')
end

return M
