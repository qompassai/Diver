#!/usr/bin/env lua
-- /qompassai/Diver/after/ftplugin/ansible.lua
-- Qompass AI Diver After Filetype Ansible Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
if vim.b.did_ftplugin == 1 then
    return
end
vim.b.did_ftplugin = 1
vim.opt_local.comments = ':#'
vim.opt_local.commentstring = '# %s'
vim.opt_local.formatoptions:remove({
    't',
    'c',
})
vim.b.undo_ftplugin = 'setl comments< commentstring< formatoptions<'
local function is_ansible()
    local filepath = vim.fn.expand('%:p')
    local filename = vim.fn.expand('%:t')
    if filepath:match('[/\\](tasks|roles|handlers)[/\\].*%.ya?ml$') then
        return true
    end
    if filepath:match('[/\\](group|host)_vars[/\\]') then
        return true
    end
    local ftdetect_filename_regex = '(playbook|site|main|local|requirements)%.ya?ml$'
    if vim.g.ansible_ftdetect_filename_regex then
        ftdetect_filename_regex = vim.g.ansible_ftdetect_filename_regex
    end
    if filename:match(ftdetect_filename_regex) then
        return true
    end
    local shebang = vim.fn.getline(1)
    if shebang:match('^#!/.*/bin/env%s+ansible%-playbook') then
        return true
    end
    if shebang:match('^#!/.*/bin/ansible%-playbook') then
        return true
    end

    return false
end
local function setup_template()
    if vim.g.ansible_template_syntaxes then
        local filepath = vim.fn.expand('%:p')
        for pattern, syntax in pairs(vim.g.ansible_template_syntaxes) do
            local syntax_string = '/' .. pattern
            if filepath:match(syntax_string) then
                vim.bo.filetype = syntax .. '.jinja2'
                return
            end
        end
    end
    vim.bo.filetype = 'jinja2'
end
local augroup_yaml = vim.api.nvim_create_augroup('ansible_vim_ftyaml_ansible', {
    clear = true,
})
vim.api.nvim_create_autocmd({
    'BufNewFile',
    'BufRead',
}, {
    group = augroup_yaml,
    pattern = '*',
    callback = function()
        if is_ansible() then
            vim.bo.filetype = 'yaml.ansible'
        end
    end,
})
local augroup_jinja2 = vim.api.nvim_create_augroup('ansible_vim_ftjinja2', { clear = true })
vim.api.nvim_create_autocmd({
    'BufNewFile',
    'BufRead',
}, {
    group = augroup_jinja2,
    pattern = '*.j2',
    callback = setup_template,
})
local augroup_hosts = vim.api.nvim_create_augroup('ansible_vim_fthosts', { clear = true })
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
    group = augroup_hosts,
    pattern = 'hosts',
    callback = function()
        vim.bo.filetype = 'ansible_hosts'
    end,
})
