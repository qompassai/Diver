-- /qompassai/Diver/lua/ai/rose/ui.lua
-- Native Rose chat buffer (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The rose://chat scratch buffer: open/append/close with bounded memory.
-- Unlike rose.nvim's version, the buffer keymaps never require a
-- plugin-style global; setup() injects the on_stop/on_ask callbacks.

local M = {}

local CHAT_LINE_COUNT_MAX = 10000

---@class AiRoseUiCallbacks
---@field on_stop? fun() cancel in-flight Rose work
---@field on_ask? fun() prompt for a Rose question

local on_stop ---@type fun()?
local on_ask ---@type fun()?

---@param callbacks? AiRoseUiCallbacks
function M.setup(callbacks)
    callbacks = callbacks or {}
    assert(callbacks.on_stop == nil or type(callbacks.on_stop) == 'function', 'ui.setup: on_stop must be a function')
    assert(callbacks.on_ask == nil or type(callbacks.on_ask) == 'function', 'ui.setup: on_ask must be a function')
    on_stop, on_ask = callbacks.on_stop, callbacks.on_ask
end

---@return integer buffer
function M.open()
    if M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
        if not M.window or not vim.api.nvim_win_is_valid(M.window) then
            local source_window = vim.api.nvim_get_current_win()
            vim.cmd('botright 14split')
            M.window = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(M.window, M.buffer)
            vim.api.nvim_set_current_win(source_window)
        end
        return M.buffer
    end
    M.buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.buffer, 'rose://chat')
    vim.bo[M.buffer].buftype = 'nofile'
    vim.bo[M.buffer].bufhidden = 'hide'
    vim.bo[M.buffer].swapfile = false
    vim.bo[M.buffer].filetype = 'markdown'
    vim.bo[M.buffer].modifiable = false
    local source_window = vim.api.nvim_get_current_win()
    vim.cmd('botright 14split')
    M.window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.window, M.buffer)
    vim.wo[M.window].wrap = true
    vim.api.nvim_set_current_win(source_window)
    vim.keymap.set('n', 'q', function()
        if M.window and vim.api.nvim_win_is_valid(M.window) and #vim.api.nvim_list_wins() > 1 then
            vim.api.nvim_win_close(M.window, true)
        end
    end, { buffer = M.buffer, desc = 'Hide Rose chat' })
    vim.keymap.set('n', '<C-c>', function()
        if on_stop then
            on_stop()
        end
    end, { buffer = M.buffer, desc = 'Stop Rose' })
    vim.keymap.set('n', 'i', function()
        if on_ask then
            on_ask()
        end
    end, { buffer = M.buffer, desc = 'Ask Rose' })
    return M.buffer
end

---@param label string section heading
---@param text string? body text
function M.append(label, text)
    assert(type(label) == 'string', 'ui.append: label must be a string')
    local buffer = M.open()
    text = tostring(text or ''):gsub('\r', '')
    local lines = vim.split('\n## ' .. label .. '\n\n' .. text, '\n', { plain = true })
    vim.bo[buffer].modifiable = true
    vim.api.nvim_buf_set_lines(buffer, -1, -1, false, lines)
    -- Bound long-running chat output in memory.
    local count = vim.api.nvim_buf_line_count(buffer)
    if count > CHAT_LINE_COUNT_MAX then
        vim.api.nvim_buf_set_lines(buffer, 0, count - CHAT_LINE_COUNT_MAX, false, {})
    end
    vim.bo[buffer].modifiable = false
    if M.window and vim.api.nvim_win_is_valid(M.window) then
        vim.api.nvim_win_set_cursor(M.window, { vim.api.nvim_buf_line_count(buffer), 0 })
    end
end

--- Hide the Rose chat window and buffer.
function M.close()
    if M.window and vim.api.nvim_win_is_valid(M.window) and #vim.api.nvim_list_wins() > 1 then
        pcall(vim.api.nvim_win_close, M.window, true)
    end
    if M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
        pcall(vim.api.nvim_buf_delete, M.buffer, { force = true })
    end
    M.buffer, M.window = nil, nil
end

return M
