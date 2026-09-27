#!/usr/bin/env lua
-- /qompassai/Diver/lua/email/init.lua
-- Qompass AI Diver Email Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
M.mail = require('email.mail')
M.mime = require('email.mime')

---Initialize the email suite. Safe to call more than once.
---@param opts? table mail.setup options
function M.setup(opts)
    M.mail.setup(opts)
end

return M
