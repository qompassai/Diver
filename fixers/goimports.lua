-- /qompassai/Diver/lua/fixers/goimports.lua
-- Qompass AI Diver Goimports Fixer Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.fixer.Config
return {
  cmd = 'goimports',
  args = {
  },
  stdin = true,
  allow_non_zero = false,
}