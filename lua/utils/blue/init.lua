#!/usr/bin/env lua5.1 JIT
-- /qompassai/Diver/lua/utils/blue/init.lua
-- Qompass AI Diver BlueTeam Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
require('utils.blue.base64')
require('utils.blue.gpg')
require('utils.blue.sops').setup({
  supported_file_formats = {
    '*.enc.yaml',
    '*.enc.yml',
  },
})
require('utils.blue.ssh').setup({
  ssh_binary = 'ssh',
  scp_binary = 'scp',
  notify_prefix = '[Blue SSH] ',
})
require('utils.blue.dap').setup()

return M