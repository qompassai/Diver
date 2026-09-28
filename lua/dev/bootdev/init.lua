-- /qompassai/Diver/lua/dev/bootdev/init.lua
-- Qompass AI bootdev-local Launcher Entry Point (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Wires the bootdev-local lesson runner (commands only). Nothing runs at
-- require-time; :Bootdev opens the CLI lazily in a terminal split.

local M = {}

local configured = false

---@param opts? table Reserved for future options; currently unused.
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'bootdev.setup expects a table or nil')
    if configured then
        return
    end
    configured = true
    require('dev.bootdev.commands')
end

return M
