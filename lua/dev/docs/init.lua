-- #################################################################
-- /qompassai/diver/lua/dev/docs.lua
-- Qompass AI Diver Docs-Meta (Tiger Style)
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################
---@module 'dev.docs'
--
-- In-editor query front for docs-meta: versioned language-reference
-- metadata. Agents and humans query locally; nobody curls docs.
--
-- Contract:
-- - Store root: ~/.local/share/diver/docs-meta (XDG_DATA_HOME-aware).
-- - `:DiverDocs <lang> [version] <query>` shows hits in a float.
-- - `:DiverDocsUpdate` regenerates metadata for the installed toolchains.
-- - Queries shell out to the `diver-docs` CLI (bundled in
--   lua/dev/docs/bin/); the Lua side never parses the JSON store itself.

local M = {}

local api = vim.api
local rce = require('security.rce')

local setup_done = false

---Path to the bundled CLI.
local function cli_path()
    return vim.fn.stdpath('config') .. '/lua/dev/docs/bin/diver-docs'
end

---Run a docs query; return decoded JSON or nil + err.
---@param lang string
---@param version string?|nil
---@param query string
---@return table? result, string? err
function M.query(lang, version, query)
    local args = { cli_path(), lang }
    if version ~= nil and version ~= '' then
        args[#args + 1] = version
    end
    args[#args + 1] = query
    local env = { DIVER_DOCS_META = M.store_root() }
    local result, exec_err = rce.safe_exec(args, { timeout_ms = 15000, env = env })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil)
    if result.code ~= 0 then
        return nil, vim.trim(result.stderr or 'no match')
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok then
        return nil, 'invalid JSON from diver-docs'
    end
    return decoded, nil
end

---Rebuild manifest.json from the store directories.
function M.refresh_manifest()
    local root = M.store_root()
    local manifest = {}
    for _, lang in ipairs(vim.fn.readdir(root)) do
        local dir = root .. '/' .. lang
        if vim.fn.isdirectory(dir) == 1 then
            local vers = {}
            for _, f in ipairs(vim.fn.readdir(dir)) do
                local v = f:match('^(.-)%.json$')
                if v and v ~= 'manifest' then
                    vers[#vers + 1] = v
                end
            end
            table.sort(vers, function(a, b)
                return a > b
            end)
            if #vers > 0 then
                manifest[lang] = vers
            end
        end
    end
    local f = io.open(root .. '/manifest.json', 'w')
    if f then
        f:write(vim.json.encode(manifest))
        f:write('\n')
        f:close()
    end
end

function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('DiverDocs', function(opts)
        local parts = vim.split(opts.args, '%s+', { trimempty = true })
        if #parts < 2 then
            vim.notify('DiverDocs: usage :DiverDocs <lang> [version] <query>', vim.log.levels.WARN)
            return
        end
        local lang = parts[1]
        local version, query
        -- Heuristic: if parts[2] looks like a version, treat it as one.
        if #parts >= 3 and parts[2]:match('^[%d%.]+$') then
            version = parts[2]
            query = table.concat(parts, ' ', 3)
        else
            query = table.concat(parts, ' ', 2)
        end
        M.show(lang, version, query)
    end, { nargs = '+', desc = 'Query versioned language reference metadata' })
    api.nvim_create_user_command('DiverDocsUpdate', function()
        M.update()
    end, { desc = 'Regenerate docs-meta for installed toolchains' })
end

---Show query hits in a float.
function M.show(lang, version, query)
    local result, err = M.query(lang, version, query)
    if err ~= nil then
        vim.notify('DiverDocs: ' .. err, vim.log.levels.WARN)
        return
    end
    assert(result ~= nil)
    local lines = {
        string.format(" %s %s — %d hit(s) for '%s' ", result.lang, result.version, #result.hits, result.query),
        '',
    }
    for _, h in ipairs(result.hits) do
        lines[#lines + 1] = ' ' .. h.path .. (h.sig and (' ' .. h.sig) or '')
        if h.doc ~= nil and h.doc ~= '' then
            lines[#lines + 1] = '   ' .. h.doc
        end
        lines[#lines + 1] = ''
    end
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local width = 0
    for _, l in ipairs(lines) do
        width = math.max(width, #l)
    end
    width = math.min(width + 2, 100)
    local height = math.min(#lines, 30)
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' diver-docs ',
    })
    vim.keymap.set('n', 'q', function()
        api.nvim_win_close(win, true)
    end, { buffer = buf, silent = true })
end

---XDG-aware store root.
function M.store_root()
    local xdg = os.getenv('XDG_DATA_HOME')
    local base = (xdg ~= nil and xdg ~= '') and xdg or (os.getenv('HOME') .. '/.local/share')
    return base .. '/diver/docs-meta'
end

---Regenerate metadata for installed toolchains.
function M.update()
    local root = M.store_root()
    vim.notify('DiverDocs: regenerating metadata into ' .. root)
    local bin = vim.fn.stdpath('config') .. '/lua/dev/docs/bin'
    local jobs = {
        { 'python3', bin .. '/py_introspect.py', '--out', root .. '/python' },
    }
    -- Lua via whichever interpreter is available.
    local lua_bin = vim.fn.exepath('lua') ~= '' and 'lua' or nil
    if lua_bin then
        jobs[#jobs + 1] = { lua_bin, bin .. '/lua_introspect.lua', '--out', root .. '/lua' }
    end
    for _, cmd in ipairs(jobs) do
        local result, exec_err = rce.safe_exec(cmd, { timeout_ms = 120000 })
        if exec_err ~= nil or result == nil or result.code ~= 0 then
            vim.notify('DiverDocs: updater failed: ' .. table.concat(cmd, ' '), vim.log.levels.ERROR)
        else
            vim.notify('DiverDocs: ' .. vim.trim(result.stdout or ''), vim.log.levels.INFO)
        end
    end
    -- Refresh the manifest.
    M.refresh_manifest()
end

return M
