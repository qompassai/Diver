-- /qompassai/diver/lua/plugins/ui/css.lua
-- Qompass AI CSS Plugin spec
-- Copyright (c) 2025 Qompass AI, All Rights Reserved
-----------------------------------------------------
local css_cfg = require('config.ui.colors')
return {
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = true,
  },
  {
    'nvchad/nvim-colorizer.lua',
    event = 'BufReadPre',
    config = function(_, opts)
      css_cfg.setup_colorizer(opts)
    end,
  },
}