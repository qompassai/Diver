-- /qompassai/Diver/linters/cookstyle.lua
-- Qompass AI Diver Cookstyle Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'cookstyle',
    stdin = false,
    append_fname = true,
    args = {
        '--display-cop-names',
        '--force-exclusion',
        '--format',
        'clang',
        '--no-color',
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
            local path, lnum, col, sev_letter, rest = line:match('^(.-):(%d+):(%d+):%s*([A-Z]):%s*(.+)$')
            if path and lnum and col and rest then
                if vim.fs.basename(path) == filename or path == bufname then
                    lnum = tonumber(lnum) - 1
                    col = tonumber(col) - 1
                    local severity ---@type vim.diagnostic.Severity
                    if sev_letter == 'F' or sev_letter == 'E' then
                        severity = vim.diagnostic.severity.ERROR
                    elseif sev_letter == 'W' then
                        severity = vim.diagnostic.severity.WARN
                    else
                        severity = vim.diagnostic.severity.INFO
                    end
                    table.insert(diagnostics, {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        message = rest,
                        severity = severity,
                        source = 'cookstyle',
                    })
                end
            end
        end
        return diagnostics
    end,
}
