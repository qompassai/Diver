-- /qompassai/Diver/lsp/uv.lua
-- Qompass AI UV Formatter
 -- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------
local M = {}
function M.format_project()
  local cwd = vim.loop.cwd()
  vim.fn.jobstart({ 'uv', 'format' }, {
    cwd = cwd,
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.schedule(function()
          vim.cmd('checktime')
          vim.notify('uv format completed', vim.log.levels.INFO)
        end)
      else
        vim.notify('uv format failed (see messages)', vim.log.levels.ERROR)
      end
    end,
  })
end
return M