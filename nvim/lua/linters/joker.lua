-- /qompassai/Diver/linters/joker.lua
-- Qompass AI Joker Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---go install github.com/candid82/joker@latest
local core_parser = require('config.core.parser')
return ---@type vim.lint.Config
{
    cmd = 'joker',
    stdin = false,
    append_fname = true,
    args = {
        '--lint',
    },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output, bufnr)
        return core_parser.simple_colon_parser(output, bufnr, {
            severity = vim.diagnostic.severity.WARN,
            source = 'joker',
            pattern = '^(.-):(%d+):(%d+):%s*(.+)$',
        })
    end,
}
