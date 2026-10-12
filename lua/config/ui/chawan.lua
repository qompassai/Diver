--- Chawan browser helpers — browse the web inside Neovim with a modern text engine.
---
--- Plain-language version: Chawan is a text-mode web browser with its own CSS and JavaScript engine and inline
--- image support. This module opens pages in it from Neovim and wires up commands. It mirrors the shape of
--- `config.ui.w3m` so the two browsers behave the same from the user's seat; the difference is the engine —
--- reach for Chawan when a page needs CSS or JavaScript that w3m cannot render. It runs when you invoke its
--- commands; it needs `cha` installed.
---@module 'config.ui.chawan'
-- /qompassai/Diver/lua/config/ui/chawan.lua
-- Qompass AI Diver UX Chawan Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn
local levels = vim.log.levels
local notify = vim.notify
local ucmd = api.nvim_create_user_command
M.OPEN_NORMAL = 0
M.OPEN_SPLIT = 1
M.OPEN_TAB = 2
M.OPEN_VSPLIT = 3
M.config = {
    args = {},
    command = 'cha',
    lang = vim.v.lang,
}
---Longest URL or search string accepted by a single open call, in bytes.
local URL_LENGTH_MAX = 4096

---Build the search URL for a plain-text query, mirroring config.ui.w3m's engines.
---@param query string Search terms typed by the user
---@return string url Absolute search URL with the query percent-encoded
local function build_search_url(query)
    local encoded_query = query:gsub(' ', '%%20')
    if M.config.lang == 'ja_JP' or M.config.lang == 'ja' then
        return 'https://search.yahoo.co.jp/search?p=' .. encoded_query .. '&ei=' .. vim.o.encoding
    end
    return 'https://www.google.com/search?q=' .. encoded_query .. '&ie=' .. vim.o.encoding
end

---Register the :Cha family of user commands.
---@return nil
function M.create_commands()
    ucmd('Cha', function(opts)
        M.open(M.OPEN_NORMAL, unpack(opts.fargs))
    end, {
        nargs = '*',
        desc = 'Open URL in Chawan browser',
    })
    ucmd('ChaLocal', function(opts)
        if #opts.fargs == 0 then
            notify('No file path provided', levels.WARN)
            return
        end
        M.open_local(opts.fargs[1])
    end, {
        nargs = 1,
        complete = 'file',
        desc = 'Open local file in Chawan browser',
    })
    ucmd('ChaSplit', function(opts)
        M.open(M.OPEN_SPLIT, unpack(opts.fargs))
    end, {
        nargs = '*',
        desc = 'Open URL in Chawan browser (split)',
    })
    ucmd('ChaTab', function(opts)
        M.open(M.OPEN_TAB, unpack(opts.fargs))
    end, {
        nargs = '*',
        desc = 'Open URL in Chawan browser (new tab)',
    })
    ucmd('ChaVSplit', function(opts)
        M.open(M.OPEN_VSPLIT, unpack(opts.fargs))
    end, {
        nargs = '*',
        desc = 'Open URL in Chawan browser (vertical split)',
    })
end

---Open a URL or search terms in Chawan.
---@param mode number Open mode (NORMAL, SPLIT, TAB, VSPLIT)
---@param ... any URL or search terms; only the first argument is used, mirroring config.ui.w3m
---@return boolean ok true when the browser job started
function M.open(mode, ...)
    assert(
        mode == M.OPEN_NORMAL or mode == M.OPEN_SPLIT or mode == M.OPEN_TAB or mode == M.OPEN_VSPLIT,
        'config.ui.chawan: unknown open mode'
    )
    local args = { ... }
    if #args == 0 then
        notify('No URL or search terms provided', levels.WARN)
        return false
    end
    local target = args[1]
    if type(target) ~= 'string' or target == '' then
        notify('No URL or search terms provided', levels.WARN)
        return false
    end
    if #target > URL_LENGTH_MAX then
        notify('URL or search terms too long (max ' .. URL_LENGTH_MAX .. ' bytes)', levels.WARN)
        return false
    end
    local url = target
    if not url:match('^https?://') and not url:match('^file://') then
        url = build_search_url(url)
    end
    if mode == M.OPEN_SPLIT then
        cmd('split')
    elseif mode == M.OPEN_VSPLIT then
        cmd('vsplit')
    elseif mode == M.OPEN_TAB then
        cmd('tabnew')
    end
    local buf = api.nvim_create_buf(false, true)
    api.nvim_set_current_buf(buf)
    local argv = { M.config.command }
    for _, extra_arg in ipairs(M.config.args) do
        table.insert(argv, extra_arg)
    end
    table.insert(argv, url)
    local job_id = fn.jobstart(argv, {
        term = true,
        on_exit = function(_, code)
            if code ~= 0 and M.config.debug then
                notify('cha exited with code: ' .. code, levels.WARN)
            end
        end,
    })
    if job_id <= 0 then
        notify('Failed to start ' .. M.config.command, levels.ERROR)
        api.nvim_buf_delete(buf, { force = true })
        return false
    end
    bo[buf].bufhidden = 'wipe'
    bo[buf].swapfile = false
    bo[buf].filetype = 'chawan'
    return true
end

---Open a local file in Chawan.
---@param path string File path
---@return boolean ok true when the browser job started
function M.open_local(path)
    if type(path) ~= 'string' or path == '' then
        notify('No file path provided', levels.WARN)
        return false
    end
    local full_path = fn.fnamemodify(path, ':p')
    if fn.filereadable(full_path) == 0 then
        notify('File not found: ' .. path, levels.ERROR)
        return false
    end
    return M.open(M.OPEN_NORMAL, 'file://' .. full_path)
end

---@param opts? table User configuration
---@return boolean ok true when Chawan setup completed
function M.setup(opts)
    M.config = vim.tbl_deep_extend('force', M.config, opts or {})
    if fn.executable(M.config.command) == 0 then
        notify('cha (Chawan) is not installed or not in PATH!', levels.ERROR)
        return false
    end
    M.create_commands()
    return true
end

return M
