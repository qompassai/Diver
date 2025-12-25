-- /qompassai/Diver/linters/joker.lua
-- Qompass AI Joker Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = 'joker',
    stdin = false,
    stream = 'stderr',
    args = { '--lint' },
    ignore_exitcode = true,
    parser = require('lint.parser').from_errorformat('%f:%l:%c: %m', { ---@type string
        source = 'joker',
    }),
}
