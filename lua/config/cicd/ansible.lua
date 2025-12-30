-- qompassai/Diver/lua/config/cicd/ansible.lua
-- Qompass AI Diver CICD Ansible Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'config.cicd.ansible'
vim.filetype.add({
  extension = {
    ['yaml.ansible'] = 'yaml.ansible',
    ['yml.ansible'] = 'yaml.ansible',
  },
  filename = {
    ['ansible.cfg'] = 'ansible',
  },
  pattern = {
    ['.*%.ansible%.ya?ml'] = 'yaml.ansible',
  },
})
local M = {}
local augroups = {
  ansible = vim.api.nvim_create_augroup('Ansible',
    {
      clear = true,
    }),
  yaml = vim.api.nvim_create_augroup('YAML',
    {
      clear = true,
    }),
}
vim.api.nvim_create_autocmd(
  {
    'BufRead',
    'BufNewFile',
  },
  {
    group = augroups.ansible,
    pattern = {
      '*/ansible/*.yml',
      '*/playbooks/*.yml',
      '*/tasks/*.yml',
      '*/roles/*.yml',
      '*/handlers/*.yml',
    },
    callback = function()
      vim.bo.filetype = 'ansible'
    end,
  }
)
vim.api.nvim_create_autocmd({
  'BufRead',
  'BufNewFile',
}, {
  group = augroups.yaml,
  pattern = {
    '*.yml',
    '*.yaml',
  },
  callback = function()
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, 30, false), '\n')
    if content:match('ansible_') or (content:match('hosts:') and content:match('tasks:')) then
      vim.bo.filetype = 'yaml.ansible'
    elseif content:match('apiVersion:') and content:match('kind:') then
      vim.bo.filetype = 'yaml.kubernetes'
    elseif content:match('version:') and content:match('services:') then
      vim.bo.filetype = 'yaml.docker'
    end
  end,
})
---@param opts? { on_attach?: fun(client,bufnr), capabilities?: table }
function M.ansible_cfg(opts)
  opts = opts or {}
  M.ansible_filetype_autocmd()
end

return M