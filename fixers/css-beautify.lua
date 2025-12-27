-- /qompassai/Diver/lua/fixers/css-beautify.lua
-- Qompass AI Diver CSS-Beautify Fixer Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.fixer.Config
return {
  cmd = 'css-beautify',
  args = {
    '--stdin',
    '--indent-size', '2',
    '--end-with-newline',
  },
  stdin = true,
  allow_non_zero = false,
}