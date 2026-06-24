-- /qompassai/Diver/lua/utils/sf/tests.lua
-- Qompass AI Salesforce Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
local M = {}
---@param opts table|nil
---@return string|nil
function M.get_args(opts)
    if opts and opts.args and opts.args ~= '' then
        return opts.args
    end
    return nil
end

function M.executable(bin)
    return vim.fn.executable(bin) == 1
end

---@param value string|number
---@return string
function M.shellescape(value)
    return tostring(vim.fn.shellescape(tostring(value)))
end

function M.current_file()
    return vim.api.nvim_buf_get_name(0)
end

function M.current_dir()
    return vim.fn.expand('%:p:h')
end

function M.current_basename()
    return vim.fn.expand('%:t:r')
end

function M.current_ext()
    return vim.fn.expand('%:e')
end

function M.current_line()
    return vim.api.nvim_win_get_cursor(0)[1]
end

function M.filetype()
    return vim.bo.filetype
end

---@return string|nil
function M.project_root()
    return vim.fs.root(0, { 'sfdx-project.json' })
end

function M.in_sf_project()
    return M.project_root() ~= nil
end

---@param msg string|string[]
---@param level? integer
function M.notify(msg, level)
    if type(msg) == 'table' then
        msg = table.concat(msg, '\n')
    end
    vim.notify(msg, level or vim.log.levels.INFO, {
        title = 'Salesforce',
    })
end

function M.open_term_cmd(cmd, height)
    height = height or 14
    vim.cmd('botright ' .. height .. 'split | terminal ' .. cmd)
    local buf = vim.api.nvim_get_current_buf()
    local opts = {
        buffer = buf,
        noremap = true,
        silent = true,
    }
    vim.keymap.set('n', 'q', '<cmd>bd!<cr>', opts)
    vim.keymap.set('n', '<Esc>', '<cmd>bd!<cr>', opts)
    vim.cmd('startinsert')
end

function M.ensure_sf()
    if not M.executable('sf') then
        M.notify('sf CLI not found in PATH', vim.log.levels.ERROR)
        return false
    end
    return true
end

function M.ensure_project()
    if not M.in_sf_project() then
        M.notify('Not inside an sfdx-project.json workspace', vim.log.levels.WARN)
        return false
    end
    return true
end

function M.has_file()
    local file = M.current_file()
    if file == '' then
        M.notify('No current file', vim.log.levels.WARN)
        return false
    end
    return true
end

function M.get_visual_selection()
    local s = vim.fn.getpos('\'<')
    local e = vim.fn.getpos('\'>')
    local lines = vim.api.nvim_buf_get_lines(0, s[2] - 1, e[2], false)
    if #lines == 0 then
        return ''
    end
    lines[#lines] = string.sub(lines[#lines], 1, e[3])
    lines[1] = string.sub(lines[1], s[3])
    return table.concat(lines, '\n')
end

return M