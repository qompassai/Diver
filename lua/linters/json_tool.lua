-- /qompassai/Diver/lua/linters/json_tool.lua
-- Qompass AI Diver Native JSON Syntax Linter
---@module 'linters.json_tool'
---@source https://docs.python.org/3/library/json.html
---
--- ELI5: This checks that your JSON is well-formed using Python's own
--- `json.tool`. It reads the buffer from stdin (`/dev/stdin`) and tries to
--- reprint it nicely. When the JSON is broken it fails with a message like
--- `Expecting property name enclosed in double quotes: line 1 column 2
--- (char 1)` on stderr. The adapter reads the line/column out of that
--- message and points at the broken spot. Valid JSON reports nothing.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR

local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 15000

local floor = math.floor
local type = type

local SOURCE = 'json_tool'

-- `...: line 1 column 2 (char 1)` (also matches `line 1 col 2`? No: only
-- the exact words json.tool emits)
local POSITION_PATTERN = '[Ll]ine (%d+)%s+[Cc]olumn (%d+)'

---@param value string
---@return string?
local function clean_message(value)
    assert(type(value) == 'string')

    local message = vim.trim(value:gsub('[%z\1-\8\11-\31\127]', ' '))

    if message == '' then
        return nil
    end

    if #message > MESSAGE_LENGTH_MAX then
        message = message:sub(1, MESSAGE_LENGTH_MAX) .. '…'
    end

    return message
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

---@param value string
---@param minimum integer
---@param maximum integer
---@return integer?
local function integer_in_range(value, minimum, maximum)
    assert(minimum >= 0)
    assert(maximum >= minimum)

    local parsed = tonumber(value)

    if parsed == nil or parsed ~= floor(parsed) then
        return nil
    end

    if parsed < minimum or parsed > maximum then
        return nil
    end

    ---@cast parsed integer
    return parsed
end

---@param output string
---@param _ LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _)
    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    if output == '' then
        return diagnostics
    end

    assert(#output <= OUTPUT_BYTES_MAX, 'json.tool output exceeded maximum size')

    -- json.tool prints one error, possibly across several stderr lines; the
    -- position phrase is the reliable part.
    for line in output:gmatch('[^\r\n]+') do
        if #line <= LINE_LENGTH_MAX then
            local row, column = line:match(POSITION_PATTERN)

            if row ~= nil then
                local parsed_row = integer_in_range(row, 1, 2147483647)
                local parsed_column = integer_in_range(column, 1, 2147483647)
                local cleaned = clean_message(line)

                if parsed_row ~= nil and parsed_column ~= nil and cleaned ~= nil then
                    diagnostics[#diagnostics + 1] = {
                        code = 'syntax',
                        col = parsed_column - 1,
                        end_col = parsed_column,
                        end_lnum = parsed_row - 1,
                        lnum = parsed_row - 1,
                        message = cleaned,
                        severity = ERROR,
                        source = SOURCE,
                    }
                    break
                end
            end
        end
    end

    return diagnostics
end

return ---@type Linter
{
    append_fname = false,
    args = {
        '-m',
        'json.tool',
        -- Read the buffer from stdin.
        '/dev/stdin',
    },
    automatic = true,
    cmd = 'python3',
    cwd = cwd,
    -- Invalid JSON exits nonzero; that is the normal diagnostic path.
    ignore_exitcode = true,
    parser = parse,
    root_markers = {
        '.git',
    },
    stdin = true,
    -- json.tool writes decode errors to stderr.
    stream = 'stderr',
    timeout = TIMEOUT_MS,
}
