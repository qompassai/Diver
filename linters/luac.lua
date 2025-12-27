-- /qompassai/Diver/linters/luac.lua
-- Qompass AI Diver LuaC Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local core_parser = require('config.core.parser')
return ---@type vim.lint.Config
{
    cmd = 'luac',
    stdin = true,
    append_fname = false,
    args = {
        '-p',
        '-',
    },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output, bufnr)
        return core_parser.simple_colon_parser(output, bufnr, {
            severity = vim.diagnostic.severity.WARN,
            source = 'luac',
            pattern = '^(.-):(%d+):(%d+):%s*(.+)$',
        })
    end,
}
