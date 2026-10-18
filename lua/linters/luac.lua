-- /qompassai/Diver/linters/luac.lua
-- Qompass AI Diver LuaC Linter Spec
---@module 'linters.luac'
local core_parser = require('config.core.parser')
return ---@type vim.lint.Config
{
    append_fname = false,
    args = {
        '-p',
        '-',
    },
    cmd = 'luac',
    ignore_exitcode = true,
    ---@type LintBufferParser
    ---@param output string
    ---@param bufnr integer
    ---@return vim.Diagnostic.Set[]
    parser = function(output, bufnr)
        return core_parser.simple_colon_parser(output, bufnr, {
            pattern = '^(.-):(%d+):(%d+):%s*(.+)$',
            severity = vim.diagnostic.severity.WARN,
            source = 'luac',
        })
    end,
    stdin = true,
    stream = 'stderr',
}
