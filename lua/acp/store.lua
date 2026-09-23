-- Opt-in private snapshots; endpoints and credentials are deliberately excluded.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local config, util = require('acp.config'), require('acp.util')
local M = {}
local FILES_MAX = 128

local function directory()
    return config.options.store.directory or vim.fs.joinpath(vim.fn.stdpath('state'), 'acp-agents')
end

function M.list()
    local result, scan = {}, vim.uv.fs_scandir(directory())
    if not scan then
        return result
    end
    for _ = 1, FILES_MAX + 1 do
        local name, kind = vim.uv.fs_scandir_next(scan)
        if not name then
            break
        end
        if kind == 'file' and name:match('^[%x%-]+%.json$') then
            result[#result + 1] = vim.fs.joinpath(directory(), name)
        end
    end
    table.sort(result)
    return result
end

function M.save(state)
    if not config.options.store.enabled then
        return true
    end
    local ok, err = util.mkdir(directory())
    if not ok then
        return nil, err
    end
    local root, failure = util.root(directory())
    if not root then
        return nil, failure
    end
    local path = vim.fs.joinpath(root, state.key .. '.json')
    if #M.list() >= FILES_MAX and not vim.uv.fs_lstat(path) then
        return nil, 'Saved conversation limit (128); remove old snapshots explicitly'
    end
    local value = {
        format = 1,
        agent_name = state.agent_name,
        protocol = state.agent.protocol,
        version = state.agent.version,
        cwd = state.cwd,
        key = state.key,
        remote = state.remote,
        prompt_parts = state.prompt_parts,
        delegation = state.delegation,
    }
    local encoded, problem = util.json(value)
    if not encoded then
        return nil, problem
    end
    return util.write(path, encoded)
end

function M.read(path)
    local root, err = util.root(directory())
    if not root then
        return nil, err
    end
    local resolved, failure = util.path(root, path)
    if not resolved then
        return nil, failure
    end
    local content, problem = util.read(resolved, util.BYTES_MAX)
    if not content then
        return nil, problem
    end
    local value, decode_error = util.decode(content)
    if not value then
        return nil, decode_error
    end
    if
        value.format ~= 1
        or type(value.remote) ~= 'table'
        or not util.string(value.agent_name, 64)
    then
        return nil, 'Invalid conversation snapshot'
    end
    return value
end
return M
