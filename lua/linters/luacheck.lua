-- /qompassai/Diver/linters/luacheck.lua
-- Qompass AI Diver LuaCheck Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local pattern = '[^:]+:(%d+):(%d+)-(%d+): %((%a)(%d+)%) (.*)'
local groups = {
    'lnum',
    'col',
    'end_col',
    'severity',
    'code',
    'message',
}
local severities = {
    W = vim.diagnostic.severity.WARN, ---@type integer
    E = vim.diagnostic.severity.ERROR, ---@type integer
}
return {
    cmd = 'luacheck',
    stdin = true,
    args = {
        '--formatter',
        'plain',
        '--codes',
        '--ranges',
        '-',
    },
    ignore_exitcode = true,
    parser = require('lint.parser').from_pattern( ---@type string
        pattern,
        groups,
        severities,
        {
            ['source'] = 'luacheck',
        },
        {
            end_col_offset = 0,
        }
    ),
}
