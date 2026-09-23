-- /qompassai/Diver/lua/config/core/parser.lua
-- Bounded colon diagnostics; compare full paths, never just equal basenames.
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local M = {}
local OUTPUT_BYTES_MAX = 8 * 1024 * 1024
local DIAGNOSTICS_MAX = 20000

local function canonical(path, cwd)
    if not path:match('^/') and not path:match('^%a:[/\\]') then
        path = vim.fs.joinpath(cwd, path)
    end
    path = vim.fs.normalize(path)
    path = vim.uv.fs_realpath(path) or path
    return vim.fn.has('win32') == 1 and path:lower() or path
end

---@param output string
---@param bufnr integer
---@param opts? {cwd?: string, pattern?: string, severity?: integer, source?: string}
---@return vim.Diagnostic[], string? error
function M.simple_colon_parser(output, bufnr, opts)
    assert(type(output) == 'string', 'output must be a string')
    opts = opts or {}
    if not api.nvim_buf_is_valid(bufnr) then
        return {}, 'Invalid buffer'
    end
    if #output > OUTPUT_BYTES_MAX then
        return {}, 'Parser output exceeds 8 MiB'
    end
    local name = api.nvim_buf_get_name(bufnr)
    if name == '' then
        return {}, 'Buffer has no filename'
    end
    local cwd = opts.cwd or vim.fn.getcwd()
    local target = canonical(name, cwd)
    local diagnostics = {}
    local pattern = opts.pattern or '^(.-):(%d+):(%d+):%s*(.+)$'
    local lines = api.nvim_buf_line_count(bufnr)
    local visited = 0
    for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
        visited = visited + 1
        if visited > 100000 then
            return {}, 'Parser line budget exceeded'
        end
        local path, row, column, message = line:match(pattern)
        if not path then
            path, row, message = line:match('^(.-):(%d+):%s*(.+)$')
        end
        row, column = tonumber(row), tonumber(column or 1)
        if
            path
            and row
            and column
            and message
            and row >= 1
            and row <= lines
            and column >= 1
            and canonical(path, cwd) == target
        then
            if #diagnostics == DIAGNOSTICS_MAX then
                return {}, 'Diagnostic budget exceeded'
            end
            local text = api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ''
            local col = math.min(column - 1, #text)
            diagnostics[#diagnostics + 1] = {
                lnum = row - 1,
                end_lnum = row - 1,
                col = col,
                end_col = math.min(col + 1, #text),
                message = message:gsub('\r$', ''),
                severity = opts.severity or vim.diagnostic.severity.WARN,
                source = opts.source,
            }
        end
    end
    return diagnostics
end
return M
