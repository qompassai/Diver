-- /qompassai/Diver/lua/plugins/core/flash.lua
-- Qompass AI Diver Flash Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local cfg = require('config.core.flash')
return {
 "folke/flash.nvim",
  event  = 'VeryLazy',
  config = function()
    cfg.flash_cfg()
  end,
}
