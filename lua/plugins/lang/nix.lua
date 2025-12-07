-- /qompassai/Diver/lua/plugins/lang/nix.lua
-- Qompass AI Diver Nix Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local nix_cfg = require("config.lang.nix")

return {
  {
    'LnL7/vim-nix',
    ft = {
      'nix'
    },
    config = function()
      nix_cfg.vim_nix_config()
    end,
  },
}