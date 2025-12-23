-- lint.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@mod 'config.core.lint'
local M = {}
local running_procs_by_buf = {} ---@type table<integer, table<string, vim.lint.LintProc>>
local namespaces = setmetatable({}, {
  __index = function(tbl, key)
    ---@cast key string
    local ns = vim.api.nvim_create_namespace(key)
    rawset(tbl, key, ns)
    return ns
  end
})
---@return integer
function M.get_namespace(name) ---@param name string linter
  return namespaces[name]
end

---@return string[]
function M.get_running(bufnr) ---@param bufnr? integer buffer for which to get the running linters. nil=all buffers
  local linters = {}
  if bufnr then
    bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
    local running_procs = (running_procs_by_buf[bufnr] or {})
    for linter_name, _ in pairs(running_procs) do
      table.insert(linters, linter_name)
    end
  else
    for _, running_procs in pairs(running_procs_by_buf) do
      for linter_name, _ in pairs(running_procs) do
        table.insert(linters, linter_name)
      end
    end
  end
  return linters
end

return M