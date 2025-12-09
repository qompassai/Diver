-- /qompassai/Diver/lua/plugins/core/flash.lua
-- Qompass AI Diver Flash Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
  'folke/flash.nvim',
  config = function()
    require('config.core.flash').flash_cfg()
  end,
}
