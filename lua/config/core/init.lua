-- /qompassai/Diver/lua/config/init.lua
-- Qompass AI Diver Core Config Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
require('config.core.async')
require('config.core.filetype')
-- Deferred: config.core.lint loads on BufReadPre via init.lua (saves ~8ms).
-- require('config.core.lint')
require('config.core.lsp')
require('config.core.parser')
require('config.core.qf')
require('config.core.refactor')
require('config.core.tree')
require('config.core.whichkey')
