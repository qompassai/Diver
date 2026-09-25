#!/usr/bin/env luajit
---@version >5.1
-- /qompassai/Diver/lua/types/ui/icons.lua
-- Qompass AI Diver UI Icon Types
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
local M = {}
---@class                    nerdy.config
---@field copy_to_clipboard                                boolean
---@field max_recents                                      integer
M.config = {
    copy_to_clipboard = false,
    copy_register = '+',
    max_recents = 30,
}
M.setup = function(opts)
    M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end
return M
