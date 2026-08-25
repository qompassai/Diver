-- /qompassai/Diver/lua/fixers/gofumpt.lua
-- Qompass AI Diver Gofumpt Fixer Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.fixer.Config
return {
    cmd = 'gofumpt',
    args = {},
    stdin = true,
    allow_non_zero = false,
}
