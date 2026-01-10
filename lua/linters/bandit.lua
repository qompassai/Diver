-- /qompassai/Diver/linters/bandit.lua
-- Qompass AI Diver Bandit Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'bandit',
    stdin = false,
    append_fname = true,
    args = {
        '--format',
        'screen',
        '--quiet',
        '--severity-level',
        'LOW',
        '--confidence-level',
        'LOW',
        '--recursive',
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
            local path, lnum, col, severity_str, code, msg =
                line:match('^(.-):(%d+):(%d+):%s*(%u+)%s+([A-Z]%d+):%s*(.+)$')
            if not path then
                path, lnum, severity_str, code, msg = line:match('^(.-):(%d+):%s*(%u+)%s+([A-Z]%d+):%s*(.+)$')
            end
            if path and lnum and msg then
                lnum = tonumber(lnum) - 1
                col = tonumber(col or 1) - 1
                if vim.fs.basename(path) == filename or path == bufname then
                    local sev = string.upper(severity_str or '')
                    local severity = vim.diagnostic.severity.WARN
                    if sev == 'LOW' then
                        severity = vim.diagnostic.severity.INFO
                    elseif sev == 'MEDIUM' then
                        severity = vim.diagnostic.severity.WARN
                    elseif sev == 'HIGH' then
                        severity = vim.diagnostic.severity.ERROR
                    end
                    local message = msg
                    if code and code ~= '' then
                        message = string.format('[%s] %s', code, msg)
                    end
                    table.insert(diagnostics, {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        message = message,
                        severity = severity,
                        source = 'bandit',
                    })
                end
            end
        end
        return diagnostics
    end,
}
