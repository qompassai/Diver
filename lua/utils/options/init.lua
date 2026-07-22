#!/usr/bin/env lua

-- init.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://neovim.io/doc/user/quickref/#option-list
local M = {}
function M.setup()
	require('utils.options.buffer')
	require('utils.options.global')
end

return M
