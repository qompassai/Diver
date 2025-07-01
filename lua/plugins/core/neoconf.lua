-- /qompassai/Diver/lua/plugins/core/neoconf.lua
-- Qompass AI Diver Neoconf Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------
local neoconf_cfg = require('config.core.neoconf')
return {
  'folke/neoconf.nvim',
  priority = 10000,
  opts     = function() return neoconf_cfg.opts() end,
  config   = function(_, opts) require('neoconf').setup(opts) end,
}
