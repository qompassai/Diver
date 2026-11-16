-- /qompassai/Diver/linters/deadnix.lua
-- Qompass AI Deadnix Linter Spec
---@module 'linters.deadnix'
--local core_parser = require('config.core.parser')
return ---@type vim.lint.Config
{
    append_fname = true,
    args = {
        '--output-format',
        'json',
        '--warn-used-underscore',
        '--fail',
    },
    cmd = 'deadnix',
    ignore_exitcode = true,
    ---@param bufnr integer
    ---@return vim.Diagnostic.Set[]
    parser = function(output, bufnr) ---@param output string
        if output == '' then
            return {}
        end
        local ok, decoded_raw = pcall(vim.json.decode, output)
        if not ok or not decoded_raw then
            return {}
        end
        local decoded = decoded_raw ---@type vim.lint.Config.ReportItem[]
        -- deadnix >= 1.0 wraps findings: { file = ..., results = { ... } };
        -- older releases emitted the findings array at the top level.
        local items = decoded
        if type(decoded) == 'table' and type(decoded.results) == 'table' then
            items = {}
            for _, result in ipairs(decoded.results) do
                items[#items + 1] = {
                    column = result.column,
                    endColumn = result.endColumn,
                    kind = result.kind,
                    line = result.line,
                    message = result.message,
                    path = decoded.file,
                }
            end
        end
        local diagnostics = {}
        for _, item in ipairs(items) do
            if item.path and item.line and item.column then
                local bufname = vim.api.nvim_buf_get_name(bufnr)
                if vim.fs.basename(item.path) == vim.fs.basename(bufname) or item.path == bufname then
                    local lnum = (item.line or 1) - 1
                    local col = (item.column or 1) - 1
                    diagnostics[#diagnostics + 1] = {
                        code = item.kind,
                        col = col,
                        end_col = item.endColumn ~= nil and (item.endColumn - 1) or (col + 1),
                        end_lnum = lnum,
                        lnum = lnum,
                        message = item.message or 'dead code detected',
                        severity = vim.diagnostic.severity.WARN,
                        source = 'deadnix',
                    }
                end
            end
        end
        return diagnostics
    end,
    stdin = false,
    stream = 'stdout',
}
