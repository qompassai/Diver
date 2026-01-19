-- /qompassai/diver/linters/nvcc.lua
-- Qompass AI Diver NVCC Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'nvcc',
    stdin = false,
    stream = 'stderr',
    args = {
        '-c',
        '-lineinfo',
        '-Xcompiler',
        '-Wall',
        '-o',
        (vim.fn.has('win32') == 1) and 'NUL' or '/dev/null',
    },
    ignore_exitcode = true,
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local filename = vim.fs.basename(bufname)
        for line in
            vim.gsplit(output, '\n', {
                plain = true,
                trimempty = true,
            })
        do
            local path, lnum, col, msg = line:match('^(.-):(%d+):(%d+):%s*(.+)$')
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
                        severity = vim.diagnostic.severity.WARN,
                    })
                end
            end
        end
        return diagnostics
    end,
}
