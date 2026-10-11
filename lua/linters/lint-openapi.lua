-- lint-openapi.lua
-- Qompass AI OpenAPI Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local severities = {
    ---@type { [string]: vim.diagnostic.Severity }
    error = vim.diagnostic.severity.ERROR,
    hint = vim.diagnostic.severity.HINT,
    info = vim.diagnostic.severity.INFO,
    warning = vim.diagnostic.severity.WARN,
}
local function insert_diagnostics(diagnostics, output, level)
    local results = output[level].results ---@type table[]
    for _, result in pairs(results or {}) do
        table.insert(diagnostics, {
            col = 0,
            lnum = result.line - 1, ---@type integer
            message = result.message, ---@type string
            severity = severities[level],
            source = 'lint-openapi',
        })
    end
end
---@type vim.lint.Config
return {
    append_fname = true,
    args = { '--json' },
    cmd = 'lint-openapi',
    ignore_exitcode = true,
    name = 'lint-openapi',
    parser = function(output)
        if vim.trim(output) == '' then
            return {}
        end
        local decoded = vim.fn.json_decode(output)
        local diagnostics = {}
        insert_diagnostics(diagnostics, decoded, 'error')
        insert_diagnostics(diagnostics, decoded, 'warning')
        insert_diagnostics(diagnostics, decoded, 'info')
        insert_diagnostics(diagnostics, decoded, 'hint')
        return diagnostics
    end,
}
