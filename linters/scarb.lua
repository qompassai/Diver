-- /qompassai/Diver/linters/scarb.lua
-- Qompass AI Diver Scarb Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'scarb',
    stdin = false,
    append_fname = false,
    args = {
        'lint',
        '--json',
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
            local ok, obj = pcall(vim.json.decode, line)
            if ok and type(obj) == 'table' then
                local span = obj.span or obj.location or {}
                local path = span.file or span.file_name or obj.file
                local lnum = span.line or span.start_line or obj.line
                local col = span.column or span.start_col or obj.column
                local level = obj.level or obj.severity or 'warning'
                local msg = obj.message or obj.msg or obj.code or ''
                if path and lnum and msg ~= '' then
                    lnum = tonumber(lnum) - 1
                    col = tonumber(col or 1) - 1
                    if vim.fs.basename(path) == filename or path == bufname then
                        local sev
                        if level == 'error' then
                            sev = vim.diagnostic.severity.ERROR
                        elseif level == 'warning' then
                            sev = vim.diagnostic.severity.WARN
                        elseif level == 'info' then
                            sev = vim.diagnostic.severity.INFO
                        else
                            sev = vim.diagnostic.severity.WARN
                        end
                        table.insert(diagnostics, {
                            lnum = lnum,
                            end_lnum = lnum,
                            col = col,
                            end_col = col + 1,
                            message = msg,
                            severity = sev,
                            source = 'scarb lint',
                        })
                    end
                end
            end
        end
        return diagnostics
    end,
}
