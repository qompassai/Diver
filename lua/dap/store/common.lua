-- ~/.config/nvim/lua/dap/store/common.lua
local uv = vim.uv

---@class DapStoreProjectRecord
---@field id string
---@field root string

---@class DapStoreSessionRecord
---@field id string
---@field project_id string
---@field host_name string
---@field adapter string
---@field configuration? string
---@field request? string
---@field executable? string
---@field cwd? string
---@field git_commit? string
---@field git_branch? string
---@field metadata? table

---@class DapStoreOutcomeRecord
---@field exit_code? integer
---@field result? string

---@class DapStoreEventRecord
---@field session_id string
---@field event_type string
---@field payload? table

---@class DapStoreBreakpointRecord
---@field id string
---@field project_id string
---@field path string
---@field line integer
---@field column_number? integer
---@field condition? string
---@field hit_condition? string
---@field log_message? string
---@field enabled? boolean

---@class DapStoreMetricRecord
---@field session_id string
---@field adapter string
---@field metric_name string
---@field metric_value number
---@field unit? string
---@field metadata? table

local M = {}

---@param cwd? string
---@return string?
function M.git_branch(cwd)
    if vim.fn.executable('git') ~= 1 then
        return nil
    end

    local branch_obj = vim.system({
        'git',
        '-C',
        cwd or vim.fn.getcwd(),
        'branch',
        '--show-current',
    }, {
        text = true,
    })
    ---@cast branch_obj vim.SystemObj
    local result = branch_obj:wait(1000)

    if result.code ~= 0 then
        return nil
    end

    local branch = vim.trim(result.stdout or '')
    return branch ~= '' and branch or nil
end
---@param cwd? string
---@return string?
function M.git_commit(cwd)
    if vim.fn.executable('git') ~= 1 then
        return nil
    end

    local commit_obj = vim.system({
        'git',
        '-C',
        cwd or vim.fn.getcwd(),
        'rev-parse',
        'HEAD',
    }, {
        text = true,
    })
    ---@cast commit_obj vim.SystemObj
    local result = commit_obj:wait(1000)

    if result.code ~= 0 then
        return nil
    end

    return vim.trim(result.stdout or '')
end

---@return string
function M.hostname()
    return uv.os_gethostname() or 'unknown'
end

---@param seed? string
---@return string
function M.id(seed)
    local material = table.concat({
        seed or '',
        tostring(uv.hrtime()),
        tostring(math.random()),
        tostring(vim.fn.getpid()),
    }, '\0')

    return vim.fn.sha256(material):sub(1, 32)
end

--- Encode a value as JSON for storage in a TEXT column. Returns nil and an
--- error on encode failure so callers can abort the query instead of
--- persisting a corrupt payload.
---@param value unknown
---@return string? encoded JSON as a SQL literal
---@return string? err encode or literal error
function M.json(value)
    local ok, encoded = pcall(vim.json.encode, value or {})
    if not ok then
        return nil, 'failed to encode JSON: ' .. tostring(encoded)
    end
    return M.literal(encoded)
end

--- Escape a Lua value as a SQL literal. Accepts only nil, booleans, finite
--- numbers, and strings; anything else is rejected with nil and an error so
--- callers cannot silently serialize tables or functions into queries.
---@param value unknown
---@return string? literal SQL-safe representation
---@return string?
function M.literal(value)
    if value == nil then
        return 'NULL'
    end

    if type(value) == 'boolean' then
        return value and 'TRUE' or 'FALSE'
    end

    if type(value) == 'number' then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil, 'non-finite SQL number'
        end
        return tostring(value)
    end

    if type(value) == 'string' then
        return "'" .. value:gsub("'", "''") .. "'"
    end

    return nil, 'cannot serialize value of type ' .. type(value)
end

---@param root string
---@return string
function M.project_id(root)
    return vim.fn.sha256(vim.fs.normalize(root)):sub(1, 32)
end

return M
