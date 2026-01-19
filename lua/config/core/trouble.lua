-- /qompassai/Diver/lua/config/core/trouble.lua
-- Qompass AI Diver Core Trouble Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@param opts? TroubleOptions
---@return TroubleOptions
return function(opts)
    opts = opts or {}
    return vim.tbl_deep_extend('force', {
        auto_close = true,
        auto_open = true,
        position = 'bottom',
        height = 10,
        use_diagnostic_signs = true,
    }, opts)
end
