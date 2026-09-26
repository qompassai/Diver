-- /qompassai/Diver/linters/clj-kondo.lua
-- Qompass AI CLJ-Kondo Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return { ---@type vim.lint.Config
    cmd = 'clj-kondo',
    stdin = true,
    stream = 'stdout',
    ignore_exitcode = true,
    args = function(context)
        return {
            '--config',
            '{:output {:format :json}}',
            '--filename',
            context.filename,
            '--lint',
            '-',
        }
    end,
    parser = function(output)
        if output == '' then
            return {}
        end
        local decoded = vim.json.decode(output) or {}
        local findings = decoded.findings or {}
        local diagnostics = {}
        local severity_map = {
            error = vim.diagnostic.severity.ERROR,
            warning = vim.diagnostic.severity.WARN,
        }
        for _, finding in ipairs(findings) do
            diagnostics[#diagnostics + 1] = { ---@type vim.lint.Diagnostic
                lnum = finding.row - 1,
                col = finding.col - 1,
                end_lnum = (finding['end-row'] or finding.row) - 1,
                end_col = (finding['end-col'] or finding.col) - 1,
                severity = severity_map[finding.level] or vim.diagnostic.severity.WARN,
                message = finding.message,
            }
        end
        return diagnostics
    end,
}
