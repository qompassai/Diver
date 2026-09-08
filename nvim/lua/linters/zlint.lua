-- /qompassai/Diver/linter/zlint.lua
-- Qompass AI Diver Zlint Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source curl -fsSL https://raw.githubusercontent.com/DonIsaac/zlint/refs/heads/main/tasks/install.sh | bash
return ---@type vim.lint.Config
{
    cmd = 'zlint',
    stdin = false,
    append_fname = true,
    args = {
        '--format',
        'github',
    },
    stream = 'both',
    ignore_exitcode = true,
    env = nil,
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
            local severity, path, lnum, col, code, msg =
                line:match('^::(%w+) file=([^,]+),line=(%d+),col=(%d+),title=([^:]+)::(.+)$')
            if not severity then
                severity, path, lnum, code, msg = line:match('^::(%w+) file=([^,]+),line=(%d+),title=([^:]+)::(.+)$')
            end
            if severity and path and lnum and msg then
                lnum = tonumber(lnum) - 1
                col = tonumber(col or 1) - 1

                if vim.fs.basename(path) == filename or path == bufname then
                    local sev
                    if severity == 'error' then
                        sev = vim.diagnostic.severity.ERROR
                    elseif severity == 'warning' then
                        sev = vim.diagnostic.severity.WARN
                    else
                        sev = vim.diagnostic.severity.WARN
                    end
                    table.insert(diagnostics, {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        message = (code and (code .. ': ' .. msg) or msg),
                        severity = sev,
                        source = 'zlint',
                    })
                end
            end
        end
        return diagnostics
    end,
}
