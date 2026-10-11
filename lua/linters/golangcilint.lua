-- golangcilint.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local core_parser = require('config.core.parser')
return ---@type vim.lint.Config
{
    append_fname = true,
    args = { 'run', '--out-format', 'line-number', '--path-prefix', vim.uv.cwd() },
    cmd = 'golangci-lint',
    ignore_exitcode = true,
    ---@param output string
    ---@param bufnr integer
    ---@return vim.Diagnostic.Set[]
    parser = function(output, bufnr)
        return core_parser.simple_colon_parser(output, bufnr, {
            pattern = '^(.-):(%d+):(%d+):%s*(.+)$',
            severity = vim.diagnostic.severity.WARN,
            source = 'golangci-lint',
        })
    end,
    stdin = false,
    stream = 'stdout',
}
