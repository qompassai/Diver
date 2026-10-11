-- /qompassai/Diver/linters/cypher-lint.lua
-- Qompass AI Diver Cypher-Lint Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    append_fname = true,
    args = {},
    cmd = 'cypher-lint',
    env = nil,
    ignore_exitcode = true,
    ---@param output string
    ---@param bufnr integer
    ---@return vim.Diagnostic.Set[]
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local filename = vim.fs.basename(bufname)
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local path, lnum, col, msg = line:match('^(.-):(%d+):(%d+):%s*(.+)$')
            if not path then
                path, lnum, msg = line:match('^(.-):(%d+):%s*(.+)$')
            end
            if path and lnum and msg then
                lnum = tonumber(lnum) - 1
                col = tonumber(col or 1) - 1
                if vim.fs.basename(path) == filename or path == bufname then
                    table.insert(diagnostics, {
                        col = col,
                        end_col = col + 1,
                        end_lnum = lnum,
                        lnum = lnum,
                        message = msg,
                        severity = vim.diagnostic.severity.ERROR,
                        source = 'cypher-lint',
                    })
                end
            end
        end
        return diagnostics
    end,
    stdin = false,
    stream = nil,
}
