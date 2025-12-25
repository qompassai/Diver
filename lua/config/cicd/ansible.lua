-- qompassai/Diver/lua/config/cicd/ansible.lua
-- Qompass AI Diver CICD Ansible Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'config.cicd.ansible'
local M = {}

function M.ansible_filetype_autocmd()
  vim.api.nvim_create_autocmd({
      'BufRead', 'BufNewFile'
    },
    {
      pattern = {
        '*/playbooks/*.yml',
        '*/roles/*.yml',
        '*/inventory/*.yml',
        '*/host_vars/*.yml',
        '*/group_vars/*.yml',
      },
      callback = function()
        vim.bo.filetype = 'yaml.ansible'
      end,
    })
end

---@param opts? { on_attach?: fun(client,bufnr), capabilities?: table }
function M.ansible_cfg(opts)
  opts = opts or {}
  M.ansible_filetype_autocmd()
end

return M