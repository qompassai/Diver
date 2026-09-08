-- /qompassai/Diver/linters/secfixes_check.lua
-- Qompass AI Diver secfixes-check Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'secfixes-check',
    stdin = false,
    append_fname = true,
    args = {},
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
            local sev_cert, tag, path, lnum, msg = line:match('^([SMH][CP]):%[([^%]]+)%]:(.-):(%d+):%s*(.+)$')
            if path and lnum and msg then
                lnum = tonumber(lnum) - 1
                local col = 0
                if vim.fs.basename(path) == filename or path == bufname then
                    local sev_letter = sev_cert and sev_cert:sub(1, 1) or 'M'
                    local severity
                    if sev_letter == 'H' then
                        severity = vim.diagnostic.severity.ERROR
                    elseif sev_letter == 'M' then
                        severity = vim.diagnostic.severity.WARN
                    else
                        severity = vim.diagnostic.severity.INFO
                    end
                    local message = msg
                    if tag and tag ~= '' then
                        message = string.format('[%s] %s', tag, msg)
                    end
                    table.insert(diagnostics, {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        message = message,
                        severity = severity,
                        source = 'secfixes-check',
                    })
                end
            end
        end
        return diagnostics
    end,
}
