-- /qompassai/Diver/linters/alex.lua
-- Qompass AI Diver Alex Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local pattern = '%s*(%d+):(%d+)-(%d+):(%d+)%s+(%w+)%s+(.-)%s+%s+(%g+)%s+%g+'
local groups = {
    'lnum',
    'col',
    'end_lnum',
    'end_col',
    'severity',
    'message',
    'code',
}
local severity_map = {
    warning = vim.diagnostic.severity.WARN, ---@type integer
    error = vim.diagnostic.severity.ERROR, ---@type integer
}
return ---@type vim.lint.Config
{
    cmd = 'alex',
    stdin = true,
    stream = 'stderr',
    ignore_exitcode = true,
    args = {},
    parser = require('lint.parser').from_pattern(pattern, groups, severity_map, {
        severity = vim.diagnostic.severity.WARN, ---@type integer
        source = 'alex',
    }),
}
