-- /qompassai/Diver/linters/writegood.lua
-- Qompass AI WriteGood Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = 'write-good',
    stdin = false,
    args = { '--parse' },
    stream = 'stdout',
    ignore_exitcode = true,
    env = nil,

    parser = require('lint.parser').from_pattern([=[%w+:(%d+):(%d+):(.*)]=], { 'lnum', 'col', 'message' }, nil, {
        ['source'] = 'write_good',
        ['severity'] = vim.diagnostic.severity.INFO, ---@type integer
    }),
}
