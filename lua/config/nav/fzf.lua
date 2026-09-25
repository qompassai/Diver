-- /qompassai/Diver/lua/config/nav/fzf.lua
-- Qompass AI Diver native FZF navigation; mappings belong to mappings.navmap.
-- Copyright (C) 2025-2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local lsp = vim.lsp
local uv = vim.uv
local M = {}

local ITEM_COUNT_MAX = 20000
local LABEL_SIZE_BYTES_MAX = 2048
local OUTPUT_SIZE_BYTES_MAX = 8 * 1024 * 1024
local ERROR_SIZE_BYTES_MAX = 65536
local PROCESS_TIMEOUT_MS = 10000
local LSP_TIMEOUT_MS = 5000
local SYMBOL_DEPTH_MAX = 32
local SYMBOL_COUNT_MAX = 40000
local CLIENT_COUNT_MAX = 32
local ROOT_MARKERS = {
    '.git',
    'Cargo.toml',
    'flake.nix',
    'go.mod',
    'package.json',
    'pyproject.toml',
}

---@class NativeFzfItem
---@field label string
---@field value any

---@class NativeFzfPickOptions
---@field prompt? string

---@class NativeFzfOptions
---@field binaries string[]
---@field projects_directory string
---@field prompt string
---@field picker 'native'|'fzf'

---@class NativeFzfSetupOptions
---@field binaries? string[]
---@field projects_directory? string
---@field prompt? string
---@field picker? 'native'|'fzf'

---@class NativeFzfSession
---@field origin_buffer integer
---@field origin_window integer
---@field cwd string
---@field process? vim.SystemObj
---@field job_id? integer
---@field terminal_buffer? integer
---@field terminal_window? integer
---@field directory? string
---@field input_path? string
---@field output_path? string
---@field timer? uv.uv_timer_t
---@field requests table[]
---@field closed boolean

---@type NativeFzfSession?
local active_session

---@type NativeFzfOptions
M.options = {
    binaries = { 'fzf', 'sk' },
    projects_directory = fn.expand('~/projects'),
    prompt = '❯ ',
    picker = 'native',
}

---@param message string
---@param level? integer
local function notify(message, level)
    local function emit()
        vim.notify(message, level or vim.log.levels.INFO, { title = 'Native FZF' })
    end
    if vim.in_fast_event() then
        vim.schedule(emit)
    else
        emit()
    end
end

---@param value any
---@return boolean
local function is_integer(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge and value % 1 == 0
end

---@param value any
---@return boolean
local function valid_string(value)
    return type(value) == 'string' and value ~= '' and not value:find('\0', 1, true)
end

---@param value number
---@return integer
local function integer_floor(value)
    assert(type(value) == 'number')
    assert(value == value and value ~= math.huge and value ~= -math.huge)
    local result = math.floor(value)
    ---@cast result integer
    return result
end

---@param command string
---@return string?
local function executable_path(command)
    local path = fn.exepath(command)
    if path == '' then
        return nil
    end
    return path
end

---@return string?
local function picker_binary()
    local configured = vim.env.NVIM_FZF_BIN
    if valid_string(configured) then
        local path = executable_path(configured)
        if path == nil then
            notify('NVIM_FZF_BIN is not executable: ' .. configured, vim.log.levels.ERROR)
        end
        return path
    end
    for index = 1, math.min(#M.options.binaries, 8) do
        local path = executable_path(M.options.binaries[index])
        if path ~= nil then
            return path
        end
    end
    notify('Install fzf or skim, or set NVIM_FZF_BIN.', vim.log.levels.ERROR)
end

---@param bufnr integer
---@return string
local function project_root(bufnr)
    local name = api.nvim_buf_get_name(bufnr)
    local start = fn.getcwd()
    if name ~= '' and vim.bo[bufnr].buftype == '' then
        start = fs.dirname(name) or start
    end
    return fs.root(start, ROOT_MARKERS) or fn.getcwd()
end

---@param session NativeFzfSession
---@return boolean
local function is_current(session)
    return active_session == session and not session.closed
end

---@param session NativeFzfSession
---@return boolean
local function origin_valid(session)
    return api.nvim_buf_is_valid(session.origin_buffer)
        and api.nvim_win_is_valid(session.origin_window)
        and api.nvim_win_get_buf(session.origin_window) == session.origin_buffer
end

---@param operation string
---@param callback function
---@param ... any
local function cleanup_call(operation, callback, ...)
    local ok, result, err = pcall(callback, ...)
    if not ok or result == nil and err ~= nil then
        notify(operation .. ': ' .. tostring(err or result), vim.log.levels.WARN)
    end
end

---@param path string?
local function unlink(path)
    if path == nil then
        return
    end
    local ok, err, code = uv.fs_unlink(path)
    if not ok and code ~= 'ENOENT' then
        notify('Remove picker file: ' .. tostring(err), vim.log.levels.WARN)
    end
end

---@param session NativeFzfSession
local function cancel_requests(session)
    for index = 1, #session.requests do
        local request = session.requests[index]
        cleanup_call('Cancel LSP request', request.client.cancel_request, request.client, request.id)
    end
    session.requests = {}
end

---@param session NativeFzfSession
local function close_session(session)
    if session.closed then
        return
    end
    session.closed = true
    if active_session == session then
        active_session = nil
    end
    if session.timer ~= nil and not session.timer:is_closing() then
        session.timer:stop()
        session.timer:close()
    end
    cancel_requests(session)
    if session.process ~= nil then
        cleanup_call('Stop process', session.process.kill, session.process, 9)
        session.process = nil
    end
    if session.job_id ~= nil then
        cleanup_call('Stop picker', fn.jobstop, session.job_id)
        session.job_id = nil
    end
    if session.terminal_window and api.nvim_win_is_valid(session.terminal_window) then
        cleanup_call('Close picker window', api.nvim_win_close, session.terminal_window, true)
    end
    if session.terminal_buffer and api.nvim_buf_is_valid(session.terminal_buffer) then
        cleanup_call('Delete picker buffer', api.nvim_buf_delete, session.terminal_buffer, {
            force = true,
        })
    end
    unlink(session.input_path)
    unlink(session.output_path)
    if session.directory ~= nil then
        cleanup_call('Remove picker directory', uv.fs_rmdir, session.directory)
    end
end

function M.cancel()
    if active_session ~= nil then
        close_session(active_session)
    end
end

---@return NativeFzfSession
local function begin_session()
    M.cancel()
    local bufnr = api.nvim_get_current_buf()
    local session = {
        origin_buffer = bufnr,
        origin_window = api.nvim_get_current_win(),
        cwd = project_root(bufnr),
        requests = {},
        closed = false,
    }
    active_session = session
    return session
end

---@param session NativeFzfSession
---@param message string
local function fail(session, message)
    if is_current(session) then
        close_session(session)
        notify(message, vim.log.levels.ERROR)
    end
end

---@param value string
---@return string
local function clean_label(value)
    -- Strip control bytes before sending filenames or server text to a terminal UI.
    local label = value:sub(1, LABEL_SIZE_BYTES_MAX):gsub('[%z\1-\31\127]', ' ')
    return label
end

---@param items NativeFzfItem[]
---@param label string
---@param value any
---@return boolean
local function append_item(items, label, value)
    if #items >= ITEM_COUNT_MAX then
        return false
    end
    items[#items + 1] = { label = clean_label(label), value = value }
    return true
end

---@param path string
---@param payload string
---@return boolean?, string?
local function write_private(path, payload)
    local descriptor, open_error = uv.fs_open(path, 'wx', 384)
    if descriptor == nil then
        return nil, tostring(open_error)
    end
    local written, write_error = uv.fs_write(descriptor, payload, 0)
    local closed, close_error = uv.fs_close(descriptor)
    if written ~= #payload then
        return nil, 'Incomplete picker write: ' .. tostring(write_error)
    end
    if not closed then
        return nil, tostring(close_error)
    end
    return true
end

---@param session NativeFzfSession
---@param items NativeFzfItem[]
---@return boolean?, string?
local function prepare_files(session, items)
    local directory, directory_error = uv.fs_mkdtemp(fn.tempname() .. '-XXXXXX')
    if directory == nil then
        return nil, tostring(directory_error)
    end
    session.directory = directory
    session.input_path = directory .. '/input'
    session.output_path = directory .. '/output'
    local lines = {}
    local size_bytes = 0
    for index = 1, #items do
        local line = ('%08d\t%s\n'):format(index, clean_label(items[index].label))
        size_bytes = size_bytes + #line
        if size_bytes > OUTPUT_SIZE_BYTES_MAX then
            return nil, 'Picker input exceeds 8 MiB; narrow the source.'
        end
        lines[index] = line
    end
    local ok, err = write_private(session.input_path, table.concat(lines))
    if not ok then
        return nil, err
    end
    return write_private(session.output_path, '')
end

---@param path string
---@return integer?, string?
local function selected_index(path)
    local descriptor, open_error = uv.fs_open(path, 'r', 0)
    if descriptor == nil then
        return nil, tostring(open_error)
    end
    local data, read_error = uv.fs_read(descriptor, LABEL_SIZE_BYTES_MAX + 64, 0)
    local closed, close_error = uv.fs_close(descriptor)
    if not closed then
        return nil, tostring(close_error)
    end
    if data == nil then
        return nil, tostring(read_error)
    end
    local number = tonumber(data:match('^(%d+)\t'))
    if not is_integer(number) or number < 1 or number > ITEM_COUNT_MAX then
        return nil, 'Picker returned an invalid selection.'
    end
    ---@cast number integer
    return number
end

---@param session NativeFzfSession
---@param items NativeFzfItem[]
---@param sink fun(value: any, item: NativeFzfItem)
---@param code integer
local function picker_exit(session, items, sink, code)
    session.job_id = nil
    if not is_current(session) then
        close_session(session)
        return
    end
    local index, err
    if code == 0 and session.output_path ~= nil then
        index, err = selected_index(session.output_path)
    end
    local valid = origin_valid(session)
    close_session(session)
    if code == 1 or code == 130 then
        return -- No match or user cancellation is not an error.
    end
    if code ~= 0 or index == nil or items[index] == nil then
        notify(err or ('Picker exited with code %d.'):format(code), vim.log.levels.ERROR)
        return
    end
    if not valid then
        notify('Original buffer/window changed; selection discarded.', vim.log.levels.WARN)
        return
    end
    api.nvim_set_current_win(session.origin_window)
    local item = items[index]
    local ok, sink_error = pcall(sink, item.value, item)
    if not ok then
        notify('Selection failed: ' .. tostring(sink_error), vim.log.levels.ERROR)
    end
end

---@param session NativeFzfSession
local function open_picker_window(session)
    local width = integer_floor(math.max(1, math.min(vim.o.columns - 4, 120)))
    local height = integer_floor(math.max(1, math.min(vim.o.lines - 4, 24)))
    session.terminal_buffer = api.nvim_create_buf(false, true)
    session.terminal_window = api.nvim_open_win(session.terminal_buffer, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.max(0, integer_floor((vim.o.lines - height) / 2)),
        col = math.max(0, integer_floor((vim.o.columns - width) / 2)),
        style = 'minimal',
        border = 'rounded',
    })
    vim.bo[session.terminal_buffer].bufhidden = 'wipe'
    api.nvim_create_autocmd('BufWipeout', {
        buffer = session.terminal_buffer,
        once = true,
        callback = function()
            vim.schedule(function()
                if is_current(session) then
                    M.cancel()
                end
            end)
        end,
    })
end

---@param session NativeFzfSession
---@param items NativeFzfItem[]
---@param sink fun(value: any, item: NativeFzfItem)
---@param prompt string
local function launch_picker(session, items, sink, prompt)
    local picker = picker_binary()
    local shell = executable_path('sh')
    if picker == nil or shell == nil then
        fail(session, 'An executable picker and POSIX sh are required.')
        return
    end
    local prepared, err = prepare_files(session, items)
    if not prepared then
        fail(session, 'Prepare picker: ' .. tostring(err))
        return
    end
    open_picker_window(session)
    -- A fixed script is needed only for PTY input/output redirection. Values are argv, never code.
    local script = 'exec "$1" --layout=reverse --cycle --no-multi '
        .. '--delimiter "$2" --with-nth "2.." --prompt "$3" < "$4" > "$5"'
    local job = fn.jobstart({
        shell,
        '-c',
        script,
        'native-fzf',
        picker,
        '\t',
        clean_label(prompt),
        session.input_path,
        session.output_path,
    }, {
        term = true,
        cwd = session.cwd,
        env = {
            ENV = '',
            BASH_ENV = '',
            FZF_DEFAULT_OPTS = '',
            FZF_DEFAULT_OPTS_FILE = '',
            FZF_DEFAULT_COMMAND = '',
            SKIM_DEFAULT_OPTIONS = '',
            SKIM_DEFAULT_COMMAND = '',
        },
        on_exit = function(_, code)
            vim.schedule(function()
                picker_exit(session, items, sink, code)
            end)
        end,
    })
    if job <= 0 then
        fail(session, 'Unable to start the picker terminal.')
        return
    end
    session.job_id = job
    vim.cmd.startinsert()
end

-- Native UI remains usable without an external picker or a POSIX shell.
local function native_picker(session, items, sink, prompt)
    local function select(candidates)
        if not is_current(session) or not origin_valid(session) then
            return
        end
        vim.ui.select(candidates, {
            prompt = prompt,
            format_item = function(item)
                return clean_label(item.label)
            end,
        }, function(item)
            local valid = is_current(session) and origin_valid(session)
            close_session(session)
            if item and valid then
                api.nvim_set_current_win(session.origin_window)
                local ok, err = pcall(sink, item.value, item)
                if not ok then
                    notify('Selection: ' .. tostring(err), vim.log.levels.ERROR)
                end
            end
        end)
    end
    if #items <= 200 then
        select(items)
        return
    end
    vim.ui.input({ prompt = prompt .. 'Fuzzy filter (top 200): ' }, function(query)
        if not is_current(session) then
            return
        end
        if not query then
            close_session(session)
            return
        end
        if #query > 4096 then
            fail(session, 'Filter exceeds 4096 bytes')
            return
        end
        if query == '' then
            select(vim.list_slice(items, 1, 200))
        else
            select(fn.matchfuzzy(items, query, { key = 'label', limit = 200 }))
        end
    end)
end

---@param session NativeFzfSession
---@param items NativeFzfItem[]
---@param sink fun(value: any, item: NativeFzfItem)
---@param prompt string
local function present(session, items, sink, prompt)
    if not is_current(session) then
        return
    end
    if not origin_valid(session) then
        fail(session, 'Original buffer/window changed while collecting entries.')
        return
    end
    if #items == 0 then
        close_session(session)
        notify('No entries.')
        return
    end
    assert(#items <= ITEM_COUNT_MAX)
    local picker = M.options.picker == 'fzf' and launch_picker or native_picker
    local ok, err = pcall(picker, session, items, sink, prompt)
    if not ok then
        fail(session, 'Open picker: ' .. tostring(err))
    end
end

---@param items any[]
---@param sink fun(value: any, item: NativeFzfItem)
---@param options? NativeFzfPickOptions
function M.fzf_pick(items, sink, options)
    assert(type(items) == 'table')
    assert(type(sink) == 'function')
    if #items > ITEM_COUNT_MAX then
        notify('Too many entries; limit is 20000.', vim.log.levels.ERROR)
        return
    end
    local normalized = {}
    for index = 1, #items do
        local value = items[index]
        if type(value) == 'table' and type(value.label) == 'string' then
            append_item(normalized, value.label, value.value)
        else
            append_item(normalized, tostring(value), value)
        end
    end
    local prompt = M.options.prompt
    if options then
        local option_prompt = options.prompt
        if valid_string(option_prompt) and type(option_prompt) == 'string' then
            prompt = option_prompt
        end
    end
    present(begin_session(), normalized, sink, prompt)
end

---@param session NativeFzfSession
---@param command string[]
---@param cwd string
---@param callback fun(output: string, code: integer)
---@param allow_no_match? boolean
local function run(session, command, cwd, callback, allow_no_match)
    assert(#command > 0)
    if not is_current(session) then
        return
    end
    local stdout, stderr = {}, {}
    local size_bytes, error_size_bytes = 0, 0
    local failure
    local function capture(is_error, err, data)
        if err ~= nil then
            failure = tostring(err)
        end
        if data ~= nil and failure == nil then
            if is_error then
                error_size_bytes = error_size_bytes + #data
                if error_size_bytes <= ERROR_SIZE_BYTES_MAX then
                    stderr[#stderr + 1] = data
                else
                    failure = 'Process stderr exceeds 64 KiB.'
                end
            else
                size_bytes = size_bytes + #data
                if size_bytes <= OUTPUT_SIZE_BYTES_MAX then
                    stdout[#stdout + 1] = data
                else
                    failure = 'Process output exceeds 8 MiB; narrow the search.'
                end
            end
        end
        if failure ~= nil and session.process ~= nil then
            cleanup_call('Stop oversized process', session.process.kill, session.process, 9)
        end
    end
    local ok, process = pcall(vim.system, command, {
        cwd = cwd,
        timeout = PROCESS_TIMEOUT_MS,
        stdout = function(err, data)
            capture(false, err, data)
        end,
        stderr = function(err, data)
            capture(true, err, data)
        end,
    }, function(result)
        vim.schedule(function()
            session.process = nil
            if not is_current(session) then
                return
            end
            if failure or result.signal ~= 0 or result.code ~= 0 and not (allow_no_match and result.code == 1) then
                fail(
                    session,
                    failure or ('%s failed (%d): %s'):format(command[1], result.code, clean_label(table.concat(stderr)))
                )
                return
            end
            local called, callback_error = pcall(callback, table.concat(stdout), result.code)
            if not called then
                fail(session, 'Read process result: ' .. tostring(callback_error))
            end
        end)
    end)
    if not ok then
        fail(session, 'Start process: ' .. tostring(process))
        return
    end
    session.process = process
end

---@param output string
---@param delimiter string
---@return string[]?, string?
local function records(output, delimiter)
    local result = {}
    local position = 1
    for _ = 1, ITEM_COUNT_MAX + 1 do
        if position > #output then
            return result
        end
        local ending = output:find(delimiter, position, true)
        if ending == nil then
            return nil, 'Incomplete machine-readable output.'
        end
        if #result >= ITEM_COUNT_MAX then
            return nil, 'More than 20000 records; narrow the source.'
        end
        result[#result + 1] = output:sub(position, ending - 1)
        position = ending + #delimiter
    end
    return nil, 'Record limit exceeded.'
end

---@param path string
local function edit(path)
    if not valid_string(path) then
        error('Invalid file path.')
    end
    -- Structured Ex arguments prevent filenames containing bars/newlines becoming commands.
    api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }, {})
end

---@param path string
---@param line integer
---@param column integer Zero-based byte column.
local function open_byte_location(path, line, column)
    edit(path)
    local last_line = api.nvim_buf_line_count(0)
    line = integer_floor(math.max(1, math.min(line, last_line)))
    local text = api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ''
    api.nvim_win_set_cursor(0, { line, integer_floor(math.max(0, math.min(column, #text))) })
end

---@param session NativeFzfSession
---@param output string
---@param root string
---@param prompt string
local function present_paths(session, output, root, prompt)
    local paths, err = records(output, '\0')
    if paths == nil then
        fail(session, tostring(err))
        return
    end
    local items = {}
    table.sort(paths)
    for index = 1, #paths do
        local relative = paths[index]:gsub('^%./', '')
        append_item(items, relative, fs.joinpath(root, relative))
    end
    present(session, items, edit, prompt)
end

function M.files()
    local session = begin_session()
    local fd = executable_path('fd')
    local rg = executable_path('rg')
    local find = executable_path('find')
    ---@type string[]
    local command
    if fd ~= nil then
        command = {
            fd,
            '-0',
            '--type',
            'f',
            '--type',
            'l',
            '--hidden',
            '--exclude',
            '.git',
            '.',
            '.',
        }
    elseif rg ~= nil then
        command = { rg, '--no-config', '--files', '-0', '--hidden', '--glob', '!.git' }
    elseif find ~= nil then
        command = { find, '.', '-name', '.git', '-prune', '-o', '-type', 'f', '-print0' }
    else
        fail(session, 'File discovery requires fd, ripgrep, or find.')
        return
    end
    run(session, command, session.cwd, function(output)
        present_paths(session, output, session.cwd, 'Files❯ ')
    end, true)
end

function M.buffers()
    local buffers = api.nvim_list_bufs()
    if #buffers > ITEM_COUNT_MAX then
        notify('Buffer inventory exceeds 20000.', vim.log.levels.ERROR)
        return
    end
    local items = {}
    table.sort(buffers)
    for index = 1, #buffers do
        local bufnr = buffers[index]
        if api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
            local name = api.nvim_buf_get_name(bufnr)
            append_item(items, ('%d  %s'):format(bufnr, name ~= '' and name or '[No Name]'), bufnr)
        end
    end
    M.fzf_pick(items, function(bufnr)
        if api.nvim_buf_is_valid(bufnr) then
            api.nvim_set_current_buf(bufnr)
        else
            notify('Selected buffer no longer exists.', vim.log.levels.WARN)
        end
    end, { prompt = 'Buffers❯ ' })
end

---@param symbol table
---@param default_uri string
---@return table?
local function symbol_location(symbol, default_uri)
    local location = symbol.location
    local uri = default_uri
    local range = symbol.selectionRange or symbol.range
    if type(location) == 'table' then
        uri = location.uri
        range = location.range
    end
    if not valid_string(uri) or type(range) ~= 'table' then
        return nil
    end
    for _, position in ipairs({ range.start, range['end'] }) do
        if
            type(position) ~= 'table'
            or not is_integer(position.line)
            or not is_integer(position.character)
            or position.line < 0
            or position.character < 0
        then
            return nil
        end
    end
    if range.start == nil or range['end'] == nil then
        return nil
    end
    return { uri = uri, range = range }
end

---@param symbols table[]
---@param uri string
---@param encoding string
---@param items NativeFzfItem[]
---@param budget table
local function collect_symbols(symbols, uri, encoding, items, budget)
    local stack = { { symbols = symbols, index = 1, depth = 0 } }
    for _ = 1, SYMBOL_COUNT_MAX * 2 + 1 do
        local frame = stack[#stack]
        if frame == nil then
            return
        end
        if frame.index > #frame.symbols then
            stack[#stack] = nil
        else
            local symbol = frame.symbols[frame.index]
            frame.index = frame.index + 1
            budget.visited = budget.visited + 1
            if budget.visited > SYMBOL_COUNT_MAX or #items >= ITEM_COUNT_MAX then
                budget.truncated = true
                return
            end
            if type(symbol) == 'table' then
                local location = symbol_location(symbol, uri)
                if location ~= nil then
                    local name = type(symbol.name) == 'string' and symbol.name or '<unnamed>'
                    local label = ('%s%s  line %d'):format(
                        string.rep('  ', frame.depth),
                        clean_label(name),
                        location.range.start.line + 1
                    )
                    append_item(items, label, { location = location, encoding = encoding })
                end
                if type(symbol.children) == 'table' and #symbol.children > 0 then
                    if frame.depth < SYMBOL_DEPTH_MAX then
                        stack[#stack + 1] = {
                            symbols = symbol.children,
                            index = 1,
                            depth = frame.depth + 1,
                        }
                    else
                        budget.truncated = true
                    end
                end
            end
        end
    end
    budget.truncated = true
end

---@param session NativeFzfSession
---@param clients vim.lsp.Client[]
---@param responses table
---@param prompt string
local function present_symbols(session, clients, responses, prompt)
    if not is_current(session) then
        return
    end
    if session.timer ~= nil and not session.timer:is_closing() then
        session.timer:stop()
        session.timer:close()
    end
    cancel_requests(session)
    local uri = vim.uri_from_bufnr(session.origin_buffer)
    local items = {}
    local budget = { visited = 0, truncated = false }
    for index = 1, #clients do
        local client = clients[index]
        local response = responses[client.id]
        if response ~= nil and response.error ~= nil then
            notify(client.name .. ': ' .. clean_label(tostring(response.error.message)), vim.log.levels.WARN)
        elseif response ~= nil and type(response.result) == 'table' then
            collect_symbols(response.result, uri, client.offset_encoding, items, budget)
        end
        if budget.truncated then
            break
        end
    end
    if budget.truncated then
        notify('Symbol results reached the item/node/depth limit.', vim.log.levels.WARN)
    end
    present(session, items, function(target)
        -- Server offsets may be UTF-16; never use them directly as byte columns.
        if not lsp.util.show_document(target.location, target.encoding, { focus = true }) then
            notify('Unable to open symbol location.', vim.log.levels.WARN)
        end
    end, prompt)
end

---@param method string
---@param params table
---@param prompt string
local function request_symbols(method, params, prompt)
    local session = begin_session()
    local clients = lsp.get_clients({ bufnr = session.origin_buffer, method = method })
    if #clients == 0 or #clients > CLIENT_COUNT_MAX then
        fail(session, 'Expected 1–32 attached LSP clients supporting ' .. method .. '.')
        return
    end
    table.sort(clients, function(left, right)
        return left.id < right.id
    end)
    local responses = {}
    local remaining = #clients
    local finished = false
    local function finish()
        if finished or not is_current(session) then
            return
        end
        finished = true
        if not origin_valid(session) then
            fail(session, 'Symbol request origin is no longer available.')
            return
        end
        local ok, err = pcall(present_symbols, session, clients, responses, prompt)
        if not ok then
            fail(session, 'Collect symbols: ' .. tostring(err))
        end
    end
    for index = 1, #clients do
        local client = clients[index]
        local ok, sent, request_id = pcall(client.request, client, method, params, function(err, result)
            if finished or not is_current(session) then
                return
            end
            responses[client.id] = { error = err, result = result }
            remaining = remaining - 1
            if remaining == 0 then
                finish()
            end
        end, session.origin_buffer)
        if ok and sent and request_id ~= nil then
            session.requests[#session.requests + 1] = { client = client, id = request_id }
        else
            remaining = remaining - 1
            notify('Request failed for ' .. client.name .. ': ' .. tostring(sent), vim.log.levels.WARN)
        end
    end
    if remaining == 0 then
        finish()
    elseif not finished then
        session.timer = vim.defer_fn(function()
            if is_current(session) then
                notify('LSP deadline reached; showing available symbols.', vim.log.levels.WARN)
                finish()
            end
        end, LSP_TIMEOUT_MS)
    end
end

function M.document_symbols()
    request_symbols('textDocument/documentSymbol', {
        textDocument = { uri = vim.uri_from_bufnr(0) },
    }, 'Document symbols❯ ')
end

function M.workspace_symbols()
    local query = fn.input('Workspace symbol query: ')
    if valid_string(query) then
        request_symbols('workspace/symbol', { query = query }, 'Workspace symbols❯ ')
    end
end

---@param completion string
---@param prompt string
---@param sink fun(value: any, item: NativeFzfItem)
local function completion_picker(completion, prompt, sink)
    local values = fn.getcompletion('', completion)
    table.sort(values)
    M.fzf_pick(values, sink, { prompt = prompt })
end

function M.commands()
    -- nvim_get_commands({ builtin = true }) is not implemented by the API.
    completion_picker('command', 'Commands❯ ', function(command)
        if command:match('^[A-Za-z][A-Za-z0-9]*$') == nil then
            error('Invalid command name.')
        end
        api.nvim_feedkeys(':' .. command .. ' ', 'n', false)
    end)
end

function M.help_tags()
    completion_picker('help', 'Help❯ ', function(tag)
        api.nvim_cmd({ cmd = 'help', args = { tag } }, {})
    end)
end

function M.colorschemes()
    completion_picker('color', 'Colorschemes❯ ', function(name)
        api.nvim_cmd({ cmd = 'colorscheme', args = { name } }, {})
    end)
end

---@param entries table[]
---@param origin_buffer integer
---@param items NativeFzfItem[]
local function collect_marks(entries, origin_buffer, items)
    for index = 1, math.min(#entries, ITEM_COUNT_MAX) do
        local entry = entries[index]
        local position = entry.pos
        if
            type(entry.mark) == 'string'
            and type(position) == 'table'
            and is_integer(position[2])
            and position[2] > 0
            and is_integer(position[3])
            and position[3] > 0
        then
            local bufnr = position[1]
            local path = entry.file
            if is_integer(bufnr) and bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
                path = api.nvim_buf_get_name(bufnr)
            elseif not valid_string(path) then
                bufnr = origin_buffer
                path = api.nvim_buf_get_name(bufnr)
            end
            append_item(items, ('%s  %s:%d'):format(entry.mark, path or '[No Name]', position[2]), {
                bufnr = bufnr,
                path = path,
                line = position[2],
                column = position[3] - 1,
            })
        end
    end
end

function M.marks()
    local items = {}
    local bufnr = api.nvim_get_current_buf()
    collect_marks(fn.getmarklist(), bufnr, items)
    collect_marks(fn.getmarklist(bufnr), bufnr, items)
    table.sort(items, function(left, right)
        return left.label < right.label
    end)
    M.fzf_pick(items, function(mark)
        if is_integer(mark.bufnr) and mark.bufnr > 0 and api.nvim_buf_is_valid(mark.bufnr) then
            fn.bufload(mark.bufnr)
            api.nvim_set_current_buf(mark.bufnr)
        elseif valid_string(mark.path) then
            edit(mark.path)
        else
            error('Marked buffer/file is unavailable.')
        end
        local line = integer_floor(math.min(mark.line, api.nvim_buf_line_count(0)))
        local text = api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ''
        api.nvim_win_set_cursor(0, { line, integer_floor(math.min(mark.column, #text)) })
    end, { prompt = 'Marks❯ ' })
end

---@param encoded table
---@return string?
local function rg_text(encoded)
    if type(encoded) ~= 'table' then
        return nil
    end
    if type(encoded.text) == 'string' then
        return encoded.text
    end
    -- Arbitrary filename bytes are represented as base64 by ripgrep JSON.
    if type(encoded.bytes) == 'string' then
        local ok, decoded = pcall(vim.base64.decode, encoded.bytes)
        if ok then
            return decoded
        end
    end
    return nil
end

---@param session NativeFzfSession
---@param output string
local function present_grep(session, output)
    local items = {}
    local position = 1
    for _ = 1, SYMBOL_COUNT_MAX do
        if position > #output then
            present(session, items, function(target)
                open_byte_location(target.path, target.line, target.column)
            end, 'Grep❯ ')
            return
        end
        local ending = output:find('\n', position, true)
        if ending == nil then
            fail(session, 'Incomplete ripgrep JSON record.')
            return
        end
        local record = vim.json.decode(output:sub(position, ending - 1))
        position = ending + 1
        if record.type == 'match' then
            local data = record.data
            local path, text = rg_text(data.path), rg_text(data.lines)
            local match = type(data.submatches) == 'table' and data.submatches[1] or nil
            if
                not valid_string(path)
                or not is_integer(data.line_number)
                or data.line_number < 1
                or type(match) ~= 'table'
                or not is_integer(match.start)
                or match.start < 0
            then
                fail(session, 'Malformed ripgrep match.')
                return
            end
            local label = ('%s:%d:%d:%s'):format(path, data.line_number, match.start + 1, text or '')
            if
                not append_item(items, label, {
                    path = fs.joinpath(session.cwd, path),
                    line = data.line_number,
                    column = match.start,
                })
            then
                fail(session, 'More than 20000 grep matches; narrow the query.')
                return
            end
        end
    end
    fail(session, 'Ripgrep JSON record limit exceeded; narrow the query.')
end

---@param query? string
---@param fixed? boolean
function M.live_grep(query, fixed)
    -- Compatibility name: prompt once, collect rg results, then fuzzy-filter those results.
    if query == nil then
        query = fn.input('Grep pattern: ')
    end
    if not valid_string(query) then
        return
    end
    local session = begin_session()
    local rg = executable_path('rg')
    if rg == nil then
        fail(session, 'ripgrep is required for grep.')
        return
    end
    local command = { rg, '--json', '--no-config', '--smart-case', '--hidden', '--glob', '!.git' }
    if fixed then
        command[#command + 1] = '--fixed-strings'
        command[#command + 1] = '--word-regexp'
    end
    command[#command + 1] = '--'
    command[#command + 1] = query
    command[#command + 1] = '.'
    run(session, command, session.cwd, function(output)
        present_grep(session, output)
    end, true)
end

function M.grep_cword()
    local word = fn.expand('<cword>')
    if valid_string(word) then
        M.live_grep(word, true)
    end
end

---@param callback fun(session: NativeFzfSession, git: string, root: string)
local function with_git_root(callback)
    local session = begin_session()
    local git = executable_path('git')
    if git == nil then
        fail(session, 'git is required.')
        return
    end
    run(session, { git, 'rev-parse', '--show-toplevel' }, session.cwd, function(output)
        -- Strip exactly the protocol newline, not whitespace belonging to the path.
        local root = output:gsub('\n$', '')
        if not valid_string(root) then
            fail(session, 'Not a Git worktree.')
            return
        end
        callback(session, git, root)
    end)
end

---@param session NativeFzfSession
---@param output string
---@param root string
local function present_git_status(session, output, root)
    local entries, err = records(output, '\0')
    if entries == nil then
        fail(session, tostring(err))
        return
    end
    local items = {}
    local index = 1
    for _ = 1, #entries do
        if index > #entries then
            break
        end
        local entry = entries[index]
        if #entry < 4 or entry:sub(3, 3) ~= ' ' then
            fail(session, 'Malformed Git porcelain status.')
            return
        end
        local status, path = entry:sub(1, 2), entry:sub(4)
        -- In porcelain v1 -z, a rename is destination NUL source NUL, never "old -> new".
        if status:find('[RC]') then
            if entries[index + 1] == nil then
                fail(session, 'Missing Git rename/copy source.')
                return
            end
            index = index + 1
        end
        append_item(items, status .. ' ' .. path, fs.joinpath(root, path))
        index = index + 1
    end
    table.sort(items, function(left, right)
        return left.value < right.value
    end)
    present(session, items, edit, 'Git status❯ ')
end

function M.git_status()
    with_git_root(function(session, git, root)
        run(session, { git, 'status', '--porcelain=v1', '-z', '--untracked-files=all' }, root, function(output)
            present_git_status(session, output, root)
        end)
    end)
end

function M.git_branches()
    with_git_root(function(session, git, root)
        run(session, { git, 'branch', '--format=%(refname:short)' }, root, function(output)
            local branches, err = records(output, '\n')
            if branches == nil then
                fail(session, tostring(err))
                return
            end
            table.sort(branches)
            local items = {}
            for index = 1, #branches do
                append_item(items, branches[index], branches[index])
            end
            present(session, items, function(branch)
                local next_session = begin_session()
                run(next_session, { git, 'switch', '--', branch }, root, function()
                    close_session(next_session)
                    notify('Switched to ' .. branch)
                end)
            end, 'Git branches❯ ')
        end)
    end)
end

function M.projects()
    local directory = M.options.projects_directory
    local stat = uv.fs_stat(directory)
    if stat == nil or stat.type ~= 'directory' then
        notify('Projects directory does not exist: ' .. directory, vim.log.levels.WARN)
        return
    end
    local session = begin_session()
    local find = executable_path('find')
    if find == nil then
        fail(session, 'find is required for project discovery.')
        return
    end
    run(
        session,
        {
            find,
            '.',
            '-mindepth',
            '1',
            '-maxdepth',
            '2',
            '-name',
            '.git',
            '-prune',
            '-o',
            '-type',
            'd',
            '-print0',
        },
        directory,
        function(output)
            local paths, err = records(output, '\0')
            if paths == nil then
                fail(session, tostring(err))
                return
            end
            table.sort(paths)
            local items = {}
            for index = 1, #paths do
                append_item(items, paths[index], fs.joinpath(directory, paths[index]))
            end
            present(session, items, function(path)
                local current_stat = uv.fs_stat(path)
                if current_stat == nil or current_stat.type ~= 'directory' then
                    error('Selected directory no longer exists.')
                end
                api.nvim_set_current_dir(path)
                -- Capture the chosen cwd without deriving another root from the old buffer.
                local selected_session = begin_session()
                selected_session.cwd = path
                local finder = executable_path('find')
                if finder == nil then
                    fail(selected_session, 'find is required for project files.')
                    return
                end
                run(
                    selected_session,
                    { finder, '.', '-name', '.git', '-prune', '-o', '-type', 'f', '-print0' },
                    path,
                    function(files)
                        present_paths(selected_session, files, path, 'Project files❯ ')
                    end
                )
            end, 'Projects❯ ')
        end
    )
end

function M.smart_hlsearch()
    vim.o.hlsearch = fn.getreg('/') ~= ''
end

function M.highlight_word_under_cursor()
    local word = fn.expand('<cword>')
    if word == '' then
        return
    end
    fn.setreg('/', '\\V\\<' .. fn.escape(word, '\\') .. '\\>')
    M.smart_hlsearch()
end

---@param direction 'n'|'N'
local function search_match(direction)
    local count = math.max(1, vim.v.count1)
    local ok, err = pcall(function()
        vim.cmd('keepjumps normal! ' .. tostring(count) .. direction)
    end)
    if not ok then
        notify(tostring(err), vim.log.levels.WARN)
        return
    end
    M.smart_hlsearch()
end

function M.next_match()
    search_match('n')
end

function M.prev_match()
    search_match('N')
end

function M.toggle_search_highlight()
    if vim.v.hlsearch == 1 then
        vim.cmd.nohlsearch()
    else
        M.smart_hlsearch()
        vim.v.hlsearch = 1
    end
end

---@param command string Trusted Ex command supplied by configuration, never external input.
function M.substitute(command)
    assert(valid_string(command))
    local window = api.nvim_get_current_win()
    local buffer = api.nvim_get_current_buf()
    local cursor = api.nvim_win_get_cursor(window)
    local search = fn.getreg('/')
    local ok, err = pcall(function()
        vim.cmd('keepjumps ' .. command)
    end)
    fn.setreg('/', search)
    if api.nvim_win_is_valid(window) and api.nvim_win_get_buf(window) == buffer then
        local line = integer_floor(math.min(cursor[1], api.nvim_buf_line_count(buffer)))
        local text = api.nvim_buf_get_lines(buffer, line - 1, line, false)[1] or ''
        api.nvim_win_set_cursor(window, { line, integer_floor(math.min(cursor[2], #text)) })
    end
    M.smart_hlsearch()
    if not ok then
        notify('Substitute failed: ' .. tostring(err), vim.log.levels.ERROR)
    end
end

local owned_commands = {}
local function command(name, callback, opts)
    local existing = api.nvim_get_commands({ builtin = false })[name]
    if existing then
        if owned_commands[name] == existing.definition then
            return
        end
        notify('Preserving existing command :' .. name, vim.log.levels.WARN)
        return
    end
    opts.force = false
    api.nvim_create_user_command(name, callback, opts)
    owned_commands[name] = api.nvim_get_commands({ builtin = false })[name].definition
end

local function create_commands()
    ---@type { name: string, callback: fun() }[]
    local commands = {
        { name = 'NativeFzfBuffers', callback = M.buffers },
        { name = 'NativeFzfCancel', callback = M.cancel },
        { name = 'NativeFzfColorschemes', callback = M.colorschemes },
        { name = 'NativeFzfCommands', callback = M.commands },
        { name = 'NativeFzfDocumentSymbols', callback = M.document_symbols },
        { name = 'NativeFzfFiles', callback = M.files },
        { name = 'NativeFzfGitBranches', callback = M.git_branches },
        { name = 'NativeFzfGitStatus', callback = M.git_status },
        { name = 'NativeFzfHelp', callback = M.help_tags },
        { name = 'NativeFzfMarks', callback = M.marks },
        { name = 'NativeFzfProjects', callback = M.projects },
        { name = 'NativeFzfWorkspaceSymbols', callback = M.workspace_symbols },
        { name = 'Projects', callback = M.projects },
    }
    for index = 1, #commands do
        local name, callback = commands[index].name, commands[index].callback
        command(name, function()
            callback()
        end, {})
    end
    command('NativeFzfGrep', function(options)
        M.live_grep(options.args ~= '' and options.args or nil)
    end, { nargs = '*' })
end

---@param options? NativeFzfSetupOptions
---@return boolean?, string?
function M.setup(options)
    if options ~= nil and type(options) ~= 'table' then
        return nil, 'FZF options must be a table.'
    end
    local candidate = vim.tbl_deep_extend('force', vim.deepcopy(M.options), options or {})
    if
        type(candidate.binaries) ~= 'table'
        or #candidate.binaries < 1
        or #candidate.binaries > 8
        or not valid_string(candidate.projects_directory)
        or not valid_string(candidate.prompt)
        or (candidate.picker ~= 'native' and candidate.picker ~= 'fzf')
    then
        return nil, 'Invalid FZF binaries, projects_directory, or prompt.'
    end
    for index = 1, #candidate.binaries do
        if not valid_string(candidate.binaries[index]) then
            return nil, 'Each FZF executable must be a nonempty string.'
        end
    end
    candidate.projects_directory = fn.fnamemodify(fn.expand(candidate.projects_directory), ':p')
    M.cancel()
    M.options = candidate
    create_commands()
    local group = api.nvim_create_augroup('NativeFzfLifecycle', { clear = true })
    api.nvim_create_autocmd('VimLeavePre', { group = group, callback = M.cancel })
    vim.o.incsearch = true
    vim.o.hlsearch = true
    return true
end

M.fzf_setup = M.setup

return M
