-- /qompassai/Diver/init.lua
-- Qompass AI Diver Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'
vim.env.FONTCONFIG_DEBUG = "none"
require('config.init').config({
	core = true,
	cicd = true,
	cloud = true,
	debug = false,
	edu = true,
	nav = true,
	ui = true
})
require('utils')
require('types')
