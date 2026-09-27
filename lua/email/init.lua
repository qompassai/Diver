#!/usr/bin/env lua
-- /qompassai/Diver/lua/email/init.lua
-- Qompass AI Diver Email Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
M.mail = require('email.mail')
M.mime = require('email.mime')
M.clients = require('email.clients')

---Initialize the email suite. Safe to call more than once.
---@param opts? table mail.setup options; opts.clients feeds clients.setup
function M.setup(opts)
    M.mail.setup(opts)
    M.clients.setup(opts ~= nil and opts.clients or nil)
end

return M
