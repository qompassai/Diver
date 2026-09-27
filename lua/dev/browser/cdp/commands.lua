-- lua/dev/browser/cdp/commands.lua
-- The seven :Browser* user commands. Thin glue: parse args, demand a
-- connection, delegate to actions. No protocol logic here.
-- Plain words: this is the command palette surface. :BrowserAttach picks
-- a target and confirms; everything else needs a live connection first.
-- Copyright (C) 2026 Qompass AI. All rights reserved.
-- SPDX-License-Identifier: Apache-2.0
---@module 'dev.browser.cdp.commands'

local actions = require('dev.browser.cdp.actions')
local security = require('dev.browser.cdp.security')

local M = {}

local DEFAULT_HOST = '127.0.0.1'
local DEFAULT_PORT = 9222

---Internal/test seam: the live connection. Prefer :BrowserAttach/:BrowserOpen.
M._conn = nil
M._console_ring = nil
M._network_log = nil

---@return table|nil conn
local function need_conn()
    if M._conn == nil or M._conn.closed then
        vim.notify('Not connected: run :BrowserAttach or :BrowserOpen first', vim.log.levels.ERROR)
        return nil
    end
    return M._conn
end

local function cmd_open(opts)
    local url = opts.args ~= '' and opts.args or nil
    actions.open(url, {}, function(err, conn)
        if err ~= nil then
            vim.notify(tostring(err), vim.log.levels.ERROR)
            return
        end
        M._conn = conn
        M._console_ring = nil
        M._network_log = nil
        vim.notify('Browser opened and attached: ' .. tostring(conn.target_url or conn.target_id))
    end)
end

local function cmd_attach()
    actions.list_targets(DEFAULT_HOST, DEFAULT_PORT, {}, function(err, pages)
        if err ~= nil then
            vim.notify(tostring(err), vim.log.levels.ERROR)
            return
        end
        if #pages == 0 then
            vim.notify('No page targets found', vim.log.levels.WARN)
            return
        end
        local items = {}
        for _, target_info in ipairs(pages) do
            local label = tostring(target_info.title or target_info.id)
            items[#items + 1] = label .. ' — ' .. tostring(target_info.url)
        end
        vim.ui.select(items, { prompt = 'Attach to browser target:' }, function(choice)
            if choice == nil then
                return
            end
            local picked = nil
            for i, item in ipairs(items) do
                if item == choice then
                    picked = pages[i]
                    break
                end
            end
            if picked == nil then
                return
            end
            local ref = { title = picked.title, url = picked.url }
            security.confirm_attach(ref, function(allowed, reason)
                if not allowed then
                    vim.notify('Attach declined: ' .. tostring(reason), vim.log.levels.WARN)
                    return
                end
                local attach_opts = { confirmed = true }
                local host, port, target_id = DEFAULT_HOST, DEFAULT_PORT, picked.id
                actions.attach(host, port, target_id, attach_opts, function(
                    attach_err,
                    conn
                )
                    if attach_err ~= nil then
                        vim.notify(tostring(attach_err), vim.log.levels.ERROR)
                        return
                    end
                    M._conn = conn
                    M._console_ring = nil
                    M._network_log = nil
                    vim.notify('Attached: ' .. tostring(conn.target_url or conn.target_id))
                end)
            end)
        end)
    end)
end

local function cmd_navigate(opts)
    local conn = need_conn()
    if conn == nil then
        return
    end
    actions.navigate(conn, opts.args, function(err, result)
        if err ~= nil then
            vim.notify(tostring(err), vim.log.levels.ERROR)
            return
        end
        local suffix = ''
        if result and result.loaderId then
            suffix = ': ' .. tostring(result.loaderId)
        end
        vim.notify('Navigated' .. suffix)
    end)
end

local function cmd_eval(opts)
    local conn = need_conn()
    if conn == nil then
        return
    end
    -- Confirmation happens inside actions.eval via vim.ui; nothing runs
    -- without the user seeing the exact expression and target URL.
    actions.eval(conn, opts.args, {}, function(err, result)
        if err ~= nil then
            vim.notify(tostring(err), vim.log.levels.ERROR)
            return
        end
        local shown = '(no value)'
        local inner = type(result) == 'table' and result.result or nil
        if type(inner) == 'table' and inner.value ~= nil then
            local ok, text = pcall(vim.json.encode, result.result.value)
            shown = ok and text or tostring(result.result.value)
        end
        vim.notify('Eval result: ' .. shown)
    end)
end

local function cmd_screenshot(opts)
    local conn = need_conn()
    if conn == nil then
        return
    end
    local path = opts.args ~= '' and opts.args or nil
    actions.screenshot(conn, path, function(err, saved)
        if err ~= nil then
            vim.notify(tostring(err), vim.log.levels.ERROR)
            return
        end
        vim.notify('Screenshot saved: ' .. tostring(saved))
    end)
end

local function cmd_console()
    local conn = need_conn()
    if conn == nil then
        return
    end
    if M._console_ring == nil then
        M._console_ring = actions.new_ring()
        local ok, tap_err = actions.enable_console_tap(conn, M._console_ring)
        if not ok then
            vim.notify(tostring(tap_err), vim.log.levels.ERROR)
            M._console_ring = nil
            return
        end
    end
    actions.show_console(M._console_ring)
end

local function cmd_network()
    local conn = need_conn()
    if conn == nil then
        return
    end
    if M._network_log == nil then
        M._network_log = actions.new_network_log()
        local ok, tap_err = actions.enable_network_tap(conn, M._network_log)
        if not ok then
            vim.notify(tostring(tap_err), vim.log.levels.ERROR)
            M._network_log = nil
            return
        end
    end
    actions.show_network(M._network_log)
end

local COMMANDS = {
    {
        name = 'BrowserOpen',
        nargs = '?',
        desc = 'Launch isolated headless Chrome and attach (optional start URL)',
        handler = cmd_open,
    },
    {
        name = 'BrowserAttach',
        nargs = 0,
        desc = 'Pick a page target of a running browser and attach (confirms)',
        handler = cmd_attach,
    },
    {
        name = 'BrowserNavigate',
        nargs = 1,
        desc = 'Navigate the attached page',
        handler = cmd_navigate,
    },
    {
        name = 'BrowserEval',
        nargs = '+',
        desc = 'Evaluate JavaScript in the page (confirms every time)',
        handler = cmd_eval,
    },
    {
        name = 'BrowserScreenshot',
        nargs = '?',
        desc = 'Screenshot the page to a PNG file',
        handler = cmd_screenshot,
    },
    {
        name = 'BrowserConsole',
        nargs = 0,
        desc = 'Show the bounded console/log tail',
        handler = cmd_console,
    },
    {
        name = 'BrowserNetwork',
        nargs = 0,
        desc = 'Show the bounded network request log',
        handler = cmd_network,
    },
}

---Register the :Browser* commands. Idempotent.
---@return boolean
function M.setup()
    assert(vim ~= nil and vim.api ~= nil, 'commands.setup needs Neovim')
    if M._setup_done then
        return true
    end
    M._setup_done = true
    for _, cmd in ipairs(COMMANDS) do
        local user_opts = { nargs = cmd.nargs, desc = cmd.desc }
        vim.api.nvim_create_user_command(cmd.name, cmd.handler, user_opts)
    end
    return true
end

---Test seam: replace the live connection.
---@param conn table|nil
function M._set_connection(conn)
    M._conn = conn
    M._console_ring = nil
    M._network_log = nil
end

return M
