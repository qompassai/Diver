-- /qompassai/Diver/lua/plugins/data/toggle.lua
-- Qompass AI Diver Toggle Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
  'akinsho/toggleterm.nvim',
  event = 'VeryLazy',
  cmd = { 'ToggleTerm' },
  config = function()
    require('toggleterm').setup({
      size = 20,
      open_mapping = [[<c-\>]],
      direction = 'float'
    })
  end,
}