-- /qompassai/Diver/lua/ai/mcp/server/tools.lua
-- Qompass AI MCP Server Tool Registry (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- The MCP tool surface diver exposes as a server: four read tools and
-- three write tools, all validated, bounded, and policy-gated.
--
-- Plain words: each tool declares its name, a JSON Schema for its
-- arguments, and honest annotations (readOnlyHint and friends -- hosts
-- use these to decide what to auto-approve, so a lie here is a privilege
-- escalation). Arguments are checked against the schema by hand, then
-- policy decides auto/confirm/deny, then the handler runs. A tool that
-- fails while running answers `{isError = true, ...}` -- a successful
-- JSON-RPC response -- while unknown tools, bad shapes, and policy
-- refusals are protocol errors (-32602 / -32000).
--
-- Subprocess tools use vim.system with argv arrays only -- there is no
-- code path that builds a shell string. rg is required for search_text;
-- diagnostics are phase-1 CLI linters (luacheck/ruff/shellcheck) when
-- installed, reported honestly when absent.

local policy = require('ai.mcp.server.policy')

local M = {}

local READ_LINES_MAX = 2000
local READ_LINE_BYTES_MAX = 8192
local LIST_ENTRIES_MAX = 500
local SEARCH_HITS_MAX = 100
local OUTPUT_BYTES_MAX = 256 * 1024
local CONTENT_BYTES_MAX = 512 * 1024
local STRING_ARG_BYTES_MAX = 1024 * 1024
local SEARCH_TIMEOUT_MS = 15000
local DIAG_TIMEOUT_MS = 15000
local COMMAND_TIMEOUT_MS_DEFAULT = 30000

local ERR_INVALID_PARAMS = -32602
local ERR_POLICY_DENIED = -32000
local ERR_INTERNAL = -32603

local by_name = {}
local registered = false

---@param text string
---@param is_error boolean?
---@return table result
local function tool_text(text, is_error)
    if #text > CONTENT_BYTES_MAX then
        text = text:sub(1, CONTENT_BYTES_MAX) .. '\n[output truncated]'
    end
    return { content = { { type = 'text', text = text } }, isError = is_error == true }
end

---@param text string
---@param limit integer
---@return string
local function truncate(text, limit)
    if #text > limit then
        return text:sub(1, limit) .. ' [truncated]'
    end
    return text
end

---@param name string
---@return boolean
local function has_executable(name)
    if vim == nil or vim.fn == nil or vim.fn.executable == nil then
        return false
    end
    return vim.fn.executable(name) == 1
end

-- Run vim.system synchronously. Real Neovim returns a SystemObj that must
-- be :wait()ed; the test stub returns the completed result table
-- directly. Returns (result, nil) or (nil, err).
---@param argv string[]
---@param opts table
---@return table? result
---@return string? err
local function system_sync(argv, opts)
    local ok, handle = pcall(vim.system, argv, opts)
    if not ok then
        return nil, 'failed to start: ' .. tostring(handle)
    end
    if type(handle) == 'table' and type(handle.wait) == 'function' then
        local wok, result = pcall(handle.wait, handle)
        if not wok then
            return nil, 'wait failed: ' .. tostring(result)
        end
        return result, nil
    end
    return handle, nil
end

---@param path string
---@return boolean
local function file_exists(path)
    local file = io.open(path, 'r')
    if file == nil then
        return false
    end
    file:close()
    return true
end

---@param path string
---@param byte_max integer
---@return string? content
---@return string? err
local function read_whole(path, byte_max)
    local file, open_err = io.open(path, 'r')
    if file == nil then
        return nil, tostring(open_err)
    end
    local size = file:seek('end')
    if size ~= nil and size > byte_max then
        file:close()
        return nil, 'file exceeds ' .. byte_max .. ' bytes'
    end
    file:seek('set')
    local content = file:read('*a')
    file:close()
    return content
end

---@param path string
---@return string? directory or nil for bare names
local function parent_dir(path)
    return path:match('^(.*)/[^/]*$')
end

-- Best-effort parent creation; the subsequent io.open still fails loudly
-- when creation did not happen, so this is convenience, not trust.
---@param path string?
local function mkdir_p(path)
    if path == nil or path == '' then
        return
    end
    if vim ~= nil and vim.fn ~= nil and vim.fn.mkdir ~= nil then
        pcall(vim.fn.mkdir, path, 'p')
    end
end

---@param path string
---@return table? stat
local function fs_stat(path)
    if vim ~= nil and vim.uv ~= nil and vim.uv.fs_stat ~= nil then
        local ok, stat = pcall(vim.uv.fs_stat, path)
        if ok then
            return stat
        end
    end
    return nil
end

---@param path string
---@return fun(): string?, string? iterator or nil when unavailable
local function fs_dir(path)
    if vim ~= nil and vim.fs ~= nil and vim.fs.dir ~= nil then
        local ok, iter = pcall(vim.fs.dir, path)
        if ok then
            return iter
        end
    end
    return nil
end

-- Minimal glob: `*` matches any run, `?` one char, everything else
-- literal. Used for list_files/search_text name filtering only.
---@param glob string
---@return string? pattern
---@return string? err
local function glob_to_pattern(glob)
    if glob:find('%c') then
        return nil, 'glob contains control characters'
    end
    local parts = { '^' }
    for i = 1, #glob do
        local c = glob:sub(i, i)
        if c == '*' then
            parts[#parts + 1] = '.*'
        elseif c == '?' then
            parts[#parts + 1] = '.'
        elseif c:find('[%^%$%(%)%%%.%[%]%+%-%?]') then
            parts[#parts + 1] = '%' .. c
        else
            parts[#parts + 1] = c
        end
    end
    parts[#parts + 1] = '$'
    return table.concat(parts)
end

-- Forward declaration: check_array and check_value recurse into each other.
local check_value

-- Validate one array-typed argument value against its schema.
---@param key string
---@param value table
---@param prop table
---@return boolean ok
---@return string? err
local function check_array(key, value, prop)
    if type(value) ~= 'table' then
        return false, 'argument ' .. key .. ' must be an array'
    end
    local count = #value
    local dense = 0
    for k in pairs(value) do
        if type(k) ~= 'number' or k < 1 or k > count or k % 1 ~= 0 then
            return false, 'argument ' .. key .. ' must be a dense array'
        end
        dense = dense + 1
    end
    if dense ~= count then
        return false, 'argument ' .. key .. ' must be a dense array'
    end
    if prop.minItems ~= nil and count < prop.minItems then
        return false, 'argument ' .. key .. ' needs at least ' .. prop.minItems .. ' items'
    end
    if prop.maxItems ~= nil and count > prop.maxItems then
        return false, 'argument ' .. key .. ' exceeds ' .. prop.maxItems .. ' items'
    end
    if prop.items ~= nil then
        for i, item in ipairs(value) do
            local ok, err = check_value(key .. '[' .. i .. ']', item, prop.items)
            if not ok then
                return false, err
            end
        end
    end
    return true
end

---@param key string
---@param value any
---@param prop table
---@return boolean ok
---@return string? err
function check_value(key, value, prop)
    local vtype = type(value)
    local ptype = prop.type
    if ptype == 'string' then
        if vtype ~= 'string' then
            return false, 'argument ' .. key .. ' must be a string'
        end
        if prop.minLength ~= nil and #value < prop.minLength then
            return false, 'argument ' .. key .. ' is too short'
        end
        if prop.maxLength ~= nil and #value > prop.maxLength then
            return false, 'argument ' .. key .. ' exceeds ' .. prop.maxLength .. ' bytes'
        end
    elseif ptype == 'integer' then
        if vtype ~= 'number' or value % 1 ~= 0 then
            return false, 'argument ' .. key .. ' must be an integer'
        end
        if prop.minimum ~= nil and value < prop.minimum then
            return false, 'argument ' .. key .. ' is below minimum ' .. prop.minimum
        end
        if prop.maximum ~= nil and value > prop.maximum then
            return false, 'argument ' .. key .. ' exceeds maximum ' .. prop.maximum
        end
    elseif ptype == 'boolean' then
        if vtype ~= 'boolean' then
            return false, 'argument ' .. key .. ' must be a boolean'
        end
    elseif ptype == 'array' then
        return check_array(key, value, prop)
    elseif ptype == 'object' then
        if vtype ~= 'table' then
            return false, 'argument ' .. key .. ' must be an object'
        end
    else
        return false, 'argument ' .. key .. ' has an unsupported schema type'
    end
    if prop.enum ~= nil then
        local allowed = false
        for _, choice in ipairs(prop.enum) do
            if choice == value then
                allowed = true
                break
            end
        end
        if not allowed then
            return false, 'argument ' .. key .. ' is not one of the allowed values'
        end
    end
    return true
end

-- Hand-rolled, bounded JSON Schema subset check. Unknown properties are
-- rejected: fail closed on shapes we did not declare.
---@param schema table
---@param args table
---@return boolean ok
---@return string? err
local function validate_args(schema, args)
    local required = schema.required or {}
    for _, key in ipairs(required) do
        if args[key] == nil then
            return false, 'missing required argument: ' .. key
        end
    end
    local properties = schema.properties or {}
    for key, value in pairs(args) do
        local prop = properties[key]
        if prop == nil then
            return false, 'unknown argument: ' .. tostring(key)
        end
        local ok, err = check_value(key, value, prop)
        if not ok then
            return false, err
        end
    end
    return true
end

---@param args table
---@return string
local function audit_target(args)
    if type(args.path) == 'string' then
        return args.path:sub(1, 256)
    end
    if type(args.dir) == 'string' then
        return args.dir:sub(1, 256)
    end
    if type(args.pattern) == 'string' then
        return args.pattern:sub(1, 256)
    end
    if type(args.cmd) == 'table' and type(args.cmd[1]) == 'string' then
        return args.cmd[1]:sub(1, 256)
    end
    return ''
end

---@param args table
---@return table? result
---@return table? err
local function handle_read_file(args)
    local path, perr = policy.scope_path(args.path)
    if path == nil then
        return nil, perr
    end
    local offset = args.offset or 1
    local limit = args.limit or READ_LINES_MAX
    if limit > READ_LINES_MAX then
        limit = READ_LINES_MAX
    end
    local file, open_err = io.open(path, 'r')
    if file == nil then
        return tool_text('cannot read file: ' .. tostring(open_err), true)
    end
    local lines = {}
    local index = 0
    local bytes = 0
    local truncated = false
    for line in file:lines() do
        index = index + 1
        if index >= offset then
            if #lines >= limit or bytes > CONTENT_BYTES_MAX then
                truncated = true
                break
            end
            if #line > READ_LINE_BYTES_MAX then
                line = line:sub(1, READ_LINE_BYTES_MAX) .. ' [line truncated]'
            end
            lines[#lines + 1] = line
            bytes = bytes + #line + 1
        end
    end
    file:close()
    local text = table.concat(lines, '\n')
    if truncated and bytes > CONTENT_BYTES_MAX then
        text = text .. '\n[output truncated at ' .. CONTENT_BYTES_MAX .. ' bytes]'
    end
    return tool_text(text)
end

---@param args table
---@return table? result
---@return table? err
local function handle_list_files(args)
    local dir = args.dir or policy.roots()[1]
    local scoped, perr = policy.scope_path(dir)
    if scoped == nil then
        return nil, perr
    end
    local stat = fs_stat(scoped)
    if stat == nil then
        return tool_text('directory not found: ' .. dir, true)
    end
    if stat.type ~= 'directory' then
        return tool_text('not a directory: ' .. dir, true)
    end
    local pattern = nil
    if args.glob ~= nil then
        local compiled, gerr = glob_to_pattern(args.glob)
        if compiled == nil then
            return nil, { code = ERR_INVALID_PARAMS, message = gerr }
        end
        pattern = compiled
    end
    local iter = fs_dir(scoped)
    if iter == nil then
        return tool_text('directory listing is unavailable', true)
    end
    local entries = {}
    local truncated = false
    local ok, iter_err = pcall(function()
        for name, ftype in iter do
            if pattern == nil or name:match(pattern) then
                if #entries >= LIST_ENTRIES_MAX then
                    truncated = true
                    break
                end
                entries[#entries + 1] = name .. (ftype == 'directory' and '/' or '')
            end
        end
    end)
    if not ok then
        return tool_text('cannot list directory: ' .. tostring(iter_err), true)
    end
    table.sort(entries)
    local text = table.concat(entries, '\n')
    if truncated then
        text = text .. '\n[truncated at ' .. LIST_ENTRIES_MAX .. ' entries]'
    end
    return tool_text(text)
end

---@param args table
---@return table? result
---@return table? err
local function handle_search_text(args)
    local dir = args.dir or policy.roots()[1]
    local scoped, perr = policy.scope_path(dir)
    if scoped == nil then
        return nil, perr
    end
    if vim == nil or vim.system == nil then
        return tool_text('subprocess execution is unavailable', true)
    end
    if not has_executable('rg') then
        return tool_text('search_text requires ripgrep (rg), which is not installed', true)
    end
    -- argv form only: the pattern travels as one literal argument, so
    -- shell metacharacters in it can never be interpreted.
    local argv = {
        'rg',
        '--no-heading',
        '--line-number',
        '--no-messages',
        '--max-count',
        tostring(SEARCH_HITS_MAX),
        '-e',
        args.pattern,
    }
    if args.glob ~= nil then
        argv[#argv + 1] = '-g'
        argv[#argv + 1] = args.glob
    end
    argv[#argv + 1] = '--'
    argv[#argv + 1] = scoped
    local result, serr = system_sync(argv, { timeout = SEARCH_TIMEOUT_MS, text = true })
    if result == nil then
        return tool_text('search ' .. serr, true)
    end
    if result.code == 1 then
        return tool_text('no matches')
    end
    if result.code ~= 0 then
        local detail = 'search failed (exit ' .. tostring(result.code) .. '): '
        return tool_text(detail .. truncate(result.stderr or '', 2048), true)
    end
    local hits = {}
    for line in (result.stdout or ''):gmatch('[^\n]+') do
        if #hits >= SEARCH_HITS_MAX then
            break
        end
        if #line > READ_LINE_BYTES_MAX then
            line = line:sub(1, READ_LINE_BYTES_MAX) .. ' [line truncated]'
        end
        hits[#hits + 1] = line
    end
    return tool_text(table.concat(hits, '\n'))
end

local PHASE1_LINTERS = {
    lua = { 'luacheck', '--no-color' },
    py = { 'ruff', 'check', '--output-format=concise', '--no-cache' },
    sh = { 'shellcheck', '-f', 'gcc' },
}

-- Phase 1 diagnostics: repo CLI linters only, bounded by timeout and
-- output cap. A missing linter is reported honestly as an execution
-- failure, never faked. (Phase 2 will use live vim.diagnostic via the
-- bridge.)
---@param args table
---@return table? result
---@return table? err
local function handle_get_diagnostics(args)
    if vim == nil or vim.system == nil then
        return tool_text('subprocess execution is unavailable', true)
    end
    local argv
    if args.path ~= nil then
        local scoped, perr = policy.scope_path(args.path)
        if scoped == nil then
            return nil, perr
        end
        local ext = scoped:match('%.([^./]+)$')
        local spec = ext and PHASE1_LINTERS[ext] or nil
        if spec == nil then
            return tool_text('no phase-1 linter for extension .' .. tostring(ext or '?'), true)
        end
        if not has_executable(spec[1]) then
            return tool_text('linter not installed: ' .. spec[1], true)
        end
        argv = {}
        for _, part in ipairs(spec) do
            argv[#argv + 1] = part
        end
        argv[#argv + 1] = scoped
    else
        if not has_executable('luacheck') then
            return tool_text('linter not installed: luacheck', true)
        end
        argv = { 'luacheck', '--no-color', policy.roots()[1] }
    end
    local result, serr = system_sync(argv, { timeout = DIAG_TIMEOUT_MS, text = true })
    if result == nil then
        return tool_text('diagnostics ' .. serr, true)
    end
    local output = truncate((result.stdout or '') .. (result.stderr or ''), OUTPUT_BYTES_MAX)
    if output == '' then
        return tool_text('no issues')
    end
    -- Linters exit nonzero when they find things; findings are data.
    return tool_text(output)
end

---@param args table
---@return table? result
---@return table? err
local function handle_write_file(args)
    local path, perr = policy.scope_path(args.path)
    if path == nil then
        return nil, perr
    end
    if args.mode == 'create' and file_exists(path) then
        return tool_text('file exists; mode=create refuses to overwrite: ' .. args.path, true)
    end
    mkdir_p(parent_dir(path))
    local file, open_err = io.open(path, 'w')
    if file == nil then
        return tool_text('cannot write file: ' .. tostring(open_err), true)
    end
    file:write(args.content)
    file:close()
    return tool_text('wrote ' .. #args.content .. ' bytes to ' .. args.path)
end

-- Exact-match replacement only: zero matches or more than one match both
-- fail loudly. The tool never fuzzes, so a typo cannot rewrite the wrong
-- text.
---@param args table
---@return table? result
---@return table? err
local function handle_edit_file(args)
    local path, perr = policy.scope_path(args.path)
    if path == nil then
        return nil, perr
    end
    local content, read_err = read_whole(path, CONTENT_BYTES_MAX)
    if content == nil then
        return tool_text('cannot read file: ' .. tostring(read_err), true)
    end
    local first_start, first_end = content:find(args.old_text, 1, true)
    if first_start == nil then
        return tool_text('old_text not found; no changes made', true)
    end
    if content:find(args.old_text, first_end + 1, true) ~= nil then
        return tool_text('old_text matches more than once; refusing ambiguous edit', true)
    end
    local updated = content:sub(1, first_start - 1) .. args.new_text .. content:sub(first_end + 1)
    local file, open_err = io.open(path, 'w')
    if file == nil then
        return tool_text('cannot write file: ' .. tostring(open_err), true)
    end
    file:write(updated)
    file:close()
    local summary = 'replaced 1 occurrence ('
            .. #args.old_text
            .. ' -> '
            .. #args.new_text
            .. ' bytes)'
    return tool_text(summary)
end

---@param args table
---@return table? result
---@return table? err
local function handle_run_command(args)
    local checked, cerr = policy.check_command(args.cmd, args.cwd)
    if checked == nil then
        return nil, cerr
    end
    if vim == nil or vim.system == nil then
        return tool_text('subprocess execution is unavailable', true)
    end
    local program = checked.argv[1]
    if not has_executable(program) then
        return tool_text('command not found on PATH: ' .. program, true)
    end
    -- vim.system with an argv table never invokes a shell: each element
    -- is passed literally (shell = false, always).
    local result, serr = system_sync(checked.argv, {
        cwd = checked.cwd,
        timeout = args.timeout_ms or COMMAND_TIMEOUT_MS_DEFAULT,
        text = true,
    })
    if result == nil then
        return tool_text('command ' .. serr, true)
    end
    local output = truncate((result.stdout or '') .. (result.stderr or ''), OUTPUT_BYTES_MAX)
    local text = 'exit code: ' .. tostring(result.code) .. '\n' .. output
    return tool_text(text, result.code ~= 0)
end

---@class McpToolDef
---@field name string lowercase snake_case tool name.
---@field title string Human-readable title.
---@field description string What the tool does.
---@field inputSchema table JSON Schema (hand-validated subset).
---@field annotations table readOnlyHint/destructiveHint/idempotentHint/openWorldHint.
---@field handler fun(args: table): table?, table?

---@param def McpToolDef
local function register(def)
    assert(type(def) == 'table', 'tool def must be a table')
    assert(type(def.name) == 'string', 'tool name must be a string')
    assert(def.name:match('^[a-z][a-z0-9_]*$'), 'tool name must be snake_case')
    assert(type(def.title) == 'string' and def.title ~= '', 'tool needs a title')
    assert(type(def.description) == 'string' and def.description ~= '', 'tool needs a description')
    assert(type(def.inputSchema) == 'table', 'tool needs an inputSchema')
    assert(type(def.annotations) == 'table', 'tool needs annotations')
    assert(type(def.handler) == 'function', 'tool needs a handler')
    assert(by_name[def.name] == nil, 'duplicate tool: ' .. def.name)
    by_name[def.name] = def
end

local function def_read_file()
    return {
        name = 'read_file',
        title = 'Read file',
        description = 'Read a text file inside the workspace roots. Returns a bounded line window '
            .. '(offset is 1-based, at most 2000 lines per call).',
        inputSchema = {
        type = 'object',
        properties = {
            path = { type = 'string', maxLength = 4096 },
            offset = { type = 'integer', minimum = 1 },
            limit = { type = 'integer', minimum = 1 },
        },
        required = { 'path' },
        },
        annotations = {
        readOnlyHint = true,
        destructiveHint = false,
        idempotentHint = true,
        openWorldHint = false,
        },
        handler = handle_read_file,
    }
end

local function def_list_files()
    return {
        name = 'list_files',
        title = 'List files',
        description = 'List directory entries inside the workspace roots, newest of at most 500 '
            .. 'entries sorted by name. Directories end with `/`.',
        inputSchema = {
        type = 'object',
        properties = {
            dir = { type = 'string', maxLength = 4096 },
            glob = { type = 'string', maxLength = 256 },
        },
        required = {},
        },
        annotations = {
        readOnlyHint = true,
        destructiveHint = false,
        idempotentHint = true,
        openWorldHint = false,
        },
        handler = handle_list_files,
    }
end

local function def_search_text()
    return {
        name = 'search_text',
        title = 'Search text',
        description = 'Search file contents with ripgrep (argv form, never a shell). '
            .. 'At most 100 hits per call.',
        inputSchema = {
        type = 'object',
        properties = {
            pattern = { type = 'string', maxLength = 4096 },
            dir = { type = 'string', maxLength = 4096 },
            glob = { type = 'string', maxLength = 256 },
        },
        required = { 'pattern' },
        },
        annotations = {
        readOnlyHint = true,
        destructiveHint = false,
        idempotentHint = true,
        openWorldHint = false,
        },
        handler = handle_search_text,
    }
end

local function def_get_diagnostics()
    return {
        name = 'get_diagnostics',
        title = 'Get diagnostics',
        description = 'Phase-1 diagnostics via repo CLI linters (luacheck, ruff, shellcheck) '
            .. 'when installed. Honest when no linter applies.',
        inputSchema = {
        type = 'object',
        properties = {
            path = { type = 'string', maxLength = 4096 },
        },
        required = {},
        },
        annotations = {
        readOnlyHint = true,
        destructiveHint = false,
        idempotentHint = true,
        openWorldHint = false,
        },
        handler = handle_get_diagnostics,
    }
end

local function def_write_file()
    return {
        name = 'write_file',
        title = 'Write file',
        description = 'Write content to a file inside the workspace roots. mode=create refuses '
            .. 'when the file exists; mode=overwrite must be chosen explicitly. Needs a '
            .. 'confirmation grant.',
        inputSchema = {
        type = 'object',
        properties = {
            path = { type = 'string', maxLength = 4096 },
            content = { type = 'string', maxLength = STRING_ARG_BYTES_MAX },
            mode = { type = 'string', enum = { 'create', 'overwrite' } },
        },
        required = { 'path', 'content', 'mode' },
        },
        annotations = {
        readOnlyHint = false,
        destructiveHint = true,
        idempotentHint = false,
        openWorldHint = false,
        },
        handler = handle_write_file,
    }
end

local function def_edit_file()
    return {
        name = 'edit_file',
        title = 'Edit file',
        description = 'Replace one exact occurrence of old_text with new_text (plain string '
            .. 'match, no fuzzy matching). Fails when old_text is absent or ambiguous. '
            .. 'Needs a confirmation grant.',
        inputSchema = {
        type = 'object',
        properties = {
            path = { type = 'string', maxLength = 4096 },
            old_text = { type = 'string', minLength = 1, maxLength = STRING_ARG_BYTES_MAX },
            new_text = { type = 'string', maxLength = STRING_ARG_BYTES_MAX },
        },
        required = { 'path', 'old_text', 'new_text' },
        },
        annotations = {
        readOnlyHint = false,
        destructiveHint = true,
        idempotentHint = false,
        openWorldHint = false,
        },
        handler = handle_edit_file,
    }
end

local function def_run_command()
    return {
        name = 'run_command',
        title = 'Run command',
        description = 'Run a command as an argv array (never a shell string). argv[0] must be '
            .. 'a bare name from the allowlist, which defaults to empty (deny-all). '
            .. 'Needs a confirmation grant.',
        inputSchema = {
        type = 'object',
        properties = {
            cmd = {
                type = 'array',
                items = { type = 'string', maxLength = 4096 },
                minItems = 1,
                maxItems = 32,
            },
            cwd = { type = 'string', maxLength = 4096 },
            timeout_ms = {
                type = 'integer',
                minimum = policy.COMMAND_TIMEOUT_MS_MIN,
                maximum = policy.COMMAND_TIMEOUT_MS_MAX,
            },
        },
        required = { 'cmd' },
        },
        annotations = {
        readOnlyHint = false,
        destructiveHint = true,
        idempotentHint = false,
        openWorldHint = true,
        },
        handler = handle_run_command,
    }
end
local function register_all()
    register(def_read_file())
    register(def_list_files())
    register(def_search_text())
    register(def_get_diagnostics())
    register(def_write_file())
    register(def_edit_file())
    register(def_run_command())
end

-- Idempotent: registers the seven MVP tools once per process.
---@return boolean
function M.setup()
    if registered then
        return true
    end
    register_all()
    registered = true
    return true
end

---@param def McpToolDef
function M.register(def)
    register(def)
end

-- Tool descriptors for tools/list, sorted by name for determinism.
-- Handlers are never exposed over the wire.
---@return table[]
function M.list()
    local names = {}
    for name in pairs(by_name) do
        names[#names + 1] = name
    end
    table.sort(names)
    local out = {}
    for _, name in ipairs(names) do
        local def = by_name[name]
        out[#out + 1] = {
            name = def.name,
            title = def.title,
            description = def.description,
            inputSchema = def.inputSchema,
            annotations = def.annotations,
        }
    end
    return out
end

-- Dispatch a tools/call. Unknown tools, bad shapes, and policy refusals
-- are protocol errors (nil + {code, message}); failures while running
-- are `{isError = true}` results. Never raises.
---@param name string
---@param args table
---@param meta table?
---@return table? result
---@return table? err {code, message}
function M.call(name, args, meta)
    if type(name) ~= 'string' then
        return nil, { code = ERR_INVALID_PARAMS, message = 'tool name must be a string' }
    end
    local def = by_name[name]
    if def == nil then
        policy.audit(name, '', 'unknown-tool')
        return nil, { code = ERR_INVALID_PARAMS, message = 'unknown tool: ' .. name }
    end
    if type(args) ~= 'table' then
        return nil, { code = ERR_INVALID_PARAMS, message = 'arguments must be an object' }
    end
    local target = audit_target(args)
    local valid, verr = validate_args(def.inputSchema, args)
    if not valid then
        policy.audit(name, target, 'invalid-args')
        return nil, { code = ERR_INVALID_PARAMS, message = verr }
    end
    local allowed, reason = policy.check_approval(name, meta)
    if not allowed then
        policy.audit(name, target, 'denied')
        return nil, { code = ERR_POLICY_DENIED, message = reason }
    end
    local ok, result, herr = pcall(def.handler, args)
    if not ok then
        policy.audit(name, target, 'crashed')
        return nil, { code = ERR_INTERNAL, message = 'tool handler failed' }
    end
    if result == nil then
        policy.audit(name, target, 'handler-error')
        local code = ERR_INTERNAL
        local message = 'tool failed'
        if type(herr) == 'table' then
            if type(herr.code) == 'number' then
                code = herr.code
            end
            if type(herr.message) == 'string' then
                message = herr.message
            end
        end
        return nil, { code = code, message = message }
    end
    policy.audit(name, target, 'allowed')
    return result
end

return M
