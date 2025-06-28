-- /qompassai/Diver/lua/config/keymaps.lua
-- Qompass AI Diver Keymaps Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local safe_require = _G.safe_require
M.setup = function()
    local mappings = safe_require('mappings')
    if mappings then mappings.setup() end
end
return M
