#!/usr/bin/env lua5.1 JIT
-- /qompassai/Diver/lua/security/blue/init.lua
-- Qompass AI Diver BlueTeam Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
require('security.blue.base64')
require('security.blue.gpg')
require('security.blue.sops').setup({
    supported_file_formats = {
        '*.enc.yaml',
        '*.enc.yml',
    },
})
require('security.blue.ssh').setup({
    ssh_binary = 'ssh',
    scp_binary = 'scp',
    notify_prefix = '[Blue SSH] ',
})
require('security.blue.dap').setup()

return M
