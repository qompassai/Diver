-- /qompassai/lua/linters/markdown-table-formatter.lua
-- Qompass AI Markdown Table Formatter
---@module 'linters.markdown-table-formatter'
-- /qompassai/Diver/lua/linters/markdown-table-formatter.lua
-- Qompass AI Diver Native Markdown Table Formatter Check
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
---@param context LintContext
---@return integer, integer
local function first_table(context)
    for index, line in ipairs(vim.api.nvim_buf_get_lines(context.bufnr, 0, -1, false)) do
        local start = line:find('|', 1, true)
        if start ~= nil and line:find('|', start + 1, true) ~= nil then
            return index - 1, start - 1
        end
    end
    return 0, 0
end
---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    local clean = vim.trim(output:gsub('\27%[[%d;]*m', ''))
    if not clean:match('files? contain markdown tables? to format') then
        return {}
    end
    if type(context) ~= 'table' then
        error('markdown-table-formatter parser requires a LintContext', 0)
    end
    ---@cast context LintContext
    local lnum, col = first_table(context)
    return {
        {
            code = 'table-format',
            col = col,
            end_col = col + 1,
            end_lnum = lnum,
            lnum = lnum,
            message = 'Markdown table formatting differs from markdown-table-formatter output',
            severity = vim.diagnostic.severity.WARN,
            source = 'markdown-table-formatter',
        },
    }
end

return ---@type Linter
{
    append_fname = true,
    args = {
        '--check',
    },
    automatic = false,
    cmd = 'markdown-table-formatter',
    cwd = function(context)
        return vim.fs.dirname(context.filename) or context.cwd
    end,
    exit_codes = {
        [0] = true,
    },
    parser = parse,
    root_markers = {
        'package.json',
        '.git',
    },
    stdin = false,
    stream = 'stdout',
    timeout = 30000,
}
