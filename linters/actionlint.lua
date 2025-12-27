-- /qompassai/Diver/linters/actionlint.lua
-- Qompass AI Actionlint Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--local core_parser = require('config.core.parser')
local function get_file_name(bufnr)
  return vim.api.nvim_buf_get_name(bufnr or 0)
end
return ---@type vim.lint.Config
{
  name = 'actionlint',
  cmd = 'actionlint',
  stdin = true,
  append_fname = false,
  args = {
    '-format',
    '{{json .}}',
    '-stdin-filename',
    get_file_name,
    '-',
  },
  stream = 'stdout',
  ignore_exitcode = true,
  parser = function(output, _)
    if output == '' then
      return {}
    end
    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or not decoded then
      return {}
    end
    local diagnostics = {}
    vim.iter(decoded):each(function(item)
      diagnostics[#diagnostics + 1] = { ---@type vim.lint.Diagnostic
        lnum = item.line - 1,
        end_lnum = item.line - 1,
        col = item.column - 1,
        end_col = item.end_column,
        severity = vim.diagnostic.severity.WARN,
        source = 'actionlint: ' .. item.kind,
        message = item.message,
      }
    end)
    return diagnostics
  end,
}