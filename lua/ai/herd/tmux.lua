-- /qompassai/Diver/lua/ai/herd/tmux.lua
-- Herdr tmux driver (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- The ONLY herd module allowed to shell out to tmux. Every subprocess
-- call goes through vim.system with an argv array: untrusted values are
-- never interpolated into shell strings, and no other herd module may
-- invoke tmux directly.
--
-- Prompt text is delivered via a temp file on purpose. Passing arbitrary
-- text (shell metacharacters, newlines, quotes) as a command argument
-- forces the caller to quote and escape it, which is exactly where
-- injection bugs are born. Instead the text is written verbatim to a
-- temp file from vim.fn.tempname(), then moved into the pane with
-- tmux load-buffer + paste-buffer + send-keys Enter. The text never
-- appears in any argv, so there is nothing to quote or escape. The temp
-- file is deleted on every path, success or failure.
--
-- Every op carries a TMUX_TIMEOUT_MS timeout and returns (true) on
-- success or (nil, err) on failure.

local M = {}

local TMUX_TIMEOUT_MS = 10000
local CAPTURE_LINES_DEFAULT = 200
local CAPTURE_LINES_MAX = 2000
local TEXT_BYTES_MAX = 256 * 1024
local ERROR_MESSAGE_MAX = 500
local PROMPT_BUFFER_NAME = 'herd_prompt'
local SESSION_NAME_PATTERN = '^[A-Za-z0-9._-]+$'
local TARGET_PATTERN = '^[A-Za-z0-9._:-]+$'

---@param value string
---@return string
local function trim_message(value)
    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')
    if #trimmed > ERROR_MESSAGE_MAX then
        return trimmed:sub(1, ERROR_MESSAGE_MAX)
    end
    return trimmed
end

---@param value any
---@param pattern string
---@return boolean
local function matches_pattern(value, pattern)
    return type(value) == 'string' and value:match(pattern) ~= nil
end

-- Run one tmux argv through vim.system with the module timeout. Returns
-- the completed system object on success, or (nil, err) on spawn
-- failure, non-zero exit, or a termination signal.
--
-- run_tmux_async is the non-blocking twin: the wait happens in
-- libuv and cb fires on the main loop with (result, err). The
-- callback is wrapped in vim.schedule so callers can rely on main
-- loop context no matter how Neovim dispatches system callbacks.
---@param argv string[] argv array; first element must be 'tmux'
---@param op string operation label used in error messages
---@param cb fun(result: table?, err: string?)
local function run_tmux_async(argv, op, cb)
    assert(type(argv) == 'table', 'argv must be a table')
    assert(argv[1] == 'tmux', 'argv must start with tmux')
    assert(type(cb) == 'function', 'cb must be a function')
    local function finish(result, err)
        vim.schedule(function()
            cb(result, err)
        end)
    end
    local ok, sysobj = pcall(vim.system, argv, { text = true, timeout = TMUX_TIMEOUT_MS }, function(res)
        if res.code == 0 and res.signal == 0 then
            finish(res)
            return
        end
        local detail = ''
        if type(res.stderr) == 'string' then
            detail = trim_message(res.stderr)
        end
        if detail == '' and type(res.stdout) == 'string' then
            detail = trim_message(res.stdout)
        end
        finish(nil, 'tmux ' .. op .. ' failed: ' .. detail)
    end)
    if not ok then
        finish(nil, 'tmux ' .. op .. ' failed to start: ' .. tostring(sysobj))
    end
end

---@param argv string[] argv array; first element must be 'tmux'
---@param op string operation label used in error messages
---@return table? result completed vim.SystemObj on success
---@return string? err
local function run_tmux(argv, op)
    assert(type(argv) == 'table', 'argv must be a table')
    assert(argv[1] == 'tmux', 'argv must start with tmux')
    local ok, sysobj = pcall(vim.system, argv, { text = true })
    if not ok then
        return nil, 'tmux ' .. op .. ' failed to start: ' .. tostring(sysobj)
    end
    -- vim.system is async: the completed result only exists after wait().
    local wok, result = pcall(sysobj.wait, sysobj, TMUX_TIMEOUT_MS)
    if not wok then
        return nil, 'tmux ' .. op .. ' wait failed: ' .. tostring(result)
    end
    if result.code == 0 and result.signal == 0 then
        return result
    end
    local detail = ''
    if type(result.stderr) == 'string' then
        detail = trim_message(result.stderr)
    end
    if detail == '' and type(result.stdout) == 'string' then
        detail = trim_message(result.stdout)
    end
    return nil, 'tmux ' .. op .. ' failed: ' .. detail
end

---@param cmd_argv any
---@return boolean ok
---@return string? err
local function validate_cmd_argv(cmd_argv)
    if type(cmd_argv) ~= 'table' or #cmd_argv == 0 then
        return false, 'cmd_argv must be a non-empty array of strings'
    end
    for i, arg in ipairs(cmd_argv) do
        if type(arg) ~= 'string' or arg == '' then
            return false, 'cmd_argv[' .. i .. '] must be a non-empty string'
        end
    end
    return true
end

-- Write text verbatim to a fresh temp file. Returns the path, or
-- (nil, err) when the file cannot be created or written.
---@param text string
---@return string? path
---@return string? err
local function write_temp_text(text)
    local path = vim.fn.tempname()
    local handle, open_err = io.open(path, 'wb')
    if handle == nil then
        return nil, 'failed to write prompt temp file: ' .. tostring(open_err)
    end
    local write_ok, write_err = pcall(handle.write, handle, text)
    local close_ok = handle:close()
    if not write_ok or not close_ok then
        pcall(os.remove, path)
        return nil, 'failed to write prompt temp file: ' .. tostring(write_err)
    end
    return path
end

---@return boolean
function M.available()
    return vim.fn.executable('tmux') == 1
end

---@param name string session name; letters, digits, dot, dash, underscore
---@param cmd_argv string[] command argv to run inside the new session
---@param cwd string? working directory for the new session
---@return boolean|nil ok
---@return string? err
function M.new_session(name, cmd_argv, cwd)
    if not M.available() then
        return nil, 'tmux not available'
    end
    if not matches_pattern(name, SESSION_NAME_PATTERN) then
        return nil, 'name must match ' .. SESSION_NAME_PATTERN
    end
    local cmd_ok, cmd_err = validate_cmd_argv(cmd_argv)
    if not cmd_ok then
        return nil, cmd_err
    end
    if cwd ~= nil then
        if type(cwd) ~= 'string' or vim.fn.isdirectory(cwd) ~= 1 then
            return nil, 'cwd must be an existing directory'
        end
    end
    local argv = { 'tmux', 'new-session', '-d', '-s', name }
    if cwd ~= nil then
        argv[#argv + 1] = '-c'
        argv[#argv + 1] = cwd
    end
    for _, arg in ipairs(cmd_argv) do
        argv[#argv + 1] = arg
    end
    local _, run_err = run_tmux(argv, 'new-session')
    if run_err ~= nil then
        return nil, run_err
    end
    return true
end

---Non-blocking twin of new_session: the tmux spawn waits in libuv
---and cb fires on the main loop with (true) or (nil, err).
---@param name string
---@param cmd_argv string[]
---@param cwd string?
---@param cb fun(ok: boolean?, err: string?)
function M.new_session_async(name, cmd_argv, cwd, cb)
    assert(type(cb) == 'function', 'cb must be a function')
    if not M.available() then
        cb(nil, 'tmux not available')
        return
    end
    if not matches_pattern(name, SESSION_NAME_PATTERN) then
        cb(nil, 'name must match ' .. SESSION_NAME_PATTERN)
        return
    end
    local cmd_ok, cmd_err = validate_cmd_argv(cmd_argv)
    if not cmd_ok then
        cb(nil, cmd_err)
        return
    end
    if cwd ~= nil then
        if type(cwd) ~= 'string' or vim.fn.isdirectory(cwd) ~= 1 then
            cb(nil, 'cwd must be an existing directory')
            return
        end
    end
    local argv = { 'tmux', 'new-session', '-d', '-s', name }
    if cwd ~= nil then
        argv[#argv + 1] = '-c'
        argv[#argv + 1] = cwd
    end
    for _, arg in ipairs(cmd_argv) do
        argv[#argv + 1] = arg
    end
    run_tmux_async(argv, 'new-session', function(_, run_err)
        if run_err ~= nil then
            cb(nil, run_err)
            return
        end
        cb(true)
    end)
end

---@param target string tmux target-pane (session:window.pane or pane id)
---@param text string prompt text, written verbatim; may contain anything
---@return boolean|nil ok
---@return string? err
function M.send_keys_pane(target, text)
    if not M.available() then
        return nil, 'tmux not available'
    end
    if not matches_pattern(target, TARGET_PATTERN) then
        return nil, 'target must match ' .. TARGET_PATTERN
    end
    if type(text) ~= 'string' then
        return nil, 'text must be a string'
    end
    if #text > TEXT_BYTES_MAX then
        return nil, 'text exceeds ' .. TEXT_BYTES_MAX .. ' bytes'
    end
    local path, write_err = write_temp_text(text)
    if path == nil then
        return nil, write_err
    end
    local function remove_temp()
        pcall(os.remove, path)
    end
    local load_argv = {
        'tmux',
        'load-buffer',
        '-b',
        PROMPT_BUFFER_NAME,
        path,
    }
    local paste_argv = {
        'tmux',
        'paste-buffer',
        '-b',
        PROMPT_BUFFER_NAME,
        '-t',
        target,
        '-d',
    }
    local keys_argv = { 'tmux', 'send-keys', '-t', target, 'Enter' }
    local steps = {
        { load_argv, 'load-buffer' },
        { paste_argv, 'paste-buffer' },
        { keys_argv, 'send-keys' },
    }
    for _, step in ipairs(steps) do
        local _, run_err = run_tmux(step[1], step[2])
        if run_err ~= nil then
            remove_temp()
            return nil, run_err
        end
    end
    remove_temp()
    return true
end

---Non-blocking twin of send_keys_pane: the three tmux steps chain
---through libuv and cb fires on the main loop with (true) or
---(nil, err). The temp file is deleted on every path.
---@param target string tmux target-pane (session:window.pane or pane id)
---@param text string prompt text, written verbatim; may contain anything
---@param cb fun(ok: boolean?, err: string?)
function M.send_keys_pane_async(target, text, cb)
    assert(type(cb) == 'function', 'cb must be a function')
    if not M.available() then
        cb(nil, 'tmux not available')
        return
    end
    if not matches_pattern(target, TARGET_PATTERN) then
        cb(nil, 'target must match ' .. TARGET_PATTERN)
        return
    end
    if type(text) ~= 'string' then
        cb(nil, 'text must be a string')
        return
    end
    if #text > TEXT_BYTES_MAX then
        cb(nil, 'text exceeds ' .. TEXT_BYTES_MAX .. ' bytes')
        return
    end
    local path, write_err = write_temp_text(text)
    if path == nil then
        cb(nil, write_err)
        return
    end
    local function remove_temp()
        pcall(os.remove, path)
    end
    local load_argv = { 'tmux', 'load-buffer', '-b', PROMPT_BUFFER_NAME, path }
    local paste_argv = { 'tmux', 'paste-buffer', '-b', PROMPT_BUFFER_NAME, '-t', target, '-d' }
    local keys_argv = { 'tmux', 'send-keys', '-t', target, 'Enter' }
    local steps = {
        { load_argv, 'load-buffer' },
        { paste_argv, 'paste-buffer' },
        { keys_argv, 'send-keys' },
    }
    local function run_step(index)
        if index > #steps then
            remove_temp()
            cb(true)
            return
        end
        run_tmux_async(steps[index][1], steps[index][2], function(_, run_err)
            if run_err ~= nil then
                remove_temp()
                cb(nil, run_err)
                return
            end
            run_step(index + 1)
        end)
    end
    run_step(1)
end

---@param target string tmux target-pane (session:window.pane or pane id)
---@param lines integer? scrollback lines to capture; default 200, max 2000
---@return string? text pane text; may be empty
---@return string? err
function M.capture_pane(target, lines)
    if not M.available() then
        return nil, 'tmux not available'
    end
    if not matches_pattern(target, TARGET_PATTERN) then
        return nil, 'target must match ' .. TARGET_PATTERN
    end
    local count = CAPTURE_LINES_DEFAULT
    if lines ~= nil then
        if type(lines) ~= 'number' then
            return nil, 'lines must be a number'
        end
        count = math.floor(lines)
    end
    count = math.max(1, math.min(count, CAPTURE_LINES_MAX))
    local argv = {
        'tmux',
        'capture-pane',
        '-t',
        target,
        '-p',
        '-S',
        '-' .. tostring(count),
    }
    local result, run_err = run_tmux(argv, 'capture-pane')
    if result == nil then
        return nil, run_err
    end
    return result.stdout
end

---Non-blocking twin of capture_pane: cb fires on the main loop with
---(text, nil); text may be empty. (nil, err) on failure.
---@param target string tmux target-pane (session:window.pane or pane id)
---@param lines integer? scrollback lines to capture; default 200, max 2000
---@param cb fun(text: string?, err: string?)
function M.capture_pane_async(target, lines, cb)
    assert(type(cb) == 'function', 'cb must be a function')
    if not M.available() then
        cb(nil, 'tmux not available')
        return
    end
    if not matches_pattern(target, TARGET_PATTERN) then
        cb(nil, 'target must match ' .. TARGET_PATTERN)
        return
    end
    local count = CAPTURE_LINES_DEFAULT
    if lines ~= nil then
        if type(lines) ~= 'number' then
            cb(nil, 'lines must be a number')
            return
        end
        count = math.floor(lines)
    end
    count = math.max(1, math.min(count, CAPTURE_LINES_MAX))
    local argv = {
        'tmux',
        'capture-pane',
        '-t',
        target,
        '-p',
        '-S',
        '-' .. tostring(count),
    }
    run_tmux_async(argv, 'capture-pane', function(result, run_err)
        if result == nil then
            cb(nil, run_err)
            return
        end
        cb(result.stdout)
    end)
end

---@param name string tmux session name
---@return boolean|nil ok
---@return string? err
function M.kill_session(name)
    if not M.available() then
        return nil, 'tmux not available'
    end
    if not matches_pattern(name, SESSION_NAME_PATTERN) then
        return nil, 'name must match ' .. SESSION_NAME_PATTERN
    end
    local argv = { 'tmux', 'kill-session', '-t', name }
    local _, run_err = run_tmux(argv, 'kill-session')
    if run_err ~= nil then
        return nil, run_err
    end
    return true
end

---Non-blocking twin of kill_session, for async failure cleanup.
---@param name string
---@param cb fun(ok: boolean?, err: string?)
function M.kill_session_async(name, cb)
    assert(type(cb) == 'function', 'cb must be a function')
    if not M.available() then
        cb(nil, 'tmux not available')
        return
    end
    if not matches_pattern(name, SESSION_NAME_PATTERN) then
        cb(nil, 'name must match ' .. SESSION_NAME_PATTERN)
        return
    end
    local argv = { 'tmux', 'kill-session', '-t', name }
    run_tmux_async(argv, 'kill-session', function(_, run_err)
        if run_err ~= nil then
            cb(nil, run_err)
            return
        end
        cb(true)
    end)
end

---@return string[]? names session names, empty when tmux has none
---@return string? err
function M.list_sessions()
    if not M.available() then
        return nil, 'tmux not available'
    end
    local argv = { 'tmux', 'list-sessions', '-F', '#{session_name}' }
    local result, run_err = run_tmux(argv, 'list-sessions')
    if result == nil then
        return nil, run_err
    end
    local names = {}
    for line in result.stdout:gmatch('[^\r\n]+') do
        names[#names + 1] = line
    end
    return names
end

return M
