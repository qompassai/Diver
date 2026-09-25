-- Reusable native terminals. Shells are interactive and user initiated.
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local core = require('mappings._core')
local M = {}
local OWNER = 'cicdmap'
local terminals = {}
local group

local function open_window(kind, bufnr)
    if kind == 'float' then
        local width = math.max(1, math.floor(vim.o.columns * 0.8))
        local height = math.max(1, math.floor((vim.o.lines - 2) * 0.8))
        return api.nvim_open_win(bufnr, true, {
            relative = 'editor',
            width = width,
            height = height,
            row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
            col = math.max(0, math.floor((vim.o.columns - width) / 2)),
            border = 'single',
            style = 'minimal',
        })
    end
    vim.cmd(kind == 'vertical' and 'botright vsplit' or 'botright split')
    api.nvim_win_set_buf(0, bufnr)
    return api.nvim_get_current_win()
end

function M.toggle(kind)
    assert(kind == 'float' or kind == 'horizontal' or kind == 'vertical')
    local entry = terminals[kind]
    if entry and entry.win and api.nvim_win_is_valid(entry.win) and api.nvim_win_get_buf(entry.win) == entry.buf then
        if #api.nvim_tabpage_list_wins(0) > 1 then
            api.nvim_win_close(entry.win, true)
        else
            api.nvim_win_set_buf(entry.win, api.nvim_create_buf(true, false))
        end
        entry.win = nil
        return
    end
    local fresh = not entry or not api.nvim_buf_is_valid(entry.buf)
    if fresh then
        entry = { buf = api.nvim_create_buf(false, true) }
        terminals[kind] = entry
        vim.bo[entry.buf].bufhidden = 'hide'
        vim.bo[entry.buf].swapfile = false
    end
    entry.win = open_window(kind, entry.buf)
    if fresh then
        -- jobstart() with term=true is native; termopen() is deprecated.
        entry.job = vim.fn.jobstart(vim.o.shell, { term = true, cwd = vim.fn.getcwd() })
        if entry.job <= 0 then
            core.notify('Could not start the configured shell', vim.log.levels.ERROR)
            api.nvim_buf_delete(entry.buf, { force = true })
            terminals[kind] = nil
            return
        end
    end
    vim.cmd.startinsert()
end

function M.teardown()
    core.teardown(OWNER)
    if group then
        api.nvim_del_augroup_by_id(group)
        group = nil
    end
    -- Shell sessions intentionally survive mapping reloads; closing a mapping
    -- layer must not kill a user's interactive process. :bdelete! closes one.
end

function M.setup()
    M.teardown()
    core.install(OWNER, 0, {
        {
            lhs = '<A-h>',
            mode = { 'n', 't' },
            rhs = function()
                M.toggle('horizontal')
            end,
            desc = 'Toggle horizontal terminal',
        },
        {
            lhs = '<A-i>',
            mode = { 'n', 't' },
            rhs = function()
                M.toggle('float')
            end,
            desc = 'Toggle floating terminal',
        },
        {
            lhs = '<A-v>',
            mode = { 'n', 't' },
            rhs = function()
                M.toggle('vertical')
            end,
            desc = 'Toggle vertical terminal',
        },
    })
    group = api.nvim_create_augroup('NativeMappings_terminal_lifecycle', { clear = true })
    api.nvim_create_autocmd('BufWipeout', {
        group = group,
        callback = function(event)
            for kind, entry in pairs(terminals) do
                if entry.buf == event.buf then
                    terminals[kind] = nil
                end
            end
        end,
    })
end

M.setup_cicdmap = M.setup
return M
