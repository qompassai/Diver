#!/usr/bin/env lua
-- /qompassai/Diver/lua/types/init.lua
-- Qompass AI Diver Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {} ---@version JIT
require('types.config.core.autocmds')
require('types.config.core.cmp')
require('types.config.core.fixer')
require('types.config.core.lint')
require('types.config.core.lsp')
require('types.config.core.plenary')
require('types.config.core.plugins')
require('types.config.core.quickfix')
require('types.config.core.schema')
require('types.config.core.tree')
require('types.config.core.trouble')
require('types.config.lazy')
--[[
require('types.lang.c')
require('types.lang.cmp')
require('types.lang.cpp')
require('types.lang.go')
require('types.lang.lua')
require('types.lang.nix')
require('types.lang.python')
require('types.lang.ts')
require('types.lang.zig')
require('types.ui.colors')
require('types.ui.html')
require('types.ui.icons')
require('types.ui.line')
require('types.ui.md')
--]]
require('types.utils.media.encoder')
require('types.utils.media.rpc')
require('types.utils.red.red')
require('types.utils.sec.gpg')
require('types.utils.unreal')
require('types.utils.vulkan')
require('types.utils.wp')
require('types.nvim')
return M