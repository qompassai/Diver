-- bash.lua
-- Qompass AI Bash Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = 'bash',
    stdin = true,
    append_fname = false,
    args = { '-n', '-s' },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = require('lint.parser').from_errorformat('bash:\\ line\\ %l:\\ %m', { ---@type string
        source = 'bash',
        severity = vim.diagnostic.severity.ERROR, ---@type integer
    }),
}
