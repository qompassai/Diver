-- /qompassai/lua/linters/janet.lua
-- Qompass AI Janet
---@module 'linters.janet'

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

---@param value string|number|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
    return math.floor(tonumber(value) or fallback)
end

---@param path string
---@return boolean
local function is_absolute(path)
    assert(type(path) == 'string')
    assert(path ~= '')

    return vim.fn.isabsolutepath(path) == 1
end

local function belongs_to_buffer(path, filename, root, basename)
    if path == '' or path == '-' then
        return true
    end

    local candidate

    if is_absolute(path) then
        candidate = fs.normalize(path)
    else
        candidate = fs.normalize(fs.joinpath(root, path))
    end

    return candidate == filename or fs.basename(candidate) == basename
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    if output == '' then
        return {}
    end

    if type(context) ~= 'table' then
        error('janet parser requires a LintContext', 0)
    end

    ---@cast context LintContext

    local filename = fs.normalize(context.filename)
    local basename = fs.basename(filename)
    local root = context.root

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    for line in output:gmatch('[^\r\n]+') do
        local path
        local lnum
        local col
        local message
        local level

        --
        -- Janet syntax/checking errors:
        --
        --   error: path/to/file.janet:12:7: message
        --
        path, lnum, col, message = line:match('^error:%s*(.-):(%d+):(%d+):%s*(.+)$')

        if path ~= nil then
            level = ERROR
        else
            --
            -- Janet --lint-warn diagnostics:
            --
            --   path/to/file.janet:12:7: message
            --
            path, lnum, col, message = line:match('^(.-):(%d+):(%d+):%s*(.+)$')

            if path ~= nil then
                level = WARN
            end
        end

        if path ~= nil and belongs_to_buffer(path, filename, root, basename) then
            local row = math.max(integer(lnum, 1) - 1, 0)
            local column = math.max(integer(col, 1) - 1, 0)

            diagnostics[#diagnostics + 1] = {
                col = column,
                end_col = column + 1,
                end_lnum = row,
                lnum = row,
                message = message,
                severity = level,
                source = 'janet',
            }
        end
    end

    return diagnostics
end

return ---@type Linter
{
    append_fname = false,
    args = {
        '-k',
    },
    automatic = false,
    cmd = 'janet',
    cwd = function(context)
        return context.root
    end,
    exit_codes = {
        [0] = true,
        [1] = true,
    },
    parser = parse,
    root_markers = {
        'project.janet',
        'jpm_tree',
        '.git',
    },
    stdin = true,
    stream = 'stderr',
    timeout = 30000,
}
