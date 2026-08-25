#!/usr/bin/env lua

-- /qompassai/Diver/lua/utils/ux/init.lua
-- Qompass AI User Experience(UX) Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {} ---@version JIT
require('utils.ux.nb')
require('utils.ux.ui')
require('utils.ux.w3m')
function M.setup(opts)
  opts = opts or {}
  M.ui.setup(opts.ui or {})
end

return M
