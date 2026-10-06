--- Shared deprecation-modernizing machinery for config.lang modules.
---
--- Each language defines a REPLACEMENTS table (alphabetical by pattern):
---   { lua_pattern, replacement_string_or_function }
--- This module provides the buffer plumbing: get/set text, apply
--- replacements, notify. Keeps per-lang files small and consistent.
---@module 'config.lang.modernize'

local M = {}

local api = vim.api
local fn = vim.fn
local levels = vim.log.levels
local notify = vim.notify

---Get full buffer text.
---@param bufnr integer
---@return string
local function get_buffer_text(bufnr)
    return table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end

---Replace full buffer text, preserving view.
---@param bufnr integer
---@param text string
local function set_buffer_text(bufnr, text)
    local view = fn.winsaveview()
    api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, '\n', { plain = true }))
    fn.winrestview(view)
end

---Apply a replacements table to text.
---@param text string
---@param replacements table list of { pattern, replacement }
---@return string updated, boolean changed
function M.apply_text(text, replacements)
    local original = text
    for i = 1, #replacements do
        local item = replacements[i]
        text = text:gsub(item[1], item[2])
    end
    return text, text ~= original
end

---Apply replacements to a buffer's text.
---@param bufnr integer
---@param replacements table
---@return boolean changed
function M.apply(bufnr, replacements)
    local text = get_buffer_text(bufnr)
    local updated, changed = M.apply_text(text, replacements)
    if changed then
        set_buffer_text(bufnr, updated)
    end
    return changed
end

---Modernize the current buffer if it matches the filetype.
---@param filetype string expected vim filetype
---@param replacements table
---@param lang string language name for messages
function M.buffer(filetype, replacements, lang)
    local bufnr = api.nvim_get_current_buf()
    if vim.bo[bufnr].filetype ~= filetype then
        notify(('Current buffer is not a %s file'):format(lang), levels.WARN)
        return
    end
    if M.apply(bufnr, replacements) then
        notify(('Modernized deprecated %s syntax'):format(lang), levels.INFO)
    else
        notify(('No deprecated %s patterns found'):format(lang), levels.INFO)
    end
end

return M
