-- /qompassai/lua/linters/cppcheck.lua
-- Qompass AI Cppcheck
---@module 'linters.cppcheck'
-- /qompassai/Diver/lua/linters/cppcheck.lua
-- Qompass AI Diver Native Cppcheck Linter
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0

local diagnostic = vim.diagnostic

local severities = {
    debug = diagnostic.severity.HINT,
    error = diagnostic.severity.ERROR,
    information = diagnostic.severity.INFO,
    performance = diagnostic.severity.INFO,
    portability = diagnostic.severity.INFO,
    style = diagnostic.severity.INFO,
    warning = diagnostic.severity.WARN,
}

---@param value any
---@param fallback integer
---@return integer
local function integer(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then
        return fallback
    end
    return math.floor(parsed)
end

---@param output string
---@param _context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
    local diagnostics = {}
    for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
        local _, lnum, column, level, code, message = line:match('^(.-):(%d+):(%d+):([^:]+):([^:]+):(.+)$')
        if lnum ~= nil and level ~= nil and message ~= nil then
            local line_number = math.max(integer(lnum, 1) - 1, 0)
            local start_column = math.max(integer(column, 1) - 1, 0)
            level = vim.trim(level):lower()
            code = vim.trim(code or '')
            message = vim.trim(message)
            diagnostics[#diagnostics + 1] = {
                code = code ~= '' and code or nil,
                col = start_column,
                end_col = start_column + 1,
                end_lnum = line_number,
                lnum = line_number,
                message = code ~= '' and ('[%s] %s'):format(code, message) or message,
                severity = severities[level] or diagnostic.severity.WARN,
                source = 'cppcheck',
            }
        end
    end
    return diagnostics
end

return ---@type Linter
{
    append_fname = true,
    args = {
        '--enable=warning,style,performance,portability',
        '--inline-suppr',
        '--quiet',
        '--template={file}:{line}:{column}:{severity}:{id}:{message}',
    },
    cmd = 'cppcheck',
    cwd = function(context)
        return context.root
    end,
    exit_codes = {
        [0] = true,
    },
    parser = parse,
    root_markers = {
        'compile_commands.json',
        'CMakeLists.txt',
        'meson.build',
        '.git',
    },
    stdin = false,
    stream = 'stderr',
    timeout = 60000,
}
