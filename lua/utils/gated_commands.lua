--- Gated commands: register a suite's commands buffer-locally, only
--- in buffers where the suite applies.
---
--- Plain-language version: a suite (Salesforce, Android, ...) hands
--- this helper its command-registration function plus the conditions
--- that mark one of its buffers - file extensions, filetypes, and/or
--- project root markers. The commands are then created per buffer,
--- so they exist (and complete) only where they can actually work,
--- instead of occupying every buffer's command namespace.
---@module 'utils.gated_commands'
-- /qompassai/Diver/lua/utils/gated_commands.lua
-- Qompass AI Diver Gated Commands
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------

local api = vim.api

local M = {}

---@class GatedCommandsOpts
---@field extensions? string[] file extensions (no dot, lowercase) that open the gate
---@field filetypes? string[] filetypes that open the gate
---@field group string augroup name; also namespaces the per-buffer attached flag
---@field register fun(bufnr: integer) create the suite's commands in one buffer
---@field root_markers? string[] marker files found upward from the buffer that open the gate

---@param name string buffer file name
---@return string ext lowercase extension without the dot ('' when none)
local function extension_of(name)
    return vim.fn.fnamemodify(name, ':e'):lower()
end

---@param bufnr integer
---@param opts GatedCommandsOpts
---@return boolean open true when any configured gate dimension matches the buffer
local function gate_open(bufnr, opts)
    local name = api.nvim_buf_get_name(bufnr)
    if opts.extensions ~= nil and name ~= '' then
        local ext = extension_of(name)
        for _, wanted in ipairs(opts.extensions) do
            if ext == wanted then
                return true
            end
        end
    end
    if opts.filetypes ~= nil then
        local filetype = vim.bo[bufnr].filetype
        for _, wanted in ipairs(opts.filetypes) do
            if filetype == wanted then
                return true
            end
        end
    end
    if opts.root_markers ~= nil and name ~= '' then
        return vim.fs.root(bufnr, opts.root_markers) ~= nil
    end
    return false
end

---Install the gate. register runs at most once per matching buffer
---(tracked with a buffer variable); the buffer current at attach
---time is tried immediately, later buffers via BufEnter/FileType.
---@param opts GatedCommandsOpts
function M.attach(opts)
    assert(type(opts) == 'table', 'gated_commands.attach: opts table is required')
    assert(type(opts.group) == 'string' and opts.group ~= '', 'gated_commands.attach: group is required')
    assert(type(opts.register) == 'function', 'gated_commands.attach: register function is required')
    assert(
        opts.extensions ~= nil or opts.filetypes ~= nil or opts.root_markers ~= nil,
        'gated_commands.attach: at least one gate dimension is required'
    )
    local flag = 'gated_commands_' .. opts.group
    ---@param bufnr integer
    local function try_attach(bufnr)
        if not api.nvim_buf_is_valid(bufnr) then
            return
        end
        if vim.b[bufnr][flag] == true then
            return
        end
        if not gate_open(bufnr, opts) then
            return
        end
        opts.register(bufnr)
        vim.b[bufnr][flag] = true
    end
    local group = api.nvim_create_augroup(opts.group, { clear = true })
    api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, {
        group = group,
        callback = function(event)
            try_attach(event.buf)
        end,
        desc = 'Attach ' .. opts.group .. ' commands to matching buffers',
    })
    try_attach(api.nvim_get_current_buf())
end

return M
