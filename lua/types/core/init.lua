#!/usr/bin/env lua
-- /qompassai/Diver/lua/types/config/core/init.lua
-- Qompass AI Diver Core Config Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {} ---@version JIT
require('types.core.autocmds')
require('types.core.cmp')
require('types.core.fixer')
require('types.core.lazy')
require('types.core.lint')
require('types.core.lsp')
require('types.core.plenary')
require('types.core.plugins')
require('types.core.quickfix')
require('types.core.schema')
require('types.core.tree')
require('types.core.trouble')
return M
