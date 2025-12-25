-- /qompassai/Diver/linter/zlint.lua
-- Qompass AI Diver Zlint Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local pattern = '^::(%w+) file=([^,]+),line=(%d+),col=(%d+),title=([^:]+)::(.+)$'
local groups = {
  'severity',
  'file',
  'lnum',
  'col',
  'code',
  'message',
}
local severity_map = {
  ['error'] = vim.diagnostic.severity.ERROR,
  ['warning'] = vim.diagnostic.severity.WARN,
}
return {
  name = 'zlint',
  cmd = 'zlint',
  args = {
    '--format',
    'github',
  },
  stdin = false,
  append_fname = false,
  stream = 'both',
  ignore_exitcode = true,
  parser = require('lint.parser').from_pattern(pattern, groups, severity_map), ---@type integer
}