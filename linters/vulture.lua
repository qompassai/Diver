-- vulture.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- /qompassai/Diver/linters/vulture.lua
-- Qompass AI Diver Vulture Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
  cmd = 'vulture',
  stdin = false,
  append_fname = true,
  args = {
    '--min-confidence', '80',
    '--sort-by-size',
  },
  stream = nil,
  ignore_exitcode = true,
  env = nil,
  parser = function(output, bufnr)
    local diagnostics = {}
    if output == '' then
      return diagnostics
    end
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local filename = vim.fs.basename(bufname)
    for line in vim.gsplit(output, '\n',
      {
        plain = true,
        trimempty = true
      }) do
      local path, lnum, msg = line:match('^(.-):(%d+):%s*(.+)$')
      if path and lnum and msg then
        lnum = tonumber(lnum) - 1
        local col = 0
        if vim.fs.basename(path) == filename or path == bufname then
          table.insert(diagnostics, {
            lnum = lnum,
            end_lnum = lnum,
            col = col,
            end_col = col + 1,
            message = msg,
            severity = vim.diagnostic.severity.HINT,
            source = 'vulture',
          })
        end
      end
    end
    return diagnostics
  end,
}