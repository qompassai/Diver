#!/usr/bin/env lua5.1
-- /home/phaedrus/.config/nvim/lua/conf/ui/init.lua
-- Qompass AI Diver UI Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}

local startup_modules = {
	'colors',
	'decor',
	'float',
	'icons',
	'image',
	'illuminate',
	'line',
	'nerd',
	'padding',
	'render',
	'themes',
}
function M.setup()
	for _, module in ipairs(startup_modules) do
		require('config.ui.' .. module)
	end
	local render = require('config.ui.render')
	render.config.auto_enable.markdown = true
	render.config.auto_enable.html = true
	render.config.auto_enable.css = true
	render.config.auto_enable.latex = true
	render.config.auto_enable.image = true
	render.config.auto_enable.video = false
end

return M
