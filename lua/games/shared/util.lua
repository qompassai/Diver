-- /qompassai/Diver/lua/games/shared/util.lua
-- Qompass AI Games Shared Util
---@module 'games.shared.util'
local M = {}

function M.build_action_map(actions)
    local out = {}
    for i = 1, #actions do
        out[actions[i].id] = actions[i]
    end
    return out
end

function M.env_first(names)
    for i = 1, #names do
        local value = vim.env[names[i]]
        if value ~= nil and value ~= '' then
            return value
        end
    end
    return nil
end

function M.find_root(markers, start_dir)
    local dir = start_dir or vim.fn.getcwd()
    local found = vim.fs.find(markers, {
        upward = true,
        path = dir,
    })[1]
    if not found then
        return nil
    end
    return vim.fs.dirname(found)
end
function M.first_executable(candidates)
    for i = 1, #candidates do
        local candidate = candidates[i]
        if candidate ~= nil and candidate ~= '' then
            local expanded = vim.fn.expand(candidate)
            if vim.fn.executable(expanded) == 1 then
                return expanded
            end
        end
    end
    return nil
end
function M.first_existing_path(candidates)
    for i = 1, #candidates do
        local candidate = candidates[i]
        if candidate ~= nil and candidate ~= '' then
            local expanded = vim.fn.expand(candidate)
            if expanded ~= '' and (vim.fn.filereadable(expanded) == 1 or vim.fn.isdirectory(expanded) == 1) then
                return expanded
            end
            local glob = vim.fn.glob(expanded, false, true)
            if glob and #glob > 0 then
                return glob[1]
            end
        end
    end
    return nil
end
function M.get_action_ids(actions, arg_lead)
    local ids = {}
    for i = 1, #actions do
        local id = actions[i].id
        if arg_lead == '' or vim.startswith(id, arg_lead) then
            ids[#ids + 1] = id
        end
    end
    return ids
end
function M.is_mac()
    return vim.fn.has('mac') == 1 or vim.fn.has('macunix') == 1
end
function M.is_windows()
    return vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1
end
function M.read_file(path)
    local file = io.open(path, 'r')
    if not file then
        return nil
    end
    local content = file:read('*all')
    file:close()
    return content
end

function M.snake_to_pascal(str)
    return (str:gsub('(^%l)', string.upper):gsub('_(%l)', function(c)
        return c:upper()
    end))
end
function M.trim(s)
    return (s or ''):gsub('^%s*(.-)%s*$', '%1')
end

return M
