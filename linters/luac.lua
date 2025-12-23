-- /qompassai/Diver/linters/joker.lua
-- Qompass AI Joker Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  cmd = 'luac',
  stdin = true,
  append_fname = false,
  args = { '-p', '-' },
  stream = 'stderr',
  ignore_exitcode = true,
  parser = require('lint.parser').from_errorformat('luac:\\ stdin:%l:\\ %m,%-G%.%#', { ---@type string[]
    source = 'luac',
    severity = vim.diagnostic.severity.ERROR, ---@type string
  }),
}