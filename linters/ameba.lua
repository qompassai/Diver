-- ameba.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- /qompassai/Diver/linters/ameba.lua
-- Qompass AI Diver Ameba Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'ameba',
    stdin = false,
    append_fname = false,
    args = {
        '--all',
        -- "--only", "Lint,Syntax",
        -- "--except", "Performance",
        -- "--format", "text",
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
        local current_file
        local current_line
        local current_col
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local path, lnum, col = line:match('^(.-):(%d+):(%d+)$')
            if path and lnum and col then
                current_file = path
                current_line = tonumber(lnum) - 1
                current_col = tonumber(col) - 1
            else
                local level, rule, msg = line:match('^%[([A-Z])%]%s+([^:]+):%s*(.+)$')
                if level and msg and current_file and current_line and current_col then
                    if vim.fs.basename(current_file) == filename or current_file == bufname then
                        local severity
                        if level == 'E' then
                            severity = vim.diagnostic.severity.ERROR
                        elseif level == 'W' then
                            severity = vim.diagnostic.severity.WARN
                        else
                            severity = vim.diagnostic.severity.INFO
                        end
                        local message = msg
                        if rule and rule ~= '' then
                            message = string.format('[%s] %s', rule, msg)
                        end
                        table.insert(diagnostics, {
                            lnum = current_line,
                            end_lnum = current_line,
                            col = current_col,
                            end_col = current_col + 1,
                            message = message,
                            severity = severity,
                            source = 'ameba',
                        })
                    end
                    current_file = nil
                    current_line = nil
                    current_col = nil
                end
            end
        end

        return diagnostics
    end,
}
