-- /qompassai/Diver/lua/utils/options/init.lua
-- Qompass AI Diver Options
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--- The two option phases init.lua calls. Phase 1 runs before plugins load
--- (buffer-local options + vim.g); phase 2 runs after (global + window).
--- Splitting them keeps setup-time reads honest: nothing observes a value
--- earlier than init.lua used to set it.
---@module 'utils.options'

local M = {}

--- Phase 1 (early): buffer-local options and global variables.
--- Safe to call once per session; idempotent.
function M.setup_early()
    require('utils.options.buffer').setup()
    require('utils.options.globals').setup()
end

--- Phase 2 (late): global options and window-local options.
--- Safe to call once per session; idempotent.
function M.setup_late()
    require('utils.options.global').setup()
    require('utils.options.window').setup()
end

return M
