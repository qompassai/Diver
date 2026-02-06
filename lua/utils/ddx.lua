-- /qompassai/Diver/lua/utils/ddx.lua
-- Qompass AI Diver Util Differential Diagnosis (DDX) config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
local ERROR = vim.log.levels.ERROR
local ft = vim.bo.filetype
local notify = vim.notify
local uv = vim.uv
api.nvim_create_user_command('ConfigSelfCheck', function()
    require('tests.selfcheck').run()
end, {})
local function strip_ansi()
    vim.cmd([[%s/[\x1b]\[[0-9;]*m//g]])
end
api.nvim_create_autocmd('BufReadPost', {
    pattern = '*',
    callback = function()
        if ft == 'nvimpager' then
            strip_ansi()
        end
    end,
})
local function scandir(root)
    local handle = uv.fs_scandir(root)
    if not handle then
        return {}
    end
    local results = {}
    while true do
        local name, t = uv.fs_scandir_next(handle)
        if not name then
            break
        end
        table.insert(results, {
            name = name,
            type = t,
        })
    end
    return results
end
---@param root string
---@param path string
---@return string
local function to_module(root, path)
    local rel = path:gsub('^' .. vim.pesc(root) .. '/?', '')
    rel = rel:gsub('%.lua$', '')
    rel = rel:gsub('/', '.')
    if rel:match('%.init$') then
        rel = rel:gsub('%.init$', '')
    end
    return rel
end

---@return string[]
local function collect_lua_files(root) ---@param root string
    local files = {}
    local function walk(dir)
        for _, entry in ipairs(scandir(dir)) do
            local full = dir .. '/' .. entry.name
            if entry.type == 'file' and entry.name:match('%.lua$') then
                table.insert(files, full)
            elseif entry.type == 'directory' then
                walk(full)
            end
        end
    end
    walk(root)
    return files
end
local function selfcheck()
    local lua_root = vim.fn.stdpath('config') .. '/lua'
    local files = collect_lua_files(lua_root)
    local ok_count, err_count = 0, 0
    local state_dir = vim.fn.stdpath('state')
    local log_path = state_dir .. '/selfcheck.log'
    local fh = io.open(log_path, 'w')
    if fh then
        fh:write(('[selfcheck] %s\n'):format(os.date('%Y-%m-%d %H:%M:%S')))
        fh:write(('[selfcheck] lua_root=%s\n\n'):format(lua_root))
    end
    for _, file in ipairs(files) do
        local mod = to_module(lua_root, file)
        local ok, err = pcall(require, mod)
        if ok then
            ok_count = ok_count + 1
            if fh then
                fh:write(('[selfcheck] OK: %s\n'):format(mod))
            end
        else
            err_count = err_count + 1
            local short_file = file:gsub(lua_root .. '/', '')
            local msg = string.format('[selfcheck] %s FAILED:\n  %s\n  File: %s', mod, err, short_file)
            notify(msg, ERROR)
            if fh then
                fh:write(msg .. '\n')
                fh:write(string.rep('-', 80) .. '\n')
            end
        end
    end
    local summary = string.format('[selfcheck] %d OK, %d FAILED (log: %s)', ok_count, err_count, log_path)
    notify(summary, err_count == 0 and vim.log.levels.INFO or ERROR)
    if fh then
        fh:write(('\n[selfcheck] %d OK, %d FAILED\n'):format(ok_count, err_count))
        fh:close()
    end
end
return {
    run = selfcheck,
}
