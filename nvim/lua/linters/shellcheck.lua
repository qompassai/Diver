-- /qompassai/Diver/linters/shellcheck.lua
-- Qompass AI Diver ShellCheck Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'shellcheck',
    stdin = false,
    append_fname = true,
    args = {
        '--format=gcc',
        '--color=never',
        '--severity=style',
        '--severity=warning',
        '-x',
        '-e',
        'SC1090,SC1091',
        '-s',
        'bash',
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
            local path, lnum, col, kind, msg = line:match('^(.-):(%d+):(%d+):%s*(%w+):%s*(.+)$')
            if path and lnum and col and kind and msg then
                if vim.fs.basename(path) == filename or path == bufname then
                    lnum = tonumber(lnum) - 1
                    col = tonumber(col) - 1
                    local severity
                    if kind == 'error' then
                        severity = vim.diagnostic.severity.ERROR
                    elseif kind == 'warning' then
                        severity = vim.diagnostic.severity.WARN
                    else -- "note" etc.
                        severity = vim.diagnostic.severity.INFO
                    end
                    table.insert(diagnostics, {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        message = msg,
                        severity = severity,
                        source = 'shellcheck',
                    })
                end
            end
        end
        return diagnostics
    end,
}
