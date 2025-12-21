-- /qompassai/Diver/lua/types/autocmds.lua
-- Qompass AI Diver Autocommand Types Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'types.core.autocmds'
local M = {}
---@class                             Autocmds
---@field                             md_autocmds? fun()
---@field                             go_autocmds? fun()
---@field                             nix_autocmds? fun(opts?: table)
---@field                             vim_nix_config? fun()

return M