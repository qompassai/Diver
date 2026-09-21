-- /qompassai/Diver/lua/mappings/navmap.lua
-- Qompass AI Diver navigation mappings; the only owner of FZF key bindings.
-- Copyright (C) 2025-2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0

local api = vim.api
local fn = vim.fn
local M = {}

---@class NavigationMapping
---@field lhs string
---@field action string
---@field desc string

---@type NavigationMapping[]
local FZF_MAPS = {
    { lhs = '*', action = 'highlight_word_under_cursor', desc = 'Search: highlight current word' },
    {
        lhs = '<leader>z/',
        action = 'toggle_search_highlight',
        desc = 'Search: toggle highlighting',
    },
    { lhs = '<leader>zb', action = 'buffers', desc = 'FZF: find buffer' },
    { lhs = '<leader>zc', action = 'commands', desc = 'FZF: find command' },
    { lhs = '<leader>zd', action = 'document_symbols', desc = 'FZF: find document symbol' },
    { lhs = '<leader>zf', action = 'files', desc = 'FZF: find file' },
    { lhs = '<leader>zgg', action = 'live_grep', desc = 'FZF: grep project' },
    { lhs = '<leader>zgb', action = 'git_branches', desc = 'FZF: switch Git branch' },
    { lhs = '<leader>zgs', action = 'git_status', desc = 'FZF: find Git status entry' },
    { lhs = '<leader>zh', action = 'help_tags', desc = 'FZF: find help tag' },
    { lhs = '<leader>zH', action = 'colorschemes', desc = 'FZF: select colorscheme' },
    { lhs = '<leader>zm', action = 'marks', desc = 'FZF: find mark' },
    { lhs = '<leader>zp', action = 'projects', desc = 'FZF: select project directory' },
    { lhs = '<leader>zw', action = 'grep_cword', desc = 'FZF: grep current word' },
    { lhs = '<leader>zWs', action = 'workspace_symbols', desc = 'FZF: find workspace symbol' },
    { lhs = '<leader>zx', action = 'cancel', desc = 'FZF: cancel current operation' },
    { lhs = 'n', action = 'next_match', desc = 'Search: next match' },
    { lhs = 'N', action = 'prev_match', desc = 'Search: previous match' },
}

---@param message string
local function notify(message)
    vim.notify(message, vim.log.levels.ERROR, { title = 'Navigation mappings' })
end

---@param module_name string
---@param action string
---@param options? table
local function invoke(module_name, action, options)
    local loaded, module = pcall(require, module_name)
    if not loaded then
        notify(('Load %s: %s'):format(module_name, tostring(module)))
        return
    end
    if type(module) ~= 'table' or type(module[action]) ~= 'function' then
        notify(('%s.%s is unavailable.'):format(module_name, action))
        return
    end
    local ok, err
    if options == nil then
        ok, err = pcall(module[action])
    else
        ok, err = pcall(module[action], options)
    end
    if not ok then
        notify(('%s.%s failed: %s'):format(module_name, action, tostring(err)))
    end
end

---@param mode string|string[]
---@param lhs string
---@param callback function
---@param description string
local function map(mode, lhs, callback, description)
    assert(type(lhs) == 'string')
    assert(lhs ~= '')
    assert(type(callback) == 'function')
    vim.keymap.set(mode, lhs, callback, {
        desc = description,
        noremap = true,
        silent = true,
    })
end

local function browse_directory()
    local name = api.nvim_buf_get_name(0)
    local directory = fn.getcwd()
    if name ~= '' and vim.bo[0].buftype == '' then
        directory = vim.fs.dirname(name) or directory
    end
    local stat = vim.uv.fs_stat(directory)
    if stat == nil or stat.type ~= 'directory' then
        notify('Directory is unavailable: ' .. directory)
        return
    end
    local ok, err = pcall(api.nvim_cmd, { cmd = 'edit', args = { directory } }, {})
    if not ok then
        notify('Browse directory: ' .. tostring(err))
    end
end

local function setup_fzf_maps()
    assert(#FZF_MAPS == 18)
    for index = 1, #FZF_MAPS do
        local mapping = FZF_MAPS[index]
        map('n', mapping.lhs, function()
            invoke('config.nav.fzf', mapping.action)
        end, mapping.desc)
    end
end

local function setup_flash_maps()
    -- Flash remains optional and is loaded only when a Flash mapping is invoked.
    map('c', '<C-s>', function()
        invoke('flash', 'toggle')
    end, 'Flash: toggle search')
    map('o', 'r', function()
        invoke('flash', 'remote')
    end, 'Flash: remote jump')
    map({ 'o', 'x' }, 'R', function()
        invoke('flash', 'treesitter_search')
    end, 'Flash: search Tree-sitter nodes')
    map({ 'n', 'x', 'o' }, 's', function()
        invoke('flash', 'jump')
    end, 'Flash: jump forward')
    map({ 'n', 'x', 'o' }, 'S', function()
        invoke('flash', 'jump', { search = { forward = false } })
    end, 'Flash: jump backward')
end

---@return boolean?, string?
function M.setup()
    -- Global navigation does not depend on an LSP attaching. Repeated setup replaces these maps.
    setup_fzf_maps()
    setup_flash_maps()
    map('n', '<leader>e', browse_directory, 'Navigation: browse current directory')
    return true
end

M.setup_navmap = M.setup

return M