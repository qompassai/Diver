-- ~/.config/nvim/lua/dap/store/common.lua
local uv = vim.uv

local M = {}

--- Escape a Lua value as a SQL literal. Accepts only nil, booleans, finite
--- numbers, and strings; anything else is rejected with nil and an error so
--- callers cannot silently serialize tables or functions into queries.
---@param value unknown
---@return string? literal SQL-safe representation
---@return string? err rejection reason when the value is not literal-safe
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

---@param root string
---@return string
function M.project_id(root)
    return vim.fn.sha256(vim.fs.normalize(root)):sub(1, 32)
end

---@return string
function M.hostname()
    return uv.os_gethostname() or 'unknown'
end

---@param cwd? string
---@return string?
function M.git_commit(cwd)
    if vim.fn.executable('git') ~= 1 then
        return nil
    end

    local result = vim.system({
        'git',
        '-C',
        cwd or vim.fn.getcwd(),
        'rev-parse',
        'HEAD',
    }, {
        text = true,
    }):wait(1000)

    if result.code ~= 0 then
        return nil
    end

    return vim.trim(result.stdout or '')
end

---@param cwd? string
---@return string?
function M.git_branch(cwd)
    if vim.fn.executable('git') ~= 1 then
        return nil
    end

    local result = vim.system({
        'git',
        '-C',
        cwd or vim.fn.getcwd(),
        'branch',
        '--show-current',
    }, {
        text = true,
    }):wait(1000)

    if result.code ~= 0 then
        return nil
    end

    local branch = vim.trim(result.stdout or '')
    return branch ~= '' and branch or nil
end

return M
