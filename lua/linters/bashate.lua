-- /qompassai/Diver/linters/bashate.lua
-- Qompass AI Diver Bashate Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'bashate',
    stdin = false,
    append_fname = true,
    args = {
        '--error',
        'E040,E041,E042,E043,E044',
        '--ignore',
        'E006',
        '--warn',
        'E006',
        '--verbose',
    },
    stream = nil,
    ignore_exitcode = true,
    env = nil,
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local filename = vim.fs.basename(bufname)
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local path, lnum, col, code, msg = line:match('^(.-):(%d+):(%d+):%s*([EW]%d+)%s+(.+)$')
            if path and lnum and col and code and msg then
                if vim.fs.basename(path) == filename or path == bufname then
                    lnum = tonumber(lnum) - 1
                    col = tonumber(col) - 1
                    local severity = code:sub(1, 1) == 'E' and vim.diagnostic.severity.ERROR
                        or vim.diagnostic.severity.WARN
                    table.insert(diagnostics, {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        message = string.format('[%s] %s', code, msg),
                        severity = severity,
                        source = 'bashate',
                    })
                end
            end
        end
        return diagnostics
    end,
}
