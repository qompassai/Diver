-- /qompassai/Diver/fixers/blackd.lua
-- Qompass AI Blackd Fixer Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.fixer.Config
return {
  cmd = 'curl',
  args = {
    '-s',
    '-X', 'POST',
    'http://127.0.0.1:45484',
    '--data-binary', '@-',
  },
  stdin = true,
  allow_non_zero = false,
}