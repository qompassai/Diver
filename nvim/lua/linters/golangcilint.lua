-- golangcilint.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local core_parser = require('config.core.parser')
return ---@type vim.lint.Config
{
    cmd = 'golangci-lint',
    stdin = false,
    append_fname = true,
    args = { 'run', '--out-format', 'line-number', '--path-prefix', vim.loop.cwd() },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output, bufnr)
        return core_parser.simple_colon_parser(output, bufnr, {
            severity = vim.diagnostic.severity.WARN,
            source = 'golangci-lint',
            pattern = '^(.-):(%d+):(%d+):%s*(.+)$',
        })
    end,
}
