-- /qompassai/Diver/lua/plugins/edu/zotcite.lua
-- Qompass AI Diver Zotcite Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'plugins.edu.zotcite'
local M = {}
local sep = package.config:sub(1, 1)
local function join(...)
    return table.concat({ ... }, sep)
end
local function exists(p)
    return p and vim.uv.fs_stat(p) ~= nil
end
local function first_or_default(paths)
    for _, p in ipairs(paths) do
        if exists(p) then
            return p
        end
    end
    return paths[1]
end
local function find_bin(cmd)
    local home = vim.fn.expand('~')
    local user_bins = {
        join(home, '.local', 'bin', cmd),
        join(home, '.cargo', 'bin', cmd),
    }
    for _, p in ipairs(user_bins) do
        if exists(p) then
            return p
        end
    end
    return vim.fn.exepath(cmd) ~= '' and vim.fn.exepath(cmd) or cmd
end
local function xdg_data()
    return os.getenv('XDG_DATA_HOME') or join(vim.fn.expand('~'), '.local', 'share')
end
local function xdg_cache()
    return os.getenv('XDG_CACHE_HOME') or join(vim.fn.expand('~'), '.cache')
end
local function xdg_runtime()
    return os.getenv('XDG_RUNTIME_DIR') or vim.uv.os_tmpdir()
end
local cfg = {
    SQL_path = join(vim.fn.expand('~'), '.local', 'share', 'zotero', 'zotero.sqlite'),
    tmpdir = first_or_default({
        join(xdg_data(), 'zotcite'),
        join(xdg_runtime(), 'zotcite'),
        join(xdg_cache(), 'zotcite'),
        join(vim.uv.os_tmpdir(), 'zotcite'),
    }),
    python_path = find_bin('python3'),
    open_cmd = find_bin((vim.uv.os_uname().sysname == 'Darwin') and 'open' or 'xdg-open'),
    open_in_zotero = true,
    citation_template = '{Author}-{year}', ---@type string
    exclude_fields = 'attachment note', ---@type string
    sort_key = 'dateModified', ---@type string
    wait_attachment = false, ---@type boolean
}
if cfg.tmpdir and not exists(cfg.tmpdir) then
    vim.uv.fs_mkdir(cfg.tmpdir, 448)
end
function M.zotcite_cfg(extra)
    local ok, zot = pcall(require, 'zotcite')
    if not ok then
        vim.echo('[zotcite] plugin not found', vim.log.levels.WARN)
        return
    end
    zot.setup(vim.tbl_deep_extend('force', cfg, extra or {}))
end

return M
