-- /qompassai/Diver/linters/htmlhint.lua
-- Qompass AI Diver HtmlHint Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local core_parser = require('config.core.parser')
local pattern = '.*: line (%d+), col (%d+), (%a+) %- (.+) %((.+)%)'
local groups = {
    'lnum',
    'col',
    'severity',
    'message',
    'code',
}
local severities = {
    error = vim.diagnostic.severity.ERROR,
    warning = vim.diagnostic.severity.WARN,
}
return ---@type vim.lint.Config
{
    cmd = 'htmlhint',
    stdin = true,
    append_fname = false,
    args = {
        'stdin',
        '-f',
        'compact',
    },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output, bufnr)
        return core_parser.from_pattern(pattern, groups, severities, {
            source = 'htmlhint',
        })(output, bufnr)
    end,
}
