-- /qompassai/Diver/tests/selfcheck.lua
-- Qompass AI Diver Selfcheck Test
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local function scandir(root)
    local handle = vim.uv.fs_scandir(root)
    if not handle then
        return {}
    end
    local results = {}
    while true do
        local name, t = vim.uv.fs_scandir_next(handle)
        if not name then
            break
        end
        table.insert(results, { name = name, type = t })
    end
    return results
end
local function to_module(root, path)
    local rel = path:gsub('^' .. vim.pesc(root) .. '/?', '')
    rel = rel:gsub('%.lua$', '')
    rel = rel:gsub('/', '.')
    if rel:match('%.init$') then
        rel = rel:gsub('%.init$', '')
    end
    return rel
end
local function collect_lua_files(root)
    local files = {}
    local function walk(dir)
        for _, entry in ipairs(scandir(dir)) do
            local full = dir .. '/' .. entry.name
            if entry.type == 'file' and entry.name:sub(-4) == '.lua' then
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
        fh:write(('[selfcheck] running in %s\n'):format(os.date('%Y-%m-%d %H:%M:%S')))
        fh:write(('[selfcheck] lua_root = %s\n\n'):format(lua_root))
    end
    for _, file in ipairs(files) do
        local mod = to_module(lua_root, file)
        local ok, err = pcall(require, mod)
        if not ok then
            err_count = err_count + 1
            local msg = ('[selfcheck] require("%s") failed: %s'):format(mod, err)
            vim.notify(msg, vim.log.levels.ERROR)
            if fh then
                fh:write(msg .. '\n')
            end
        else
            ok_count = ok_count + 1
            if fh then
                fh:write(('[selfcheck] OK: %s\n'):format(mod))
            end
        end
    end
    if fh then
        fh:write(('\n[selfcheck] %d modules OK, %d failed\n'):format(ok_count, err_count))
        fh:close()
    end
    vim.notify(
        ('[selfcheck] %d modules OK, %d failed (log: %s)'):format(ok_count, err_count, log_path),
        err_count == 0 and vim.log.levels.INFO or vim.log.levels.WARN
    )
end

return {
    run = selfcheck,
}