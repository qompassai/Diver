-- htmlhint.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local pattern = '.*: line (%d+), col (%d+), (%a+) %- (.+) %((.+)%)'
local groups = { 'lnum', 'col', 'severity', 'message', 'code' }
local severities = {
  error = vim.diagnostic.severity.ERROR, ---@type integer
  warning = vim.diagnostic.severity.WARN, ---@type integer
}

return {
  cmd = 'htmlhint',
  stdin = true,
  args = {
    'stdin',
    '-f',
    'compact',
  },
  stream = 'stdout',
  ignore_exitcode = true,
  parser = require('lint.parser').from_pattern(pattern, groups, severities, { source = 'htmlhint' }), ---@type string
}