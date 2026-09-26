-- /qompassai/Diver/lua/ai/acp/ui.lua
-- Qompass AI ACP Chat Buffer Rendering (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

local api = vim.api

local M = {}

local LINE_COUNT_MAX = 20000

---@type table<string, integer>
local buffers = {}

---@param session_key string
---@param agent_name string
---@return integer bufnr
local function ensure_buffer(session_key, agent_name)
    local existing = buffers[session_key]
    if existing and api.nvim_buf_is_valid(existing) then
        return existing
    end

    local bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(bufnr, 'acp://' .. agent_name .. '/' .. session_key)
    vim.bo[bufnr].filetype = 'acpchat'
    vim.bo[bufnr].buftype = 'nofile'
    vim.bo[bufnr].bufhidden = 'hide'
    vim.bo[bufnr].swapfile = false
    buffers[session_key] = bufnr
    return bufnr
end

---@param bufnr integer
---@param lines string[]
local function append_lines(bufnr, lines)
    if not api.nvim_buf_is_valid(bufnr) then
        return
    end
    local total = api.nvim_buf_line_count(bufnr)
    if total >= LINE_COUNT_MAX then
        return
    end
    local start = api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == '' and total == 1 and 0 or total
    api.nvim_buf_set_lines(bufnr, start, -1, false, lines)
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
        api.nvim_win_call(win, function()
            vim.cmd('normal! G')
        end)
    end
end

---@param session_key string
---@param agent_name string
---@param how? 'edit'|'split'|'vsplit'|'tabedit'
---@return integer bufnr
function M.open(session_key, agent_name, how)
    local bufnr = ensure_buffer(session_key, agent_name)
    if how and how ~= 'edit' then
        vim.cmd(how)
    end
    api.nvim_set_current_buf(bufnr)
    return bufnr
end

---@param session_key string
---@param agent_name string
---@param text string
function M.append_user(session_key, agent_name, text)
    local bufnr = ensure_buffer(session_key, agent_name)
    local lines = vim.split(text, '\n', { plain = true })
    lines[1] = '> ' .. (lines[1] or '')
    append_lines(bufnr, lines)
    append_lines(bufnr, { '' })
end

---@param session_key string
---@param agent_name string
---@param update table Raw session/update notification params.
function M.append_update(session_key, agent_name, update)
    local bufnr = ensure_buffer(session_key, agent_name)
    local text
    if type(update.text) == 'string' then
        text = update.text
    elseif type(update.toolCall) == 'table' then
        text = '[tool] ' .. (update.toolCall.title or update.toolCall.name or 'call')
    else
        text = vim.inspect(update)
    end
    append_lines(bufnr, vim.split(text, '\n', { plain = true }))
end

---@param session_key string
function M.close(session_key)
    local bufnr = buffers[session_key]
    buffers[session_key] = nil
    if bufnr and api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_delete(bufnr, { force = true })
    end
end

return M
