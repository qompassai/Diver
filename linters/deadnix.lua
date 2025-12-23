-- /qompassai/Diver/linters/deadnix.lua
-- Qompass AI Deadnix Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
  cmd = 'deadnix',
  stdin = false,
  append_fname = true,
  args = {
    '--output-format=json',
  },
  stream = nil,
  ignore_exitcode = false,
  env = nil,
  parser = function(output, _)
    local diagnostics = {}
    if output == '' then
      return diagnostics
    end
    local decoded = vim.json.decode(output) or {}
    for _, diag in ipairs(decoded.results) do
      table.insert(diagnostics, {
        lnum = diag.line - 1, ---@type integer
        end_lnum = diag.line - 1, ---@type integer
        col = diag.column - 1, ---@type integer
        end_col = diag.endColumn, ---@type integer
        message = diag.message, ---@type integer
        severity = vim.diagnostic.severity.WARN, ---@type integer
      })
    end
    return diagnostics
  end,
}