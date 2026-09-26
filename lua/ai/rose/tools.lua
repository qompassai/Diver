-- /qompassai/Diver/lua/ai/rose/tools.lua
-- Bounded native host tools for the agent (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Language-agnostic, plugin-free, synchronous tool boundary for the Rose
-- agent. All file access is confined to the configured workspace root;
-- writes and check execution additionally require explicit trust. Results
-- are plain serializable tables; expected failures are status tables, not
-- Lua errors.

local M = {}

local uv = vim.uv or vim.loop

local FILE_BYTES_MAX = 1024 * 1024
local LIST_LIMIT_MAX = 1000
local CHECK_OUTPUT_MAX = 65536
local LSP_TIMEOUT_DEFAULT = 5000
local LSP_TIMEOUT_MAX = 30000

local state = { root = nil, trusted = false, checks = {} }

---@param opts table? { workspace: string, trusted: boolean, checks: table }
---@return table self
function M.setup(opts)
    opts = opts or {}
    local root = opts.workspace or uv.cwd()
    assert(type(root) == 'string' and root ~= '', 'tools.setup: workspace must be a path')
    root = vim.fn.fnamemodify(root, ':p'):gsub('[/\\]+$', '')
    if root == '' then
        root = '/'
    end
    local real = uv.fs_realpath(root)
    assert(real, 'tools.setup: workspace does not exist')
    state.root = real
    state.trusted = opts.trusted == true
    state.checks = opts.checks or {}
    return M
end

-- Resolve a workspace-relative path to an absolute path inside the root.
-- Returns nil, err when the path escapes the workspace or is unsafe.
---@param path string?
---@return string? absolute
---@return string? err
local function resolve_path(path)
    if not state.root then
        return nil, 'tools are not set up'
    end
    if path == nil or path == '' then
        return nil, 'path is required'
    end
    if type(path) ~= 'string' or path:find('\0', 1, true) then
        return nil, 'invalid path'
    end
    local joined = vim.fs.joinpath(state.root, path)
    local real = uv.fs_realpath(joined) or uv.fs_realpath(vim.fn.fnamemodify(joined, ':h'))
    if not real then
        -- Nonexistent target: resolve the parent and re-append the final component.
        local parent = vim.fn.fnamemodify(joined, ':h')
        local real_parent = uv.fs_realpath(parent)
        if not real_parent then
            return nil, 'path does not resolve inside the workspace'
        end
        real = vim.fs.joinpath(real_parent, vim.fn.fnamemodify(joined, ':t'))
    end
    if real ~= state.root and real:sub(1, #state.root + 1) ~= state.root .. '/' then
        return nil, 'path escapes the workspace'
    end
    return real
end

---@param bufnr integer
---@return table snapshot
local function buffer_snapshot(bufnr)
    return {
        bufnr = bufnr,
        filetype = vim.bo[bufnr].filetype,
        changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
        modified = vim.bo[bufnr].modified,
        loaded = vim.api.nvim_buf_is_loaded(bufnr),
    }
end

-- Find the buffer holding the path, or the current buffer when path is nil.
---@param path string?
---@return integer? bufnr
---@return string? absolute
local function target_buffer(path)
    if path == nil then
        return vim.api.nvim_get_current_buf(), nil
    end
    local absolute, err = resolve_path(path)
    if not absolute then
        return nil, err
    end
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(bufnr) == absolute then
            return bufnr, absolute
        end
    end
    return nil, absolute
end

---@param absolute string
---@return string? content
---@return string? err
local function read_file_bytes(absolute)
    local stat = uv.fs_stat(absolute)
    if not stat or stat.type ~= 'file' then
        return nil, 'not a file'
    end
    if stat.size > FILE_BYTES_MAX then
        return nil, 'file exceeds size limit'
    end
    local fd = uv.fs_open(absolute, 'r', 438)
    if not fd then
        return nil, 'could not open file'
    end
    local data = uv.fs_read(fd, stat.size, 0)
    uv.fs_close(fd)
    if type(data) ~= 'string' then
        return nil, 'could not read file'
    end
    if data:find('\0', 1, true) then
        return nil, 'binary files are not supported'
    end
    return data
end

---@param args table
---@return table result
local function file_read(args)
    local bufnr, absolute = target_buffer(args.path)
    if type(bufnr) ~= 'number' and absolute == nil then
        return { status = 'error', error = tostring(absolute) }
    end
    if bufnr and vim.api.nvim_buf_is_loaded(bufnr) then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local content = table.concat(lines, '\n')
        return {
            status = 'ok',
            path = args.path,
            content = content,
            sha256 = vim.fn.sha256(content),
            changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
            live_buffer = true,
        }
    end
    local content, err
    do
        local path = absolute
        if path == nil and type(bufnr) == 'number' then
            path = vim.api.nvim_buf_get_name(bufnr)
        end
        if path == nil or path == '' then
            return { status = 'error', error = 'could not resolve target path' }
        end
        content, err = read_file_bytes(path)
    end
    if not content then
        return { status = 'error', error = err }
    end
    return { status = 'ok', path = args.path, content = content, sha256 = vim.fn.sha256(content) }
end

-- Atomic write through a temp file plus rename; parents must already exist.
---@param args table
---@return table result
local function file_write(args)
    if not state.trusted then
        return { status = 'error', error = 'file_write requires a trusted workspace' }
    end
    local absolute, err = resolve_path(args.path)
    if not absolute then
        return { status = 'error', error = err }
    end
    if type(args.content) ~= 'string' then
        return { status = 'error', error = 'content must be a string' }
    end
    if #args.content > FILE_BYTES_MAX then
        return { status = 'error', error = 'content exceeds size limit' }
    end
    if args.expected_sha256 ~= nil and type(args.expected_sha256) ~= 'string' then
        return { status = 'error', error = 'expected_sha256 must be a string' }
    end
    local parent = vim.fn.fnamemodify(absolute, ':h')
    if uv.fs_stat(parent) == nil then
        return { status = 'error', error = 'parent directory does not exist' }
    end
    local bufnr = target_buffer(args.path)
    if type(bufnr) == 'number' and vim.api.nvim_buf_is_loaded(bufnr) then
        if vim.bo[bufnr].modified then
            return { status = 'error', error = 'buffer has unsaved changes; read it first' }
        end
        if vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then
            return { status = 'error', error = 'buffer is read-only' }
        end
        if
            args.expected_changedtick ~= nil
            and vim.api.nvim_buf_get_changedtick(bufnr) ~= args.expected_changedtick
        then
            return { status = 'error', error = 'buffer changed since it was read' }
        end
    end
    if args.expected_sha256 then
        local current = read_file_bytes(absolute)
        if current and vim.fn.sha256(current) ~= args.expected_sha256 then
            return { status = 'error', error = 'file changed on disk since it was read' }
        end
    end
    local tmp = absolute .. '.rose-tmp-' .. tostring(uv.os_getpid())
    local fd = uv.fs_open(tmp, 'w', 420)
    if not fd then
        return { status = 'error', error = 'could not create temp file' }
    end
    local wrote = uv.fs_write(fd, args.content, -1)
    uv.fs_close(fd)
    if wrote ~= #args.content then
        uv.fs_unlink(tmp)
        return { status = 'error', error = 'could not write temp file' }
    end
    if not uv.fs_rename(tmp, absolute) then
        uv.fs_unlink(tmp)
        return { status = 'error', error = 'could not replace file' }
    end
    if type(bufnr) == 'number' and vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_buf_call(bufnr, function()
            vim.cmd('silent! edit!')
        end)
    end
    return { status = 'ok', path = args.path, bytes = #args.content }
end

---@param args table
---@return table result
local function file_list(args)
    local absolute, err = resolve_path(args.path or '.')
    if not absolute then
        return { status = 'error', error = err }
    end
    local limit = math.min(args.limit or LIST_LIMIT_MAX, LIST_LIMIT_MAX)
    local handle = uv.fs_scandir(absolute)
    if not handle then
        return { status = 'error', error = 'not a directory' }
    end
    local entries = {}
    while #entries < limit do
        local name, ftype = uv.fs_scandir_next(handle)
        if not name then
            break
        end
        -- lstat, never follow: unsafe symlinks are reported, not traversed.
        local stat = uv.fs_lstat(vim.fs.joinpath(absolute, name))
        entries[#entries + 1] = {
            name = name,
            type = ftype,
            link = stat and stat.type == 'link' or false,
            size = stat and stat.size or nil,
        }
    end
    return { status = 'ok', path = args.path or '.', entries = entries }
end

---@param absolute string?
---@return table clients
local function lsp_clients(absolute)
    local clients = {}
    for _, client in ipairs(vim.lsp.get_clients()) do
        local relevant = true
        if type(absolute) == 'string' and absolute ~= '' then
            relevant = false
            local prefix = absolute
            local stat = uv.fs_stat(absolute)
            if stat and stat.type == 'directory' then
                prefix = absolute .. '/'
            end
            for bufnr in pairs(client.attached_buffers or {}) do
                local name = vim.api.nvim_buf_get_name(bufnr)
                if name == absolute or name:sub(1, #prefix) == prefix then
                    relevant = true
                    break
                end
            end
        end
        if relevant then
            table.insert(clients, { id = client.id, name = client.name })
        end
    end
    return clients
end

---@param args table
---@return table result
local function editor_context(args)
    local bufnr, absolute = target_buffer(args.path)
    if type(bufnr) ~= 'number' then
        return { status = 'error', error = tostring(absolute) }
    end
    local snapshot = buffer_snapshot(bufnr)
    local dirty = {}
    for _, other in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(other) and vim.bo[other].modified then
            dirty[#dirty + 1] = vim.api.nvim_buf_get_name(other)
        end
    end
    local check_names = {}
    for name in pairs(state.checks) do
        check_names[#check_names + 1] = name
    end
    table.sort(check_names)
    return {
        status = 'ok',
        workspace = state.root,
        trusted = state.trusted,
        path = absolute or vim.api.nvim_buf_get_name(bufnr),
        bufnr = snapshot.bufnr,
        filetype = snapshot.filetype,
        changedtick = snapshot.changedtick,
        modified = snapshot.modified,
        loaded = snapshot.loaded,
        dirty_buffers = dirty,
        workspace_snapshot = { root = state.root, dirty_buffers = dirty },
        workspace_snapshot_version = 1,
        lsp = { status = 'unverified', clients = lsp_clients(absolute) },
        checks = check_names,
        verified = false,
    }
end

---@param args table
---@return table result
local function editor_diagnostics(args)
    local bufnr, absolute = target_buffer(args.path)
    if type(bufnr) ~= 'number' then
        return { status = 'error', error = tostring(absolute) }
    end
    local items = {}
    for _, diag in ipairs(vim.diagnostic.get(bufnr)) do
        items[#items + 1] = {
            lnum = diag.lnum + 1,
            col = diag.col,
            severity = diag.severity,
            message = diag.message,
            source = diag.source,
        }
    end
    return { status = 'ok', diagnostics = items }
end

-- Synchronous bounded LSP request against the buffer's attached clients.
---@param method string
---@param params table
---@param timeout integer
---@param bufnr integer
---@return table result
local function lsp_request(method, params, timeout, bufnr)
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if #clients == 0 then
        return { status = 'unavailable', error = 'no LSP client attached' }
    end
    local responses = vim.lsp.buf_request_sync(bufnr, method, params, timeout)
    if not responses then
        return { status = 'error', error = 'LSP request timed out' }
    end
    local results = {}
    for client_id, response in pairs(responses) do
        if response.error then
            results[#results + 1] = {
                client = client_id,
                error = tostring(response.error.message or response.error),
            }
        elseif response.result then
            results[#results + 1] = { client = client_id, result = response.result }
        end
    end
    return { status = 'ok', responses = results }
end

---@param args table
---@return table result
local function editor_symbols(args)
    local bufnr, absolute = target_buffer(args.path)
    if type(bufnr) ~= 'number' then
        return { status = 'error', error = tostring(absolute) }
    end
    local timeout = args.timeout or LSP_TIMEOUT_DEFAULT
    return lsp_request(
        'textDocument/documentSymbol',
        { textDocument = { uri = vim.uri_from_bufnr(bufnr) } },
        math.min(timeout, LSP_TIMEOUT_MAX),
        bufnr
    )
end

---@param args table
---@return table result
local function editor_references(args)
    local bufnr, absolute = target_buffer(args.path)
    if type(bufnr) ~= 'number' then
        return { status = 'error', error = tostring(absolute) }
    end
    if type(args.line) ~= 'number' or type(args.column) ~= 'number' then
        return { status = 'error', error = 'line and column are required' }
    end
    local timeout = args.timeout or LSP_TIMEOUT_DEFAULT
    return lsp_request('textDocument/references', {
        textDocument = { uri = vim.uri_from_bufnr(bufnr) },
        position = { line = args.line - 1, character = args.column },
        context = { includeDeclaration = args.include_declaration == true },
    }, math.min(timeout, LSP_TIMEOUT_MAX), bufnr)
end

-- Native lint: Lua files are syntax-checked with load(); anything else is unavailable.
---@param args table
---@return table result
local function editor_lint(args)
    local bufnr, absolute = target_buffer(args.path)
    if type(bufnr) ~= 'number' then
        return { status = 'error', error = tostring(absolute) }
    end
    local filetype = vim.bo[bufnr].filetype
    if filetype ~= 'lua' then
        return { status = 'unavailable', error = 'no native linter for filetype ' .. filetype }
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local chunk, err = load(table.concat(lines, '\n'), '@' .. (absolute or 'buffer'))
    if not chunk then
        return { status = 'failed', verified = false, error = err }
    end
    return { status = 'ok', verified = true, filetype = filetype }
end

-- Run one named argv check, or every check relevant to the buffer's filetype.
---@param name string
---@param bufnr integer
---@param absolute string?
---@return table result
local function run_check(name, bufnr, absolute)
    if not state.trusted then
        return { status = 'error', error = 'editor_check requires a trusted workspace' }
    end
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].modified then
        return { status = 'error', error = 'editor_check requires saved buffers' }
    end
    local check = state.checks[name]
    if type(check) ~= 'table' or type(check.cmd) ~= 'table' or #check.cmd == 0 then
        return { status = 'error', error = 'unknown check: ' .. name }
    end
    local argv = vim.deepcopy(check.cmd)
    if absolute then
        for index, arg in ipairs(argv) do
            if arg == '{file}' then
                argv[index] = absolute
            end
        end
    end
    local ok, result = pcall(vim.system, argv, {
        text = true,
        cwd = state.root,
        timeout = check.timeout or 120000,
    })
    if not ok then
        return { status = 'error', error = 'could not start check: ' .. tostring(result) }
    end
    local completed = result:wait()
    local function bounded(text)
        if text and #text > CHECK_OUTPUT_MAX then
            return text:sub(1, CHECK_OUTPUT_MAX) .. '\n[truncated]'
        end
        return text or ''
    end
    return {
        status = completed.code == 0 and 'ok' or 'failed',
        code = completed.code,
        stdout = bounded(completed.stdout),
        stderr = bounded(completed.stderr),
    }
end

---@param args table
---@return table result
local function editor_check(args)
    local bufnr, absolute = target_buffer(args.path)
    if type(bufnr) ~= 'number' then
        return { status = 'error', error = tostring(absolute) }
    end
    if args.name ~= nil then
        local result = run_check(args.name, bufnr, absolute)
        result.name = args.name
        return result
    end
    local filetype = vim.bo[bufnr].filetype
    local results = {}
    for name, check in pairs(state.checks) do
        local relevant = check.filetypes == nil
        for _, ft in ipairs(check.filetypes or {}) do
            if ft == filetype then
                relevant = true
                break
            end
        end
        if relevant then
            local result = run_check(name, bufnr, absolute)
            result.name = name
            results[#results + 1] = result
        end
    end
    return { status = 'ok', checks = results }
end

---@param args table
---@return table result
local function editor_scip(args)
    local index = vim.fs.joinpath(state.root or '', 'index.scip.json')
    local present = uv.fs_stat(index) ~= nil
    if args.action == 'status' or args.action == nil then
        return { status = 'ok', index_present = present, index = present and index or nil }
    end
    return { status = 'unavailable', error = 'SCIP symbol queries need a decoded index reader' }
end

---@param args table
---@return table result
local function editor_debug(args)
    -- Read-only status; debug launch stays manual and is never model-triggered.
    if args.action ~= nil and args.action ~= 'status' then
        return { status = 'error', error = "editor_debug supports action 'status' only" }
    end
    return { status = 'ok', launch = 'manual', probes = {} }
end

local path_schema = {
    type = 'string',
    description = 'Workspace-relative path. Omit to target the current buffer.',
}
local timeout_schema = {
    type = 'integer',
    minimum = 1,
    maximum = 120000,
    description = 'Total completion deadline in milliseconds.',
}

local specs = {
    {
        'editor_context',
        'Snapshot the target buffer, attached LSP clients and configured checks.',
        editor_context,
        { path = path_schema },
    },
    {
        'editor_diagnostics',
        'Read the native diagnostic snapshot for the target buffer.',
        editor_diagnostics,
        { path = path_schema },
    },
    {
        'editor_symbols',
        'Request document symbols from attached LSP clients with a bounded deadline.',
        editor_symbols,
        { path = path_schema, timeout = timeout_schema },
    },
    {
        'editor_references',
        'Request references from attached LSP clients.',
        editor_references,
        {
            path = path_schema,
            timeout = timeout_schema,
            line = { type = 'integer', minimum = 1, description = '1-based line.' },
            column = { type = 'integer', minimum = 0, description = '0-based byte column.' },
            include_declaration = { type = 'boolean' },
        },
    },
    {
        'editor_lint',
        'Run the native syntax lint for the target buffer.',
        editor_lint,
        { path = path_schema, timeout = timeout_schema },
    },
    {
        'editor_check',
        'Run an explicitly configured named argv check, or all relevant checks when name is '
            .. 'omitted. Requires trust.',
        editor_check,
        {
            path = path_schema,
            name = { type = 'string', description = 'Configured check name; no argv accepted.' },
        },
    },
    {
        'editor_scip',
        'Report SCIP index presence. Symbol queries are not implemented.',
        editor_scip,
        {
            path = path_schema,
            action = { type = 'string', enum = { 'status' } },
        },
    },
    {
        'editor_debug',
        'Report debug status. Launch is manual; model tools permit status only.',
        editor_debug,
        { path = path_schema, action = { type = 'string', enum = { 'status' } } },
    },
    {
        'file_read',
        'Read a workspace text file, preferring the live buffer including unsaved changes.',
        file_read,
        { path = path_schema },
        { 'path' },
    },
    {
        'file_write',
        'Atomically write a workspace text file; refuses unsaved or read-only buffers. '
            .. 'Requires trust; parents must exist.',
        file_write,
        {
            path = path_schema,
            content = { type = 'string' },
            expected_sha256 = { type = 'string' },
            expected_changedtick = { type = 'integer', minimum = 0 },
        },
        { 'path', 'content' },
    },
    {
        'file_list',
        'List one workspace directory without following symlinks; no recursive traversal.',
        file_list,
        { path = path_schema, limit = { type = 'integer', minimum = 1, maximum = 1000 } },
    },
}

local by_name = {}
for _, spec in ipairs(specs) do
    by_name[spec[1]] = spec
end

-- Export the tool schemas in the model-tool format the agent expects.
---@return table[] schemas
function M.schemas()
    local result = {}
    for _, spec in ipairs(specs) do
        result[#result + 1] = {
            type = 'function',
            ['function'] = {
                name = spec[1],
                description = spec[2],
                parameters = {
                    type = 'object',
                    properties = vim.deepcopy(spec[4]),
                    required = spec[5] or {},
                    additionalProperties = false,
                },
            },
        }
    end
    return result
end

---@param args table
---@param spec table
local function validate_args(args, spec)
    assert(type(args) == 'table', 'tool arguments must be an object')
    for key, value in pairs(args) do
        local schema = spec[4][key]
        assert(schema, 'unknown argument: ' .. tostring(key))
        local expected = schema.type == 'integer' and 'number' or schema.type
        assert(type(value) == expected, 'invalid type for ' .. key)
        if schema.type == 'integer' then
            assert(
                value == math.floor(value)
                    and value >= (schema.minimum or -math.huge)
                    and value <= (schema.maximum or math.huge),
                'invalid range for ' .. key
            )
        end
        if schema.enum then
            assert(vim.tbl_contains(schema.enum, value), 'invalid value for ' .. key)
        end
    end
    for _, key in ipairs(spec[5] or {}) do
        assert(args[key] ~= nil, 'missing required argument: ' .. key)
    end
end

-- Exclude handles, callbacks, metatables and cyclic state from tool results.
---@param value any
---@param seen table
---@param depth integer
---@return any
local function serializable(value, seen, depth)
    if value == vim.NIL then
        return vim.NIL
    end
    local kind = type(value)
    if kind == 'nil' or kind == 'boolean' or kind == 'string' then
        return value
    end
    if kind == 'number' then
        return (value == value and value ~= math.huge and value ~= -math.huge) and value or nil
    end
    if kind ~= 'table' or depth > 40 or seen[value] then
        return nil
    end
    seen[value] = true
    local result = vim.islist(value) and {} or vim.empty_dict()
    for key, item in pairs(value) do
        if type(key) == 'string' or type(key) == 'number' then
            result[key] = serializable(item, seen, depth + 1)
        end
    end
    seen[value] = nil
    return result
end

-- Call a tool by name; never raises, always returns a status table.
---@param name string
---@param args table?
---@return table result
function M.call(name, args)
    local ok, result = pcall(function()
        local spec = by_name[name]
        assert(spec, 'unknown tool: ' .. tostring(name))
        args = args or {}
        validate_args(args, spec)
        return serializable(spec[3](args), {}, 0)
    end)
    if not ok then
        return { status = 'error', error = tostring(result) }
    end
    if type(result) ~= 'table' then
        return { status = 'error', error = 'tool returned no result' }
    end
    return result
end

return M
