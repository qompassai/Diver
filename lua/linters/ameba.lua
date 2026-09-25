--- ameba linter adapter — Crystal code spell-checker wiring.
---
--- Plain-language version: a linter is like a spell-checker, but for code instead of words. This file teaches
--- Neovim how to run the `ameba` program and turn its complaints into squiggles under your code. It only runs when
--- linting is triggered (usually on save), and only if `ameba` is installed on your computer.
---@module 'linters.ameba'
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
    ---@type LintBufferParser
    ---@param output string
    ---@param bufnr integer
    ---@return vim.Diagnostic.Set[]
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local filename = vim.fs.basename(bufname)
        local current_file ---@type string?
        local current_line ---@type integer?
        local current_col ---@type integer?
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local path, lnum, col = line:match('^(.-):(%d+):(%d+)$')
            if path and lnum and col then
                current_file = path
                current_line = math.floor(tonumber(lnum) or 1) - 1
                current_col = math.floor(tonumber(col) or 1) - 1
            else
                local level, rule, msg = line:match('^%[([A-Z])%]%s+([^:]+):%s*(.+)$')
                if level and msg and current_file and current_line and current_col then
                    if vim.fs.basename(current_file) == filename or current_file == bufname then
                        local severity ---@type vim.diagnostic.Severity
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
                        table.insert(diagnostics, { ---@type vim.lint.Diagnostic[]
                            lnum = lnum,
                            end_lnum = lnum,
                            col = col,
                            end_col = col + 1,
                            message = message,
                            severity = severity,
                            source = 'ameba',
                        })
                    end
                    current_file = nil
                end
            end
        end

        return diagnostics
    end,
}
