-- /qompassai/Diver/ftdetect/alloy.lua
-- Qompass AI Diver Alloy Filetype Detecter
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.filetype.add({
  pattern = {
    ['.*/*.als'] = 'alloy',
  },
})