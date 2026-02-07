#!/usr/bin/env lua
-- /qompassai/Diver/lua/utils/docs/init.lua
-- Qompass AI Docs Utils Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local modules = { ---@version JIT
  'bounty',
  'clipboard',
  'docs',
  'mime'
}
for _, module in ipairs(modules) do
  require('utils.docs.' .. module)
end
return M