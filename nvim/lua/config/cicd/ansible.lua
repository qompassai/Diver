-- qompassai/Diver/lua/config/cicd/ansible.lua
-- Qompass AI Diver CICD Ansible Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local api = vim.api
local group = api.nvim_create_augroup('Ansible', {
    clear = true,
})
api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'yaml.ansible' },
    callback = function()
        vim.opt_local.shiftwidth = 2
        vim.opt_local.tabstop = 2
        vim.opt_local.expandtab = true
    end,
})
function M.ansible_cfg(opts)
    opts = opts or {}
    return opts
end

return M