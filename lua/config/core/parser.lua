-- /qompassai/Diver/lua/config/core/parser.lua
-- Qompass AI Diver Core Parser Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@module 'config.core.parser'
-- lua/config/core/parser.lua
local M = {}
function M.simple_colon_parser(output, bufnr, opts)
    opts = opts or {}
    local pattern = opts.pattern or '^(.-):(%d+):(%d+):%s*(.+)$'
    local diagnostics = {}
    if output == '' then
        return diagnostics
    end
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local filename = vim.fs.basename(bufname)
    for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
        local path, lnum, col, msg = line:match(pattern)
        if not path then
            path, lnum, msg = line:match('^(.-):(%d+):%s*(.+)$')
        end
        if path and lnum and msg then
            lnum = tonumber(lnum) - 1
            col = tonumber(col or 1) - 1
            if vim.fs.basename(path) == filename or path == bufname then
                table.insert(diagnostics, {
                    lnum = lnum,
                    end_lnum = lnum,
                    col = col,
                    end_col = col + 1,
                    message = msg,
                    severity = opts.severity or vim.diagnostic.severity.WARN,
                    source = opts.source,
                })
            end
        end
    end
    return diagnostics
end

return M
