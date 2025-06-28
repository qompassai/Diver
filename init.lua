-- /qompassai/Diver/init.lua
-- Qompass AI Diver Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'
local utils = require('utils.safe_require')
_G.safe_require = utils.safe_require
require('utils')
require('types')
require('config.init').config()
