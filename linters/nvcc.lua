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
    ---@return vim.lint.Diagnostic[]
    ---@param output string
    ---@param bufnr integer
    ---@return vim.lint.Diagnostic[]
    parser = function(output, bufnr)
        ---@type vim.lint.Diagnostic[]
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local pattern = [[^([^:%(%)]+):?%((%d+)%):? ?(%d+)?:?%s*%w*%s*(error|warning): (.+)$]]
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local filename, lnum, col, level, msg = line:match(pattern)
            if filename and lnum and level and msg then
                local severity = (level == 'error') and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN
                diagnostics[#diagnostics + 1] = {
                    lnum = tonumber(lnum) - 1, ---@type number
                    col = col and (tonumber(col) - 1) or 0, ---@type number
                    end_lnum = tonumber(lnum) - 1, ---@type number
                    end_col = col and tonumber(col) or 0, ---@type number
                    severity = severity,
                    source = 'nvcc',
                    message = msg,
                    user_data = {
                        bufnr = bufnr, -- optional: keep a copy here if you want
                        filename = vim.fn.fnamemodify(filename, ':p'),
                    },
                }
            end
        end

        return diagnostics
    end,
}
