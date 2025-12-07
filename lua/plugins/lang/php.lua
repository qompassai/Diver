-- /qompassai/Diver/lua/plugins/lang/php.lua
-- Qompass AI Diver PHP Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
  "ta-tikoma/php.easy.nvim",
  dependencies = {
    "L3MON4D3/LuaSnip",
  },
  opts = {
    onAppend = {
      engine = "LuaSnip",
    },
  },
}
