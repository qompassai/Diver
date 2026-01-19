-- /qompassai/Diver/linters/mado.lua
-- Qompass AI Diver Mado Linter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lint.Config
return {
  cmd = 'mado',
  stdin = false,
  append_fname = true,
  args = {
    'lint',
    '--format',
    'unix',
    -- '--config',
    -- 'mado.toml',
  },
  stream = 'stdout',
  ignore_exitcode = true,
  ---@param bufnr integer
  ---@return vim.lint.Diagnostic[]
  parser = function(output, bufnr) ---@param output string
    if output == '' then
      return {}
    end
    local diagnostics = {}
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local bufbase = vim.fs.basename(bufname)
    for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
      local path, lnum, col, msg = line:match('^(.-):(%d+):(%d+):%s*(.+)$')
      if not path then
        path, lnum, msg = line:match('^(.-):(%d+):%s*(.+)$')
      end
      if path and lnum and msg then
        local itembase = vim.fs.basename(path)
        if itembase == bufbase or path == bufname then
          lnum = tonumber(lnum) - 1
          col = tonumber(col or 1) - 1
          diagnostics[#diagnostics + 1] = {
            lnum = lnum,
            end_lnum = lnum,
            col = col,
            end_col = col + 1,
            severity = vim.diagnostic.severity.WARN,
            source = 'mado',
            message = msg,
          }
        end
      end
    end
    return diagnostics
  end,
}