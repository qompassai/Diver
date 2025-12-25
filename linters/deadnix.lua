-- /qompassai/Diver/linters/deadnix.lua
-- Qompass AI Deadnix Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'deadnix',
    stdin = false,
    append_fname = true,
    args = { '--output-format=json' },
    ignore_exitcode = false,
    parser = function(output, _)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local decoded = vim.json.decode(output) or {}
        for _, diag in ipairs(decoded.results or {}) do
            diagnostics[#diagnostics + 1] = {
                lnum = diag.line - 1,
                end_lnum = diag.line - 1,
                col = diag.column - 1,
                end_col = diag.endColumn,
                message = diag.message,
                severity = vim.diagnostic.severity.WARN,
            }
        end
        return diagnostics
    end,
}
