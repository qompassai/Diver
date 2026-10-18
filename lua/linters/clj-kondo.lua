-- /qompassai/Diver/linters/clj-kondo.lua
-- Qompass AI CLJ-Kondo Linter Spec
---@module 'linters.clj-kondo'
return ---@type vim.lint.Config
{
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
    cmd = 'clj-kondo',
    ignore_exitcode = true,
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
            diagnostics[#diagnostics + 1] = {
                col = finding.col - 1,
                end_col = (finding['end-col'] or finding.col) - 1,
                end_lnum = (finding['end-row'] or finding.row) - 1,
                ---@type vim.lint.Diagnostic
                lnum = finding.row - 1,
                message = finding.message,
                severity = severity_map[finding.level] or vim.diagnostic.severity.WARN,
            }
        end
        return diagnostics
    end,
    stdin = true,
    stream = 'stdout',
}
