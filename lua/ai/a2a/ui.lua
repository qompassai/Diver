-- /qompassai/Diver/lua/ai/a2a/ui.lua
-- Qompass AI A2A Task Monitor (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- One floating window listing every known A2A task: id, agent, state,
-- elapsed time. It subscribes to the supervisor once (lazily, on first
-- open -- requiring this module has no side effects) and refreshes on
-- the main loop whenever anything changes. `q` closes it.

local uv = vim.uv

local tasks = require('ai.a2a.tasks')

local M = {}

local buf = nil
local subscribed = false

local function render()
    if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local lines = {
        'A2A tasks  (q to close)',
        '',
        string.format('%-6s %-20s %-14s %s', 'ID', 'AGENT', 'STATE', 'ELAPSED'),
    }
    for _, task in ipairs(tasks.list()) do
        local elapsed_s = math.floor((uv.now() - task.created_ms) / 1000)
        lines[#lines + 1] = string.format('%-6d %-20s %-14s %ds', task.id, task.agent:sub(1, 20), task.state, elapsed_s)
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

local function on_task_event()
    vim.schedule(render)
end

function M.open()
    if not subscribed then
        tasks.subscribe(on_task_event)
        subscribed = true
    end
    if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win) == buf then
                vim.api.nvim_set_current_win(win)
                render()
                return
            end
        end
    end
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, 'a2a://tasks')
    vim.bo[buf].filetype = 'a2a-tasks'
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true })
    local width = math.floor(vim.o.columns * 0.7)
    local height = math.min(#tasks.list() + 5, math.floor(vim.o.lines * 0.6))
    height = math.max(height, 6)
    vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' A2A tasks ',
    })
    render()
end

return M
