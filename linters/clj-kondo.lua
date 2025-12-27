-- /qompassai/Diver/linters/clj-kondo.lua
-- Qompass AI CLJ-Kondo Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local function get_file_name()
  return vim.api.nvim_buf_get_name(0)
end
return {
  cmd = 'clj-kondo',
  stdin = true,
  stream = 'stdout',
  ignore_exitcode = true,
  args = {
    '--config',
    '{:output {:format :json}}',
    '--filename',
    get_file_name,
    '--lint',
    '-',
  },
  parser = function(output)
    local decoded = vim.json.decode(output) or {}
    local findings = decoded.findings or {}
    local diagnostics = {}
    local severity_map = {
      error = vim.diagnostic.severity.ERROR,
      warning = vim.diagnostic.severity.WARN,
    }
    for _, finding in ipairs(findings) do
      diagnostics[#diagnostics + 1] = {
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