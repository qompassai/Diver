-- lint-openapi.lua
-- Qompass AI OpenAPI Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local severities = { ---@type { [string]: vim.diagnostic.Severity }
  error = vim.diagnostic.severity.ERROR,
  warning = vim.diagnostic.severity.WARN,
  info = vim.diagnostic.severity.INFO,
  hint = vim.diagnostic.severity.HINT,
}
local function insert_diagnostics(diagnostics, output, level)
  local results = output[level].results ---@type table[]
  for _, result in pairs(results or {}) do
    table.insert(diagnostics, {
      lnum = result.line - 1, ---@type integer
      col = 0,
      severity = severities[level],
      message = result.message, ---@type string
      source = 'lint-openapi',
    })
  end
end
---@type vim.lint.Config
return {
  name = 'lint-openapi',
  cmd = 'lint-openapi',
  args = { '--json' },
  append_fname = true,
  ignore_exitcode = true,
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