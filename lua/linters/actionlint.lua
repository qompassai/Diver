-- /qompassai/Diver/lua/linters/actionlint.lua
-- Qompass AI Actionlint Linter Spec
---@module 'linters.actionlint'
---@type vim.lint.Config
local actionlint = {
    append_fname = false,
    args = function(context)
        return {
            '-format',
            '{{json .}}',
            '-stdin-filename',
            context.filename,
            '-',
        }
    end,
    cmd = 'actionlint',
    ignore_exitcode = true,
    name = 'actionlint',
    parser = function(output, _)
        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local ok, decoded = pcall(vim.json.decode, output)
        if not ok or type(decoded) ~= 'table' then
            return diagnostics
        end
        for _, item in ipairs(decoded) do
            diagnostics[#diagnostics + 1] = {
                col = math.max(item.column - 1, 0),
                end_col = item.end_column or item.column,
                end_lnum = math.max(item.line - 1, 0),
                lnum = math.max(item.line - 1, 0),
                message = item.message,
                severity = vim.diagnostic.severity.WARN,
                source = 'actionlint: ' .. item.kind,
            }
        end
        return diagnostics
    end,
    stdin = true,
    stream = 'stdout',
}
return actionlint
