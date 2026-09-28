--- DAP session manager — keeps track of one debugging conversation.
---
--- Plain-language version: a debug session is one ongoing conversation
--- between Neovim and a debug adapter. This module holds the state for
--- that conversation: which adapter, which threads and frames exist, what
--- the current pause looks like. It is created when debugging starts and
--- cleaned up when it ends.
---@module 'dap.session'
--[[
# #################################################################
# /qompassai/lua/dap/session.lua
# Qompass AI Session
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# #################################################################
--]]
local uv = vim.uv
local api = vim.api
local rpc = require('dap.rpc')
local utils = require('dap.utils')
local breakpoints = require('dap.breakpoints')
local progress = require('dap.progress')
local log_mod = require('dap.log')
-- Logging is best-effort: a broken log path must not break debugging.
local log = log_mod.create_logger('dap.log') or log_mod.null_logger()
local repl = require('dap.repl')
local sec_to_ms = 1000
local non_empty = utils.non_empty
local index_of = utils.index_of
local mime_to_filetype = {
    ['text/javascript'] = 'javascript',
}

local err_mt = {
    __tostring = function(e)
        return utils.fmt_error(e) or 'Undefined error'
    end,
}

local ns_pool = {}
do
    local next_id = 1
    local pool = {}

    ---@return integer
    function ns_pool.acquire()
        local ns = next(pool)
        if ns then
            pool[ns] = nil
            return ns
        end
        ns = api.nvim_create_namespace('dap-' .. tostring(next_id))
        next_id = next_id + 1
        return ns
    end

    ---@param ns integer
    function ns_pool.release(ns)
        pool[ns] = true
    end
end

-- Bounded defaults for adapter/user-supplied numbers. Bare `or` chains
-- treat 0 as "unset"; `bounded_number` below treats only nil as unset and
-- clamps to a ceiling, so a hostile or buggy adapter config cannot force
-- unbounded waits, retries, or buffering.
local PIPE_TIMEOUT_DEFAULT_MS = 5000
local PIPE_TIMEOUT_MAX_MS = 60000
local PIPE_POLL_INTERVAL_MS = 50
local CONNECT_RETRIES_DEFAULT = 14
local CONNECT_RETRIES_MAX = 300
local INITIALIZE_TIMEOUT_DEFAULT_SEC = 4
local INITIALIZE_TIMEOUT_MAX_SEC = 60
local DISCONNECT_TIMEOUT_DEFAULT_SEC = 3
local DISCONNECT_TIMEOUT_MAX_SEC = 30
local REQUEST_TIMEOUT_DEFAULT_MS = 30000
local REQUEST_TIMEOUT_MAX_MS = 300000
local SOURCE_CONTENT_MAX_BYTES = 1024 * 1024
local SIGKILL_ESCALATION_NS = 5000000000

---@param value number? user-supplied value; only nil falls back to `default`
---@param default integer
---@param max integer ceiling; values above are clamped
---@return integer
local function bounded_number(value, default, max)
    local n = tonumber(utils.if_nil(value, default)) or default
    if n < 0 then
        return 0
    end
    return math.min(math.floor(n), max)
end

-- Events defined by the Debug Adapter Protocol. Anything else arriving on
-- the wire is logged and dropped instead of being dispatched through a
-- dynamic `self['event_' .. name]` lookup, which would let a rogue adapter
-- invoke arbitrary `event_*` methods on the session.
---@type table<string, boolean>
local known_events = {
    initialized = true,
    stopped = true,
    continued = true,
    exited = true,
    terminated = true,
    thread = true,
    output = true,
    breakpoint = true,
    module = true,
    loadedSource = true,
    process = true,
    capabilities = true,
    progressStart = true,
    progressUpdate = true,
    progressEnd = true,
    invalidated = true,
    memory = true,
}

---@class dap.session.PendingRequest
---@field command string request command name, for log messages
---@field generation integer session generation when the request was sent
---@field is_coroutine boolean true when the caller yielded waiting for the response
---@field callback fun(err: dap.ErrorResponse?, response: any?) delivers the response

---@class dap.Session
---@field capabilities dap.Capabilities
---@field adapter dap.Adapter
---@field private dirty table<string, boolean>
---@field private handlers table<string, fun(self: dap.Session, payload: table)|fun()>
---@field private message_callbacks table<number, dap.session.PendingRequest>
---@field private message_requests table<number, any>
---@field private message_timers table<number, uv.uv_timer_t>
---@field private generation integer incremented on close; stale responses are dropped
---@field private client dap.TransportClient
---@field private handle uv.uv_stream_t
---@field current_frame dap.StackFrame|nil
---@field initialized boolean
---@field term_buf? integer
---@field stopped_thread_id number|nil
---@field id number
---@field threads table<number, dap.Thread>
---@field filetype string filetype of the buffer where the session was started
---@field ns integer Namespace id. Valid during lifecycle of a session
---@field sign_group string
---@field closed boolean
--- Invoked when a session closes. The session is non-functional at this point and the
--- handler may run in the luv event loop (not API-safe, may require vim.schedule).
---@field on_close table<string, fun(session: dap.Session)> Handler per plugin-id
---@field children table<number, dap.Session>
---@field parent dap.Session|nil
---@field config dap.Configuration

---@class dap.TransportClient
---@field close fun(cb: function)
---@field write fun(line: string)

---@class dap.Session
local Session = {}
local session_mt = { __index = Session }

local function json_decode(payload)
    return vim.json.decode(payload, { luanil = { object = true } })
end
local json_encode = vim.json.encode
local function send_payload(client, payload)
    local msg = rpc.msg_with_content_length(json_encode(payload))
    client.write(msg)
end

local function dap()
    return require('dap')
end

local function ui()
    return require('dap.ui')
end

---@param session dap.Session
---@return table<string, any>
local function defaults(session)
    return dap().defaults[session.config.type]
end

local function coresume(co)
    return function(...)
        if coroutine.status(co) == 'suspended' then
            coroutine.resume(co, ...)
        else
            local args = { ... }
            vim.schedule(function()
                assert(
                    coroutine.status(co) == 'suspended',
                    'Incorrect use of coresume. Callee must have yielded'
                )
                coroutine.resume(co, unpack(args))
            end)
        end
    end
end

---@param env table<string, string>?
---@param terminal {command: string, args: string[]?}
---@param args string[]
---@param cwd string
---@return uv.uv_process_t? handle, integer? pid
local function launch_external_terminal(env, terminal, args, cwd)
    local handle
    local pid_or_err
    local full_args = {}
    vim.list_extend(full_args, terminal.args or {})
    vim.list_extend(full_args, args)
    -- Initializing to nil is important so environment is inherited by the terminal
    local env_formatted = nil
    if env then
        env_formatted = {}
        -- Copy environment, prefer vars set by client
        for k, v in pairs(vim.tbl_extend('keep', env, vim.fn.environ())) do
            if k:find('^[^=]*$') then -- correct variable?
                env_formatted[#env_formatted + 1] = k .. '=' .. tostring(v)
            end
        end
    end
    local opts = {
        args = full_args,
        detached = true,
        cwd = (cwd and cwd ~= '') and cwd or nil,
        env = env_formatted,
    }
    handle, pid_or_err = uv.spawn(terminal.command, opts, function(code)
        if handle then
            handle:close()
        end
        if code ~= 0 then
            utils.notify(
                string.format(
                    'Terminal exited %d running %s %s',
                    code,
                    terminal.command,
                    table.concat(full_args, ' ')
                ),
                vim.log.levels.ERROR
            )
        end
    end)
    return handle, pid_or_err
end

---@param terminal_win_cmd string|fun(config: dap.Configuration):(integer, integer?)
---@param config dap.Configuration
---@return integer bufnr, integer? winnr
local function create_terminal_buf(terminal_win_cmd, config)
    local cur_win = api.nvim_get_current_win()
    if type(terminal_win_cmd) == 'string' then
        api.nvim_command(terminal_win_cmd)
        local bufnr = api.nvim_get_current_buf()
        local win = api.nvim_get_current_win()
        api.nvim_set_current_win(cur_win)
        return bufnr, win
    else
        assert(
            type(terminal_win_cmd) == 'function',
            'terminal_win_cmd must be a string or a function'
        )
        return terminal_win_cmd(config)
    end
end

local terminals = {}
do
    ---@type table<integer, boolean>
    local pool = {}

    ---@param win_cmd string|fun(config: dap.Configuration):(integer, integer?)
    ---@param config dap.Configuration
    ---@param filetype string
    ---@return integer, integer|nil
    function terminals.acquire(win_cmd, config, filetype)
        local buf = next(pool)
        if buf then
            pool[buf] = nil
            if api.nvim_buf_is_valid(buf) then
                vim.bo[buf].modified = false
                return buf
            end
        end
        local terminal_win
        local prev_buf = api.nvim_get_current_buf()
        buf, terminal_win = create_terminal_buf(win_cmd, config)
        assert(buf, 'terminal_win_cmd must return a buffer number')
        vim.bo[buf].errorformat = vim.bo[prev_buf].errorformat
        if vim.filetype then
            local path = vim.filetype.get_option(filetype, 'path')
            assert(type(path) == 'string', 'path option must be a string')
            vim.bo[buf].path = path
        else
            vim.bo[buf].path = vim.bo[prev_buf].path
        end
        if terminal_win then
            if vim.fn.has('nvim-0.8') == 1 then
                -- older versions don't support the `win` key
                api.nvim_set_option_value('number', false, { scope = 'local', win = terminal_win })
                api.nvim_set_option_value(
                    'relativenumber',
                    false,
                    { scope = 'local', win = terminal_win }
                )
                api.nvim_set_option_value(
                    'signcolumn',
                    'no',
                    { scope = 'local', win = terminal_win }
                )
            else
                -- this is like `:set` so new windows will inherit the values :/
                vim.wo[terminal_win].number = false
                vim.wo[terminal_win].relativenumber = false
                vim.wo[terminal_win].signcolumn = 'no'
            end
        end
        vim.b[buf]['dap-type'] = config.type
        return buf, terminal_win
    end

    ---@param b number
    function terminals.release(b)
        pool[b] = true
    end
end

---@param lsession dap.Session
---@param request dap.Request
---@param lsession dap.Session
---@param request dap.Request
---@param body dap.RunInTerminalRequestArguments
---@param settings table
---@return boolean handled true if the external-terminal path sent the response
local function run_external_terminal(lsession, request, body, settings)
    local terminal = settings.external_terminal
    if not terminal then
        utils.notify(
            'Requested external terminal, but none configured. Fallback to integratedTerminal',
            vim.log.levels.WARN
        )
        return false
    end
    local handle, pid = launch_external_terminal(body.env, terminal, body.args, body.cwd)
    if not handle then
        utils.notify('Could not launch terminal ' .. terminal.command, vim.log.levels.ERROR)
    end
    lsession:response(request, {
        success = handle ~= nil,
        body = { processId = pid },
    })
    return true
end

---@param lsession dap.Session
---@param request dap.Request
---@param body dap.RunInTerminalRequestArguments
---@param settings table
local function run_integrated_terminal(lsession, request, body, settings)
    local cur_buf = api.nvim_get_current_buf()
    local terminal_buf, terminal_win =
        terminals.acquire(settings.terminal_win_cmd, lsession.config, lsession.filetype)
    local keymap_ok, keymap_err = pcall(api.nvim_buf_del_keymap, terminal_buf, 't', '<CR>')
    if not keymap_ok then
        log:debug('no <CR> terminal keymap to remove: ' .. tostring(keymap_err))
    end
    local path = vim.bo[cur_buf].path
    if path and path ~= '' then
        vim.bo[terminal_buf].path = path
    end

    local jobid
    lsession.term_buf = terminal_buf
    vim.api.nvim_buf_call(terminal_buf, function()
        -- jobstart with term=true subsumes the legacy termopen path;
        -- Neovim 0.11+ always provides it (diver requires 0.13+).
        jobid = vim.fn.jobstart(body.args, {
            env = next(body.env or {}) and body.env or vim.empty_dict(),
            cwd = (body.cwd and body.cwd ~= '') and body.cwd or nil,
            height = terminal_win and api.nvim_win_get_height(terminal_win)
                or math.ceil(vim.o.lines / 2),
            width = terminal_win and api.nvim_win_get_width(terminal_win) or vim.o.columns,
            term = true,
            on_exit = function()
                terminals.release(terminal_buf)
            end,
        })
    end)

    local terminal_buf_name = '[dap-terminal] ' .. (lsession.config.name or body.args[1])
    local terminal_name_ok, terminal_name_err =
        pcall(api.nvim_buf_set_name, terminal_buf, terminal_buf_name)
    if not terminal_name_ok then
        log:warn(
            'invalid terminal buffer name '
                .. terminal_buf_name
                .. ': '
                .. tostring(terminal_name_err)
        )
        api.nvim_buf_set_name(terminal_buf, '[dap-terminal] dap-' .. tostring(lsession.id))
    end

    if settings.focus_terminal then
        for _, win in pairs(api.nvim_tabpage_list_wins(0)) do
            if api.nvim_win_get_buf(win) == terminal_buf then
                api.nvim_set_current_win(win)
                break
            end
        end
    end
    if jobid == 0 or jobid == -1 then
        log:error('Could not spawn terminal', jobid, request)
        lsession:response(request, {
            success = false,
            message = 'Could not spawn terminal',
        })
    else
        lsession:response(request, {
            success = true,
            body = {
                processId = vim.fn.jobpid(jobid),
            },
        })
    end
end

local function run_in_terminal(lsession, request)
    ---@type dap.RunInTerminalRequestArguments
    local body = request.arguments
    log:debug('run_in_terminal', body)
    local settings = dap().defaults[lsession.config.type]
    if
        body.kind == 'external'
        or (settings.force_external_terminal and settings.external_terminal)
    then
        if run_external_terminal(lsession, request, body, settings) then
            return
        end
    end
    run_integrated_terminal(lsession, request, body, settings)
end

function Session:event_initialized()
    local function on_done()
        if self.capabilities.supportsConfigurationDoneRequest then
            self:request('configurationDone', nil, function(err1, _)
                if err1 then
                    utils.notify(tostring(err1), vim.log.levels.ERROR)
                end
                self.initialized = true
            end)
        else
            self.initialized = true
        end
    end

    local bps = breakpoints.get()
    self:set_breakpoints(bps, function()
        if self.capabilities.exceptionBreakpointFilters then
            self:set_exception_breakpoints(
                dap().defaults[self.config.type].exception_breakpoints,
                nil,
                on_done
            )
        else
            on_done()
        end
    end)
end

---@param thread_id number
---@param bufnr integer
---@param frame dap.StackFrame
function Session:_show_exception_info(thread_id, bufnr, frame)
    if not self.capabilities.supportsExceptionInfoRequest then
        return
    end
    local err, response = self:request('exceptionInfo', { threadId = thread_id })
    if err then
        utils.notify('Error getting exception info: ' .. tostring(err), vim.log.levels.ERROR)
    end
    if not response then
        return
    end
    local msg_parts = {}
    local exception_type = response.details and response.details.typeName
    local of_type = exception_type and ' of type ' .. exception_type or ''
    table.insert(
        msg_parts,
        ('Thread stopped due to exception' .. of_type .. ' (' .. response.breakMode .. ')')
    )
    if response.description then
        table.insert(msg_parts, ('Description: ' .. response.description))
    end
    local details = response.details or {}
    if details.stackTrace then
        table.insert(msg_parts, 'Stack trace:')
        table.insert(msg_parts, details.stackTrace)
    end
    if details.innerException then
        table.insert(msg_parts, 'Inner Exceptions:')
        for _, e in pairs(details.innerException) do
            table.insert(msg_parts, vim.inspect(e))
        end
    end
    vim.diagnostic.set(self.ns, bufnr, {
        {
            bufnr = bufnr,
            lnum = frame.line - 1,
            end_lnum = frame.endLine and (frame.endLine - 1) or nil,
            col = frame.column and (frame.column - 1) or 0,
            end_col = frame.endColumn,
            severity = vim.diagnostic.severity.ERROR,
            message = table.concat(msg_parts, '\n'),
            source = 'nvim-dap',
        },
    })
end

---@param win integer
---@param line integer
---@param column integer
local function set_cursor(win, line, column)
    local ok, err = pcall(api.nvim_win_set_cursor, win, { line, column - 1 })
    if ok then
        local curbuf = api.nvim_get_current_buf()
        if vim.bo[curbuf].filetype ~= 'dap-repl' then
            api.nvim_set_current_win(win)
        end
        api.nvim_win_call(win, function()
            api.nvim_command('normal! zv')
        end)
    else
        local msg = string.format(
            'Adapter reported frame in buf %d line %d:%d, but: %s. '
                .. 'Ensure executable is up2date and if using a source mapping ensure it is'
                .. ' correct',
            api.nvim_win_get_buf(win),
            line,
            column,
            err
        )
        utils.notify(msg, vim.log.levels.WARN)
    end
end

---@param bufnr integer
---@param line integer
---@param column integer
---@param switchbuf string|fun(bufnr: integer, line: integer, column: integer):nil
---@param filetype string
---@return boolean
--- Build the `switchbuf` jump strategies for `jump_to_location`.
---
--- Extracted so `jump_to_location` stays small; behavior is unchanged.
--- Buffer names passed to `:split`/`:vsplit`/`:tabnew` go through
--- `vim.fn.fnameescape` so a hostile adapter path cannot inject Ex commands.
---@param cur_buf integer
---@param cur_win integer
---@param bufnr integer
---@param line integer
---@param column integer
---@param filetype string?
---@return table<string, fun(): boolean>
local function make_switchbuf_fns(cur_buf, cur_win, bufnr, line, column, filetype)
    local switchbuf_fn = {}

    function switchbuf_fn.uselast()
        local ok, is_source_buf = pcall(vim.api.nvim_buf_get_var, cur_buf, 'dap_source_buf')
        is_source_buf = ok and is_source_buf
        if
            vim.bo[cur_buf].buftype == ''
            or vim.bo[cur_buf].filetype == filetype
            or is_source_buf
        then
            api.nvim_win_set_buf(cur_win, bufnr)
            set_cursor(cur_win, line, column)
        else
            local win = vim.fn.win_getid(vim.fn.winnr('#'))
            if win then
                api.nvim_win_set_buf(win, bufnr)
                set_cursor(win, line, column)
            end
        end
        return true
    end

    function switchbuf_fn.usevisible()
        if api.nvim_win_get_buf(cur_win) == bufnr then
            local first = vim.fn.line('w0', cur_win)
            local last = vim.fn.line('w$', cur_win)
            if first <= line and line <= last then
                return true
            end
        end
        return false
    end

    function switchbuf_fn.useopen()
        if api.nvim_win_get_buf(cur_win) == bufnr then
            set_cursor(cur_win, line, column)
            return true
        end
        for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
            if api.nvim_win_get_buf(win) == bufnr then
                set_cursor(win, line, column)
                return true
            end
        end
        return false
    end

    function switchbuf_fn.usetab()
        if api.nvim_win_get_buf(cur_win) == bufnr then
            set_cursor(cur_win, line, column)
            return true
        end
        local tabs = { 0 }
        vim.list_extend(tabs, api.nvim_list_tabpages())
        for _, tabpage in ipairs(tabs) do
            for _, win in ipairs(api.nvim_tabpage_list_wins(tabpage)) do
                if api.nvim_win_get_buf(win) == bufnr then
                    api.nvim_set_current_tabpage(tabpage)
                    set_cursor(win, line, column)
                    return true
                end
            end
        end
        return false
    end

    function switchbuf_fn.split()
        vim.cmd('split ' .. vim.fn.fnameescape(api.nvim_buf_get_name(bufnr)))
        set_cursor(0, line, column)
        return true
    end

    function switchbuf_fn.vsplit()
        vim.cmd('vsplit ' .. vim.fn.fnameescape(api.nvim_buf_get_name(bufnr)))
        set_cursor(0, line, column)
        return true
    end

    function switchbuf_fn.newtab()
        vim.cmd('tabnew ' .. vim.fn.fnameescape(api.nvim_buf_get_name(bufnr)))
        set_cursor(0, line, column)
        return true
    end
    return switchbuf_fn
end

local function jump_to_location(bufnr, line, column, switchbuf, filetype)
    -- vscode-go sends columns with 0
    -- That would cause a "Column value outside range" error calling nvim_win_set_cursor
    -- nvim-dap says "columnsStartAt1 = true" on initialize :/
    if column == 0 then
        column = 1
    end
    local cur_buf = api.nvim_get_current_buf()
    if cur_buf == bufnr and api.nvim_win_get_cursor(0)[1] == line and column == 1 then
        -- A user might have positioned the cursor over a variable in anticipation of hitting a
        -- breakpoint
        -- Don't move the cursor to the beginning of the line if it's in the right place
        return true
    end

    local cur_win = api.nvim_get_current_win()
    local switchbuf_fn = make_switchbuf_fns(cur_buf, cur_win, bufnr, line, column, filetype)

    if type(switchbuf) == 'string' and switchbuf:find('usetab') then
        switchbuf_fn.useopen = switchbuf_fn.usetab
    end

    if type(switchbuf) == 'string' and switchbuf:find('newtab') then
        switchbuf_fn.vsplit = switchbuf_fn.newtab
        switchbuf_fn.split = switchbuf_fn.newtab
    end

    if type(switchbuf) == 'function' then
        switchbuf(bufnr, line, column)
        return true
    end

    local opts = vim.split(switchbuf, ',', { plain = true })
    for _, opt in pairs(opts) do
        local fn = switchbuf_fn[opt]
        if fn and fn() then
            return true
        end
    end
    utils.notify(
        'Stopped at line '
            .. line
            .. ' but `switchbuf` setting prevented jump to location. Target buffer '
            .. bufnr
            .. ' not open in any window?',
        vim.log.levels.WARN
    )
    return false
end

--- Get the bufnr for a frame.
--- Might load source as a side effect if frame.source has sourceReference ~= 0
--- Must be called in a coroutine
---
---@param session dap.Session
---@param source dap.Source?
---@return integer|nil
local function source_to_bufnr(session, source)
    if not source then
        return nil
    end
    local source_ref = source.sourceReference
    if not source_ref or source_ref == 0 then
        if not source.path then
            return nil
        end
        local scheme = source.path:match('^([a-z]+)://.*')
        if scheme then
            return vim.uri_to_bufnr(source.path)
        else
            return vim.uri_to_bufnr(vim.uri_from_fname(source.path))
        end
    end
    local fname = string.format('dap-src://%d/%d/%s', session.id, source_ref, source.path or '')
    return vim.uri_to_bufnr(fname)
end

---@param session dap.Session
---@param frame dap.StackFrame
---@param preserve_focus_hint boolean
---@param stopped nil|dap.StoppedEvent
---@return boolean
local function jump_to_frame(session, frame, preserve_focus_hint, stopped)
    local source = frame.source
    if not source then
        utils.notify('Source missing, cannot jump to frame: ' .. frame.name, vim.log.levels.INFO)
        return false
    end
    vim.fn.sign_unplace(session.sign_group)
    if preserve_focus_hint or frame.line < 0 then
        return false
    end
    local bufnr = source_to_bufnr(session, frame.source)
    if not bufnr then
        utils.notify('Source missing, cannot jump to frame: ' .. frame.name, vim.log.levels.INFO)
        return false
    end
    vim.fn.bufload(bufnr)
    vim.bo[bufnr].buflisted = true
    local ok, failure =
        pcall(
            vim.fn.sign_place,
            0,
            session.sign_group,
            'DapStopped',
            bufnr,
            { lnum = frame.line, priority = 22 }
        )
    if not ok then
        utils.notify(tostring(failure), vim.log.levels.ERROR)
    end
    local switchbuf = defaults(session).switchbuf or vim.o.switchbuf or 'uselast'
    local jumped = jump_to_location(bufnr, frame.line, frame.column, switchbuf, session.filetype)
    if stopped and stopped.reason == 'exception' then
        session:_show_exception_info(stopped.threadId, bufnr, frame)
    end
    return jumped
end

--- Request a source
---@param source dap.Source
---@param cb fun(err: dap.ErrorResponse?, buf: integer?) buffer with the source contents
---@deprecated Open a buffer named "dap-src://<session-id>/<source-ref>/<source-path>" instead
function Session:source(source, cb)
    assert(source, 'source is required')
    assert(source.sourceReference, 'sourceReference is required')
    assert(source.sourceReference ~= 0, 'sourceReference must not be 0')
    local params = {
        source = source,
        sourceReference = source.sourceReference,
    }

    ---@param err dap.ErrorResponse
    ---@param response dap.SourceResponse
    local function on_source(err, response)
        if err then
            cb(err, nil)
            return
        end
        -- A success response with no body is legal on the wire; it just
        -- carries no source to show.
        if type(response) ~= 'table' then
            cb(setmetatable({ message = 'source response has no body' }, err_mt), nil)
            return
        end
        local content = response.content
        if type(content) ~= 'string' then
            cb(setmetatable({ message = 'source response content is not a string' }, err_mt), nil)
            return
        end
        if #content > SOURCE_CONTENT_MAX_BYTES then
            utils.notify(
                string.format(
                    'Source response too large (%d bytes); truncated to %d bytes',
                    #content,
                    SOURCE_CONTENT_MAX_BYTES
                ),
                vim.log.levels.WARN
            )
            content = content:sub(1, SOURCE_CONTENT_MAX_BYTES)
        end
        local buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_var(buf, 'dap_source_buf', true)
        local adapter_options = self.adapter.options or {}
        local ft = mime_to_filetype[response.mimeType] or adapter_options.source_filetype
        if ft then
            vim.bo[buf].filetype = ft
        end
        api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n'))
        if not ft and source.path and vim.filetype then
            local name_ok, name_err = pcall(api.nvim_buf_set_name, buf, source.path)
            if not name_ok then
                log:debug('could not name source buffer: ' .. tostring(name_err))
            end
            local ok, filetype = pcall(vim.filetype.match, source.path, buf)
            if not ok then
                -- API changed
                ok, filetype = pcall(vim.filetype.match, { buf = buf })
            end
            if ok and filetype then
                vim.bo[buf].filetype = filetype
            end
        end
        cb(nil, buf)
    end

    self:request('source', params, on_source)
end

---@param cb fun(err: dap.ErrorResponse?)
function Session:update_threads(cb)
    ---@param err dap.ErrorResponse?
    ---@param response dap.ThreadResponse?
    local on_threads = function(err, response)
        if err then
            cb(err)
            return
        end
        local threads = {}
        for _, thread in ipairs((response or {}).threads) do
            threads[thread.id] = thread
            local old_thread = self.threads[thread.id]
            if old_thread then
                local stopped = old_thread.stopped == nil and false or old_thread.stopped
                thread.stopped = stopped
                thread.frames = old_thread.frames
            end
        end
        self.threads = threads
        self.dirty.threads = false
        cb(nil)
    end

    self:request('threads', nil, on_threads)
end

---@param frames dap.StackFrame[]
---@return dap.StackFrame|nil
local function get_top_frame(frames)
    for _, frame in pairs(frames) do
        if frame.source then
            return frame
        end
    end
    local _, first = next(frames)
    return first
end

---@param stopped dap.StoppedEvent
function Session:event_stopped(stopped)
    ---dap.async.run always executes this body in a coroutine.
    require('dap.async').run(function()
        local co = coroutine.running()
        -- The event dispatch guard only validates the generation at
        -- dispatch time. Re-check after every yield below: the session
        -- may have closed while this coroutine was suspended.
        local gen = self.generation

        if self.dirty.threads or (stopped.threadId and self.threads[stopped.threadId] == nil) then
            local thread = {
                id = stopped.threadId,
                name = 'Unknown',
                stopped = true,
            }
            if thread.id then
                self.threads[thread.id] = thread
            end
            self:update_threads(coresume(co))
            -- Intentional await-in-sync: this callback always runs inside
            -- dap.async.run's coroutine; annotating it async would falsely
            -- taint Session:event_stopped's sync callers.
            local err = coroutine.yield()
            if gen ~= self.generation or self.closed then
                return
            end
            if err then
                utils.notify('Error retrieving threads: ' .. tostring(err), vim.log.levels.ERROR)
                return
            end
            if thread.stopped == false then
                log:debug('Thread resumed during stopped event handling', stopped, thread)
                return
            end
        end

        local should_jump = stopped.reason ~= 'pause' or stopped.allThreadsStopped

        -- Some debug adapters allow to continue/step via custom REPL commands (via evaluate)
        -- That by-passes `clear_running`, resulting in self.stopped_thread_id still being set
        -- Dont auto-continue if`threadId == self.stopped_thread_id`, but stop & jump
        if
            self.stopped_thread_id
            and self.stopped_thread_id ~= stopped.threadId
            and should_jump
        then
            if defaults(self).auto_continue_if_many_stopped then
                local thread = self.threads[self.stopped_thread_id]
                local thread_name = thread and thread.name or self.stopped_thread_id
                log:debug(
                    'Received stopped event, but '
                        .. thread_name
                        .. ' is already stopped. '
                        .. 'Resuming newly stopped thread. '
                        .. 'To disable this set the `auto_continue_if_many_stopped` option to'
                        .. ' false.'
                )
                self:request('continue', { threadId = stopped.threadId }, function() end)
                return
            else
                -- Allow thread to stop, but don't jump to it because stepping
                -- interleaved between threads is confusing
                should_jump = false
            end
        end
        if should_jump then
            self.stopped_thread_id = stopped.threadId
        end

        if stopped.allThreadsStopped then
            progress.report('All threads stopped')
            for _, thread in pairs(self.threads) do
                thread.stopped = true
            end
        elseif not stopped.threadId then
            utils.notify(
                'Stopped event received, but no threadId or allThreadsStopped',
                vim.log.levels.WARN
            )
        end

        if not stopped.threadId then
            return
        end
        progress.report('Thread stopped: ' .. stopped.threadId)
        local thread = self.threads[stopped.threadId]
        if not thread then
            thread = {
                id = stopped.threadId,
                name = 'Unknown',
            }
            self.threads[stopped.threadId] = thread
        end
        thread.stopped = true

        ---@type dap.StackTraceArguments
        local params = {
            startFrame = 0,
            threadId = stopped.threadId,
        }
        local err, response = self:request('stackTrace', params)
        if gen ~= self.generation or self.closed then
            return
        end
        if thread.stopped == false then
            log:debug('Debug adapter resumed during stopped event handling', thread, err)
            return
        end
        if err then
            utils.notify('Error retrieving stack traces: ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        assert(response, 'Must have response if there is no error')
        local frames = response.stackFrames --[=[@as dap.StackFrame[]]=]
        thread.frames = frames
        local current_frame = get_top_frame(frames)
        if not current_frame then
            utils.notify('Debug adapter stopped at unavailable location', vim.log.levels.WARN)
            return
        end
        if should_jump then
            self.current_frame = current_frame
            local jumped = jump_to_frame(self, current_frame, stopped.preserveFocusHint, stopped)
            if jumped then
                progress.report('Stopped at line ' .. tostring(current_frame.line))
            end
            self:_request_scopes(current_frame)
        elseif stopped.reason == 'exception' then
            local bufnr = source_to_bufnr(self, current_frame.source)
            if bufnr then
                self:_show_exception_info(stopped.threadId, bufnr, current_frame)
            end
        end
    end)
end

---@param body dap.TerminatedEvent
function Session:event_terminated(body)
    self:close()
    if body and body.restart ~= nil and body.restart ~= false then
        local config = vim.deepcopy(self.config)

        ---@diagnostic disable-next-line: inject-field
        config.__restart = body.restart
        -- This will set global session, is this still okay once startDebugging is implemented?
        dap().run(config, { filetype = self.filetype, new = true })
    end
end

---@param body dap.OutputEvent
function Session:event_output(body)
    local settings = defaults(self)
    local on_output = settings.on_output
    if on_output then
        on_output(self, body)
        return
    end
    if body.category == 'telemetry' then
        log:info('Telemetry', body.output)
    else
        repl.append(body.output, '$', { newline = false })
    end
end

---@param current_frame dap.StackFrame
function Session:_request_scopes(current_frame)
    local params = {
        frameId = current_frame.id,
    }
    ---@param scope_resp dap.ScopesResponse?
    local function on_scopes(_, scope_resp)
        if not scope_resp then
            return
        end
        local scopes = scope_resp.scopes
        current_frame.scopes = scopes
        for _, scope in ipairs(scopes) do
            if not scope.expensive then
                ---@param resp dap.VariableResponse?
                local function on_variables(_, resp)
                    scope.variables = resp and resp.variables or nil
                    for _, v in ipairs(scope.variables or {}) do
                        v.parent = scope
                    end
                end

                local varparams = { variablesReference = scope.variablesReference }
                self:request('variables', varparams, on_variables)
            end
        end
    end
    self:request('scopes', params, on_scopes)
end

---@param session dap.Session
---@param thread_id number?
local function clear_running(session, thread_id)
    vim.fn.sign_unplace(session.sign_group)
    thread_id = thread_id or session.stopped_thread_id
    session.stopped_thread_id = nil
    local thread = session.threads[thread_id]
    if thread then
        thread.stopped = false
    end
end

--- Goto specified line (source and col are optional)
function Session:_goto(line, source, col)
    local frame = self.current_frame
    if not frame then
        utils.notify('No current frame available, cannot use goto', vim.log.levels.INFO)
        return
    end
    if not self.capabilities.supportsGotoTargetsRequest then
        utils.notify("Debug Adapter doesn't support GotoTargetRequest", vim.log.levels.INFO)
        return
    end
    coroutine.wrap(function()
        local err, response = self:request(
            'gotoTargets',
            { source = source or frame.source, line = line, col = col }
        )
        if err then
            utils.notify('Error getting gotoTargets: ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        if not response or not response.targets then
            utils.notify("No goto targets available. Can't execute goto", vim.log.levels.INFO)
            return
        end
        local target = ui().pick_if_many(response.targets, 'goto target> ', function(candidate)
            return candidate.label
        end)
        if not target then
            return
        end
        local stopped_thread_id = self.stopped_thread_id
        local params = { threadId = stopped_thread_id, targetId = target.id }
        local thread = self.threads[stopped_thread_id]
        clear_running(self, stopped_thread_id)
        local goto_err = self:request('goto', params)
        if goto_err then
            self.stopped_thread_id = stopped_thread_id
            if thread then
                thread.stopped = true
            end
            utils.notify('Error executing goto: ' .. tostring(goto_err), vim.log.levels.ERROR)
        end
    end)()
end

do
    local function notify_if_missing_capability(bps, capabilities)
        for _, bp in pairs(bps) do
            if non_empty(bp.condition) and not capabilities.supportsConditionalBreakpoints then
                utils.notify(
                    "Debug adapter doesn't support breakpoints with conditions",
                    vim.log.levels.WARN
                )
            end
            local supports_hit_cond = capabilities.supportsHitConditionalBreakpoints
            if non_empty(bp.hitCondition) and not supports_hit_cond then
                utils.notify(
                    "Debug adapter doesn't support breakpoints with hit conditions",
                    vim.log.levels.WARN
                )
            end
            if non_empty(bp.logMessage) and not capabilities.supportsLogPoints then
                utils.notify("Debug adapter doesn't support log points", vim.log.levels.WARN)
            end
        end
    end

    ---@param args vim.api.keyset.create_autocmd.callback_args
    ---@return boolean
    local function remove_breakpoints(args)
        local session = dap().session()
        if session then
            session:set_breakpoints({ [args.buf] = {} })
        end
        return true
    end

    function Session:set_breakpoints(bps, on_done)
        local num_requests = vim.tbl_count(bps)
        if num_requests == 0 then
            if on_done then
                on_done()
            end
            return
        end
        for bufnr, buf_bps in pairs(bps) do
            notify_if_missing_capability(buf_bps, self.capabilities)
            if non_empty(buf_bps) then
                local group = 'dap-bps-del-' .. tostring(bufnr)
                api.nvim_create_autocmd('BufWipeout', {
                    group = api.nvim_create_augroup(group, { clear = true }),
                    buffer = bufnr,
                    callback = remove_breakpoints,
                })
            end
            local path = api.nvim_buf_get_name(bufnr)
            ---@type dap.SetBreakpointsArguments
            local payload = {
                source = {
                    path = path,
                    name = vim.fn.fnamemodify(path, ':t'),
                },
                sourceModified = false,
                breakpoints = vim.tbl_map(function(bp)
                    -- trim extra information like the state
                    return {
                        line = bp.line,
                        column = bp.column,
                        condition = bp.condition,
                        hitCondition = bp.hitCondition,
                        logMessage = bp.logMessage,
                    }
                end, buf_bps),
                lines = vim.tbl_map(function(x)
                    return x.line
                end, buf_bps),
            }
            ---@param err1 dap.ErrorResponse
            ---@param resp dap.SetBreakpointsResponse
            local function on_response(err1, resp)
                if err1 then
                    utils.notify(
                        'Error setting breakpoints: ' .. tostring(err1),
                        vim.log.levels.ERROR
                    )
                elseif resp then
                    for _, bp in pairs(resp.breakpoints) do
                        breakpoints.set_state(bufnr, bp)
                        if not bp.verified then
                            log:info('Breakpoint unverified', bp)
                        end
                    end
                end
                num_requests = num_requests - 1
                if num_requests == 0 and on_done then
                    on_done()
                end
            end
            self:request('setBreakpoints', payload, on_response)
        end
    end
end

function Session:set_exception_breakpoints(filters, exceptionOptions, on_done)
    if not self.capabilities.exceptionBreakpointFilters then
        utils.notify("Debug adapter doesn't support exception breakpoints", vim.log.levels.INFO)
        return
    end

    if filters == 'default' then
        local default_filters = {}
        for _, f in pairs(self.capabilities.exceptionBreakpointFilters) do
            if f.default then
                table.insert(default_filters, f.filter)
            end
        end
        filters = default_filters
    end

    if not filters then
        local possible_filters = {}
        for _, f in ipairs(self.capabilities.exceptionBreakpointFilters) do
            table.insert(possible_filters, f.filter)
        end
        ---@diagnostic disable-next-line: redundant-parameter, param-type-mismatch
        filters = vim.split(
            vim.fn.input('Exception breakpoint filters: ', table.concat(possible_filters, ' ')),
            ' '
        )
    end

    if exceptionOptions and not self.capabilities.supportsExceptionOptions then
        utils.notify('Debug adapter does not support ExceptionOptions', vim.log.levels.INFO)
        return
    end

    -- setExceptionBreakpoints, see
    -- https://microsoft.github.io/debug-adapter-protocol/specification
    -- #Requests_SetExceptionBreakpoints
    --- filters: string[]
    --- exceptionOptions: exceptionOptions?: ExceptionOptions[]
    --- (https://microsoft.github.io/debug-adapter-protocol/specification#Types_ExceptionOptions)
    self:request(
        'setExceptionBreakpoints',
        { filters = filters, exceptionOptions = exceptionOptions },
        function(err, _)
        if err then
            utils.notify(
                'Error setting exception breakpoints: ' .. tostring(err),
                vim.log.levels.ERROR
            )
        end
        if on_done then
            on_done()
        end
    end)
end

---@param listeners table<string, dap.RequestListener<any>|dap.EventListener<any>>
---@param ... any
local function call_listener(listeners, ...)
    for key, listener in pairs(listeners) do
        local remove = listener(...)
        if remove then
            listeners[key] = nil
        end
    end
end

--- Deliver a response that arrived after its session moved on (closed).
---
--- Callback-mode requests are dropped: invoking user code against cleared
--- session state is worse than silence. Coroutine-mode requests are resumed
--- with an error instead -- a suspended coroutine must never leak, and the
--- code after the yield already treats `err` as "bail out".
---@param pending dap.session.PendingRequest
---@param err dap.ErrorResponse
local function deliver_stale(pending, err)
    if pending.is_coroutine then
        local ok, resume_err = pcall(pending.callback, err, nil)
        if not ok then
            log:warn('stale ' .. pending.command .. ' resume failed: ' .. tostring(resume_err))
        end
    else
        log:debug('Dropping stale ' .. pending.command .. ' response')
    end
end

---@param timer uv.uv_timer_t?
local function stop_timer(timer)
    if timer then
        timer:stop()
        if not timer:is_closing() then
            timer:close()
        end
    end
end

--- Build the `on_error` callback for `rpc.create_read_loop`: a framing
--- failure means the byte stream can no longer be trusted, so the session
--- is torn down instead of limping on with a dead parser.
---@param session dap.Session
---@return fun(err: string)
local function framing_error_handler(session)
    return function(err)
        if not session.closed then
            utils.notify(err, vim.log.levels.ERROR)
            session:close()
        end
    end
end

function Session:handle_body(body)
    local decoded = assert(json_decode(body), 'Debug adapter must send JSON objects')
    log:debug(self.id, decoded)
    local listeners = dap().listeners
    if decoded.request_seq then
        local pending = self.message_callbacks[decoded.request_seq]
        local request = self.message_requests[decoded.request_seq]
        self.message_requests[decoded.request_seq] = nil
        self.message_callbacks[decoded.request_seq] = nil
        stop_timer(self.message_timers[decoded.request_seq])
        self.message_timers[decoded.request_seq] = nil
        if not pending then
            log:error('No callback found. Did the debug adapter send duplicate responses?', decoded)
            return
        end
        local err = nil
        local response = nil
        if decoded.success then
            response = decoded.body
        else
            err = {
                message = decoded.message,
                body = decoded.body,
            }
            setmetatable(err, err_mt)
        end
        vim.schedule(function()
            if self.generation ~= pending.generation then
                deliver_stale(
                    pending,
                    setmetatable(
                        {
                            message = 'session closed; dropping stale '
                                .. decoded.command
                                .. ' response',
                        },
                        err_mt
                    )
                )
                return
            end
            local before = listeners.before[decoded.command]
            call_listener(before, self, err, response, request, decoded.request_seq)
            local ok, cb_err = pcall(pending.callback, err, response)
            if not ok then
                log:warn(
                    'response callback error for '
                        .. decoded.command
                        .. ': '
                        .. tostring(cb_err)
                )
            end
            local after = listeners.after[decoded.command]
            call_listener(after, self, err, response, request, decoded.request_seq)
        end)
    elseif decoded.event then
        if type(decoded.event) ~= 'string' or not known_events[decoded.event] then
            log:warn('Ignoring unknown event from debug adapter', decoded.event)
            return
        end
        local callback_name = 'event_' .. decoded.event
        local callback = self[callback_name]
        local generation = self.generation
        vim.schedule(function()
            if self.generation ~= generation then
                log:debug('Dropping stale ' .. decoded.event .. ' event (session closed)')
                return
            end
            local before = listeners.before[callback_name]
            call_listener(before, self, decoded.body)
            if callback then
                local ok, cb_err = pcall(callback, self, decoded.body)
                if not ok then
                    log:warn(
                        'event handler error for '
                            .. decoded.event
                            .. ': '
                            .. tostring(cb_err)
                    )
                end
            end
            local after = listeners.after[callback_name]
            call_listener(after, self, decoded.body)
            if not callback and not next(before) and not next(after) then
                log:warn('No event handler for ', decoded)
            end
        end)
    elseif decoded.type == 'request' then
        local handler = self.handlers.reverse_requests[decoded.command]
        if handler then
            handler(self, decoded)
        else
            log:warn('No handler for reverse request', decoded)
        end
    else
        log:warn('Received unexpected message', decoded)
    end
end

---@param self dap.Session
---@param request dap.Request
local function start_debugging(self, request)
    local body = request.arguments --[[@as dap.StartDebuggingRequestArguments]]
    ---@async
    coroutine.wrap(function()
        local co = coroutine.running()
        local opts = {
            filetype = self.filetype,
        }
        local config = body.configuration
        local adapter = dap().adapters[config.type or self.config.type]
        config.request = body.request

        if type(adapter) == 'function' then
            adapter(coresume(co), config, self)
            adapter = coroutine.yield()
        end

        -- Prefer connecting to root server again if it is of type server and
        -- the new adapter would have an executable.
        -- Spawning a new executable is likely the wrong thing to do
        if self.adapter.type == 'server' and adapter.executable then
            adapter = vim.deepcopy(self.adapter)
            ---@diagnostic disable-next-line: inject-field
            adapter.executable = nil
        end

        local expected_types = { 'executable', 'server' }
        if type(adapter) ~= 'table' or not vim.tbl_contains(expected_types, adapter.type) then
            local msg = 'Invalid adapter definition. '
                .. 'Expected a table with type `executable` or `server`: '
            utils.notify(msg .. vim.inspect(adapter), vim.log.levels.ERROR)
            return
        end

        ---@param session dap.Session
        local function on_child_session(session)
            session.parent = self
            self.children[session.id] = session
            session.on_close['dap.session.child'] = function(s)
                if s.parent then
                    s.parent.children[s.id] = nil
                    s.parent = nil
                end
            end
            session:initialize(config)
            self:response(request, { success = true })
        end

        if adapter.type == 'executable' then
            local session = Session.spawn(adapter, config, opts)
            if session then
                on_child_session(session)
            end
        elseif adapter.type == 'server' then
            local session
            session = Session.connect(adapter, config, opts, function(err)
                if err then
                    utils.notify(
                        string.format(
                            'Could not connect startDebugging child session %s:%s: %s',
                            adapter.host or '127.0.0.1',
                            adapter.port,
                            err
                        ),
                        vim.log.levels.WARN
                    )
                elseif session then
                    on_child_session(session)
                end
            end)
        end
    end)()
end

local default_reverse_request_handlers = {
    runInTerminal = run_in_terminal,
    startDebugging = start_debugging,
}

local next_session_id = 1

---@param adapter dap.Adapter
---@param config dap.Configuration
---@param opts table
---@param handle uv.uv_stream_t
---@return dap.Session
local function new_session(adapter, config, opts, handle)
    local handlers = {}
    handlers.after = opts.after
    handlers.reverse_requests =
        vim.tbl_extend(
            'error',
            default_reverse_request_handlers,
            adapter.reverse_request_handlers or {}
        )
    local ns = ns_pool.acquire()
    local state = {
        id = next_session_id,
        handlers = handlers,
        message_callbacks = {},
        message_requests = {},
        message_timers = {},
        generation = 0,
        initialized = false,
        seq = 1,
        stopped_thread_id = nil,
        current_frame = nil,
        threads = {},
        adapter = vim.deepcopy(adapter),
        dirty = {},
        capabilities = {},
        filetype = opts.filetype or vim.bo.filetype,
        ns = ns,
        sign_group = 'dap-' .. tostring(ns),
        closed = false,
        on_close = {},
        children = {},
        handle = handle,
        client = {},
        config = config,
    }
    function state.client.write(line)
        state.handle:write(line)
    end

    function state.client.close(cb)
        cb = cb or function() end
        if state.handle:is_closing() then
            cb()
            return
        end
        state.handle:shutdown(function()
            state.handle:close()
            state.closed = true
            cb()
        end)
    end
    next_session_id = next_session_id + 1
    return setmetatable(state, session_mt)
end

-- Probes the OS for a free port by binding port 0, then releases it.
-- Known TOCTOU: the port is free when probed but the adapter binds it
-- later, so another process could win the race in between. Accepted: DAP
-- server adapters have no better rendezvous, and a connect failure
-- surfaces immediately through the retry loop in `connect_with_retry`.
---@return integer
local function get_free_port()
    local tcp = assert(uv.new_tcp(), 'Must be able to create tcp client')
    tcp:bind('127.0.0.1', 0)
    local port = tcp:getsockname().port
    tcp:shutdown()
    tcp:close()
    return port
end

---@param code integer
---@param command string
---@param adapter_name string
---@return string
local function get_badexit_msg(code, command, adapter_name)
    return string.format(
        'command `%s` of adapter `%s` exited with %d. Run :DapShowLog to open logs',
        command,
        adapter_name,
        code
    )
end

---@param err string
---@param command string
---@param adapter_name string
---@return string
local function get_spawn_errmsg(err, command, adapter_name)
    if vim.startswith(err, 'ENOENT') then
        return string.format(
            'Executable `%s` not found, fix the adapter definition for `%s` (%s)',
            command,
            adapter_name,
            err
        )
    elseif command == '' then
        return string.format('`command` of adapter `%s` must not be empty', adapter_name)
    else
        return string.format('Error running `%s` of `%s`: ', command, adapter_name, err)
    end
end

--- Spawn the executable or raise an error if the command doesn't start.
---
--- Adds a on_close hook on the session to terminate the executable once the
--- session closes.
---
---@param executable dap.ServerAdapterExecutable
---@param session dap.Session
local function spawn_server_executable(executable, session)
    local cmd = assert(
        executable.command,
        'executable of server adapter must have a `command` property'
    )
    log:debug('Starting debug adapter server executable', executable)
    local stdout = assert(uv.new_pipe(false), 'Must be able to create pipe')
    local stderr = assert(uv.new_pipe(false), 'Must be able to create pipe')
    local opts = {
        stdio = { nil, stdout, stderr },
        args = executable.args or {},
        detached = utils.if_nil(executable.detached, true),
        cwd = executable.cwd,
        hide = true,
    }
    local handle, pid_or_err
    local daplog = require('dap.log')
    local stdoutlog = daplog.create_logger('dap-' .. session.config.type .. '-stdout.log')
        or daplog.null_logger()
    local stderrlog = daplog.create_logger('dap-' .. session.config.type .. '-stderr.log')
        or daplog.null_logger()
    handle, pid_or_err = uv.spawn(cmd, opts, function(code)
        log:info('Process exit', cmd, code, pid_or_err)
        if handle then
            handle:close()
        end
        if code == 0 then
            stdoutlog:remove()
            stderrlog:remove()
        else
            stdoutlog:close()
            stderrlog:close()
            utils.notify(get_badexit_msg(code, cmd, session.config.type), vim.log.levels.WARN)
        end
    end)
    if not handle then
        stdout:close()
        stderr:close()
        utils.notify(
            get_spawn_errmsg(tostring(pid_or_err), cmd, session.config.type),
            vim.log.levels.ERROR
        )
        stdoutlog:remove()
        stderrlog:remove()
        return
    end
    local read_output = function(logger, pipe)
        return function(err, chunk)
            assert(not err, err)
            if chunk then
                logger:write(chunk)
            else
                pipe:close()
            end
        end
    end
    stderr:read_start(read_output(stderrlog, stderr))
    stdout:read_start(read_output(stdoutlog, stdout))

    local is_windows = vim.fn.has('win32')
    session.on_close['dap.server_executable'] = function()
        if not handle:is_closing() then
            if is_windows == 1 then
                handle:kill('sighup')
            else
                handle:kill('sigterm')
            end
        end
    end
end

---@param adapter dap.PipeAdapter
---@param opts? table
---@param config dap.Configuration
---@param on_connect fun(err?: string)
---@return dap.Session
---@param pipe uv.uv_pipe_t
---@param adapter dap.PipeAdapter
---@param session dap.Session
---@param on_connect fun(err?: string)
local function start_pipe_read_loop(pipe, adapter, session, on_connect)
    pipe:connect(adapter.pipe, function(err)
        if err then
            local msg = string.format("Couldn't connect to pipe %s: %s", adapter.pipe, err)
            utils.notify(msg, vim.log.levels.ERROR)
            session:close()
        else
            progress.report('Connected to ' .. adapter.pipe)
            local handle_body = vim.schedule_wrap(function(body)
                session:handle_body(body)
            end)
            pipe:read_start(rpc.create_read_loop(handle_body, function()
                if not session.closed then
                    session:close()
                    utils.notify('Debug adapter disconnected', vim.log.levels.INFO)
                end
            end, framing_error_handler(session)))
        end
        on_connect(err)
    end)
end

--- Wait for a spawned adapter to create its pipe, then connect.
---
--- Polls with a uv timer instead of blocking the editor with `vim.wait`,
--- so Neovim stays responsive while the adapter starts up. An explicit
--- timeout of 0 means "try once immediately, don't wait".
---@param pipe uv.uv_pipe_t
---@param adapter dap.PipeAdapter
---@param session dap.Session
---@param timeout_ms integer
---@param on_connect fun(err?: string)
local function connect_pipe_when_ready(pipe, adapter, session, timeout_ms, on_connect)
    local start = uv.hrtime()
    local timer = assert(uv.new_timer(), 'Must be able to create timer')
    -- The session owns this timer: if the session closes before the pipe
    -- appears, stop polling instead of lingering until the timeout fires.
    -- `done` clears the hook once the timer finishes so a later close does
    -- not stop an already-closed handle.
    local function done()
        stop_timer(timer)
        session.on_close['dap.pipe_readiness'] = nil
    end
    session.on_close['dap.pipe_readiness'] = function()
        stop_timer(timer)
    end
    timer:start(0, PIPE_POLL_INTERVAL_MS, function()
        if session.closed then
            done()
            return
        end
        if uv.fs_stat(adapter.pipe) ~= nil then
            done()
            start_pipe_read_loop(pipe, adapter, session, on_connect)
        elseif (uv.hrtime() - start) / 1e6 >= timeout_ms then
            done()
            local msg = string.format(
                'Timed out after %dms waiting for debug adapter to create pipe %s',
                timeout_ms,
                adapter.pipe
            )
            utils.notify(msg, vim.log.levels.ERROR)
            session:close()
            on_connect(msg)
        end
    end)
end

function Session.pipe(adapter, config, opts, on_connect)
    local pipe = assert(uv.new_pipe(), 'Must be able to create pipe')
    local session = new_session(adapter, config, opts or {}, pipe)

    local session_adapter = session.adapter
    ---@cast session_adapter dap.PipeAdapter
    adapter = session_adapter

    if adapter.executable then
        if adapter.pipe == '${pipe}' then
            -- Known TOCTOU: os.tmpname() reserves the name, but the file is
            -- removed before the adapter binds it, so another process could
            -- claim the path in between. Accepted: the window is tiny, the
            -- name is unpredictable, and DAP offers no better rendezvous.
            local filepath = os.tmpname()
            os.remove(filepath)
            session.on_close['dap.server_executable_pipe'] = function()
                os.remove(filepath)
            end
            adapter.pipe = filepath
            if adapter.executable.args then
                local args = assert(adapter.executable.args)
                for idx, arg in pairs(args) do
                    args[idx] = arg:gsub('${pipe}', filepath)
                end
            end
        end
        spawn_server_executable(adapter.executable, session)
        log:debug('Debug adapter server executable started with pipe ' .. adapter.pipe)
        -- The adapter should create the pipe; poll for it with a timer
        -- instead of blocking the editor with vim.wait.
        local adapter_opts = adapter.options or {}
        local timeout_ms =
            bounded_number(adapter_opts.timeout, PIPE_TIMEOUT_DEFAULT_MS, PIPE_TIMEOUT_MAX_MS)
        connect_pipe_when_ready(pipe, adapter, session, timeout_ms, on_connect)
    else
        start_pipe_read_loop(pipe, adapter, session, on_connect)
    end
    return session
end

--- Connect to a DAP server adapter with retries.
---
--- `client` is replaced (not reused) on retry: reusing a failed TCP handle
--- for a second `connect` gets stuck on some luv versions, so a fresh
--- handle is created and `session.handle` is pointed at it.
---@param client uv.uv_tcp_t
---@param session dap.Session
---@param adapter dap.ServerAdapter
---@param host string
---@param max_retries integer
---@param on_connect fun(err?: string)
local function connect_with_retry(client, session, adapter, host, max_retries, on_connect)
    local on_addresses
    on_addresses = function(err, addresses, retry_count)
        if err or #addresses == 0 then
            err = err or ('Could not resolve ' .. host)
            session:close()
            on_connect(err)
            return
        end
        local address = addresses[1]
        local port = assert(tonumber(adapter.port), 'adapter.port is required for server adapter')
        client:connect(address.addr, port, function(conn_err)
            if conn_err then
                retry_count = retry_count or 1
                if retry_count < max_retries then
                    -- Possible luv bug? A second client:connect gets stuck
                    -- Create new handle as workaround
                    client:close()
                    client = assert(uv.new_tcp(), 'Must be able to create TCP client')
                    ---@diagnostic disable-next-line: invisible
                    session.handle = client
                    local timer = assert(uv.new_timer(), 'Must be able to create timer')
                    timer:start(250, 0, function()
                        stop_timer(timer)
                        on_addresses(nil, addresses, retry_count + 1)
                    end)
                else
                    session:close()
                    on_connect(conn_err)
                end
                return
            end
            local handle_body = vim.schedule_wrap(function(body)
                session:handle_body(body)
            end)
            client:read_start(rpc.create_read_loop(handle_body, function()
                if not session.closed then
                    session:close()
                    utils.notify('Debug adapter disconnected', vim.log.levels.INFO)
                end
            end, framing_error_handler(session)))
            on_connect(nil)
        end)
    end
    -- getaddrinfo fails for some users with
    -- `bad argument #3 to 'getaddrinfo' (Invalid protocol hint)`
    -- It should generally work with luv 1.42.0 but some still get errors
    if uv.version() >= 76288 then
        ---@diagnostic disable-next-line: missing-fields
        local ok, err = pcall(uv.getaddrinfo, host, nil, { protocol = 'tcp' }, on_addresses)
        if not ok then
            log:warn(err)
            on_addresses(nil, { { addr = host } })
        end
    else
        on_addresses(nil, { { addr = host } })
    end
end

---@param adapter dap.ServerAdapter
---@param config dap.Configuration
---@param opts? table
---@param on_connect fun(err?: string)
---@return dap.Session
function Session.connect(adapter, config, opts, on_connect)
    local client = assert(uv.new_tcp(), 'Must be able to create TCP client')
    local session = new_session(adapter, config, opts or {}, client)

    local session_adapter = session.adapter
    ---@cast session_adapter dap.ServerAdapter
    adapter = session_adapter

    if adapter.executable then
        if adapter.port == '${port}' then
            local port = get_free_port()
            session.adapter = adapter
            adapter.port = port
            if adapter.executable.args then
                local args = assert(adapter.executable.args)
                for idx, arg in pairs(args) do
                    args[idx] = arg:gsub('${port}', tostring(port))
                end
            end
        end
        spawn_server_executable(adapter.executable, session)
        log:debug('Debug adapter server executable started, listening on ' .. adapter.port)
    end

    log:debug('Connecting to debug adapter', adapter)
    local max_retries =
        bounded_number(
            (adapter.options or {}).max_retries,
            CONNECT_RETRIES_DEFAULT,
            CONNECT_RETRIES_MAX
        )

    local host = adapter.host or '127.0.0.1'
    connect_with_retry(client, session, adapter, host, max_retries, on_connect)
    return session
end

---@class dap.session.SpawnCtl process state for a spawned debug adapter
---@field handle uv.uv_process_t? process handle; nil once reaped
---@field stdin uv.uv_pipe_t
---@field closed boolean teardown already ran

--- SIGINT-then-SIGKILL escalation for a spawned debug adapter.
---
--- Sends SIGINT, then SIGKILL after `SIGKILL_ESCALATION_NS` if the process
--- is still alive. `ctl.handle` is nilled once the process is gone; `cb`
--- always runs exactly once.
---@param ctl dap.session.SpawnCtl
---@param cb fun()
local function spawn_kill(ctl, cb)
    local handle = ctl.handle
    if not handle or handle:is_closing() then
        cb()
        return
    end
    handle:kill('sigint')
    local timer = assert(uv.new_timer(), 'Must be able to create timer')
    local start = uv.hrtime()
    timer:start(0, 50, function()
        if handle:is_closing() then
            stop_timer(timer)
            ctl.handle = nil
            cb()
        elseif (uv.hrtime() - start) > SIGKILL_ESCALATION_NS then
            handle:kill('sigkill')
            stop_timer(timer)
            ctl.handle = nil
            cb()
        end
    end)
end

--- Idempotent teardown for a spawned adapter: closes stdin, then escalates
--- to SIGINT/SIGKILL. Safe to call multiple times; `cb` runs at most once.
---@param ctl dap.session.SpawnCtl
---@param cb? fun()
local function spawn_close(ctl, cb)
    cb = cb or function() end
    if ctl.closed then
        -- Already closed: nothing to tear down, but the caller is still
        -- owed its callback (e.g. Session:close clears state in it).
        cb()
        return
    end
    ctl.closed = true
    if ctl.stdin:is_closing() then
        spawn_kill(ctl, cb)
    else
        ctl.stdin:close(function()
            spawn_kill(ctl, cb)
        end)
    end
end

---@param adapter dap.ExecutableAdapter
---@param config dap.Configuration
---@param opts table|nil
---@return dap.Session?
function Session.spawn(adapter, config, opts)
    log:debug('Spawning debug adapter', adapter)

    local pid_or_err
    ---@type dap.session.SpawnCtl
    local ctl = {
        handle = nil,
        stdin = assert(uv.new_pipe(false), 'Must be able to create pipe'),
        closed = false,
    }
    local stdout = assert(uv.new_pipe(false), 'Must be able to create pipe')
    local stderr = assert(uv.new_pipe(false), 'Must be able to create pipe')

    local options = adapter.options or {}
    local spawn_opts = {
        args = adapter.args,
        stdio = { ctl.stdin, stdout, stderr },
        cwd = options.cwd,
        env = options.env,
        detached = utils.if_nil(options.detached, true),
        hide = true,
    }
    local session
    local daplog = require('dap.log')
    local stderrlog = daplog.create_logger('dap-' .. config.type .. '-stderr.log')
        or daplog.null_logger()
    ctl.handle, pid_or_err = uv.spawn(adapter.command, spawn_opts, function(code)
        log:info('Process exit', adapter.command, code, pid_or_err)
        spawn_close(ctl)
        if code == 0 then
            stderrlog:remove()
        else
            stderrlog:close()
            utils.notify(get_badexit_msg(code, adapter.command, config.type), vim.log.levels.WARN)
        end
        if session and not session.closed then
            session:close()
        end
    end)
    if not ctl.handle then
        ctl.stdin:close()
        stdout:close()
        stderr:close()
        spawn_close(ctl)
        stderrlog:remove()
        local msg = get_spawn_errmsg(tostring(pid_or_err), adapter.command, config.type)
        vim.notify(msg, vim.log.levels.ERROR)
        return
    end
    session = new_session(adapter, config, opts or {}, ctl.stdin)
    session.client.close = function(cb)
        spawn_close(ctl, cb)
    end

    local function on_body(body)
        session:handle_body(body)
    end
    local function on_eof()
        stdout:close()
    end
    stdout:read_start(
        rpc.create_read_loop(vim.schedule_wrap(on_body), on_eof, framing_error_handler(session))
    )
    stderr:read_start(function(err, chunk)
        assert(not err, err)
        if chunk then
            stderrlog:write(chunk)
        else
            stderr:close()
        end
    end)
    return session
end

---@param session dap.Session
---@param thread_id integer
---@param cb? fun(err: dap.ErrorResponse?, thread_id: integer?)
local function pause_thread(session, thread_id, cb)
    assert(session, 'Cannot pause thread without active session')
    assert(thread_id, 'thread_id is required to pause thread')

    session:request('pause', { threadId = thread_id }, function(err)
        if err then
            utils.notify('Error pausing: ' .. tostring(err), vim.log.levels.ERROR)
        else
            local thread = session.threads[thread_id]
            if thread then
                thread.stopped = true
            end
        end
        if cb then
            cb(err, thread_id)
        end
    end)
end

---@param thread_id? integer
---@param cb? fun(err: dap.ErrorResponse?, thread_id: integer)
function Session:_pause(thread_id, cb)
    if thread_id then
        pause_thread(self, thread_id, cb)
        return
    end
    if self.dirty.threads then
        self:update_threads(function(err)
            if err then
                utils.notify('Error requesting threads: ' .. tostring(err), vim.log.levels.ERROR)
                return
            end
            self:_pause(nil, cb)
        end)
        return
    end
    ui().pick_if_many(vim.tbl_values(self.threads), 'Which thread?: ', function(t)
        return t.name
    end, function(thread)
        if not thread or not thread.id then
            utils.notify('No thread to stop. Not pausing...', vim.log.levels.INFO)
        else
            pause_thread(self, thread.id, cb)
        end
    end)
end

function Session:restart_frame()
    if not self.capabilities.supportsRestartFrame then
        utils.notify('Debug Adapter does not support restart frame', vim.log.levels.INFO)
        return
    end
    local frame = self.current_frame
    if not frame then
        local msg = 'Current frame not set. '
            .. 'Debug adapter needs to be stopped at breakpoint to use restart frame'
        utils.notify(msg, vim.log.levels.INFO)
        return
    end
    coroutine.wrap(function()
        if frame.canRestart == false then
            local thread = self.threads[self.stopped_thread_id] or {}
            local frames = vim.tbl_filter(function(f)
                return f.canRestart == nil or f.canRestart == true
            end, thread.frames or {})
            if not next(frames) then
                utils.notify('No frame available that can be restarted', vim.log.levels.WARN)
                return
            end
            frame = ui().pick_one(
                frames,
                "Can't restart current frame, pick another frame to restart: ",
                require('dap.entity').frames.render_item
            )
            if not frame then
                return
            end
        end
        clear_running(self)
        local err = self:request('restartFrame', { frameId = frame.id })
        if err then
            utils.notify('Error on restart_frame: ' .. tostring(err), vim.log.levels.ERROR)
        end
    end)()
end

---@param step "next"|"stepIn"|"stepOut"|"stepBack"|"continue"|"reverseContinue"
---@param params table|nil
function Session:_step(step, params)
    local count = vim.v.count1 - 1
    local function step_thread(thread_id)
        if count > 0 then
            local listeners = dap().listeners
            local clear_listeners = function()
                listeners.after.event_stopped['dap.step'] = nil
                listeners.after.event_terminated['dap.step'] = nil
                listeners.after.disconnect['dap.step'] = nil
            end
            listeners.after.event_stopped['dap.step'] = function()
                if count > 0 then
                    count = count - 1
                    step_thread(thread_id)
                else
                    clear_listeners()
                end
            end
            listeners.after.event_terminated['dap.step'] = clear_listeners
            listeners.after.disconnect['dap.step'] = clear_listeners
        end
        params = params or {}
        params.threadId = thread_id
        if not params.granularity then
            params.granularity = dap().defaults[self.config.type].stepping_granularity
        end
        clear_running(self, thread_id)
        self:request(step, params, function(err)
            if err then
                utils.notify('Error on ' .. step .. ': ' .. tostring(err), vim.log.levels.ERROR)
            end
            progress.report('Running')
        end)
    end

    if self.stopped_thread_id then
        step_thread(self.stopped_thread_id)
    else
        local paused_threads = vim.tbl_filter(function(t)
            return t.stopped
        end, vim.tbl_values(self.threads))
        if not next(paused_threads) then
            utils.notify('No stopped threads. Cannot move', vim.log.levels.ERROR)
            return
        end
        ui().pick_if_many(paused_threads, 'Select thread to step in> ', function(t)
            return t.name
        end, function(thread)
            if thread then
                step_thread(thread.id)
            end
        end)
    end
end

function Session:close()
    if self.closed then
        return
    end
    self.closed = true
    -- Invalidate the generation first: responses or events arriving after
    -- this point are stale and must not touch session state.
    self.generation = self.generation + 1
    -- Fail every pending request instead of leaving callbacks dangling or
    -- coroutines suspended forever. Delivery is scheduled so the owners get
    -- an error they can handle rather than silence.
    local closed_err = setmetatable({ message = 'session closed' }, err_mt)
    for seq, pending in pairs(self.message_callbacks) do
        self.message_callbacks[seq] = nil
        self.message_requests[seq] = nil
        stop_timer(self.message_timers[seq])
        self.message_timers[seq] = nil
        vim.schedule(function()
            local ok, cb_err = pcall(pending.callback, closed_err, nil)
            if not ok then
                log:warn(
                    'close: pending '
                        .. pending.command
                        .. ' callback failed: '
                        .. tostring(cb_err)
                )
            end
        end)
    end
    for _, on_close in pairs(self.on_close) do
        local ok, err = pcall(on_close, self)
        if not ok then
            log:warn(err)
        end
    end
    self.on_close = {}
    if self.handlers.after then
        local ok, err = pcall(self.handlers.after)
        if not ok then
            log:warn(err)
        end
        self.handlers.after = nil
    end
    vim.schedule(function()
        local ok, err = pcall(vim.fn.sign_unplace, self.sign_group)
        if not ok then
            log:debug('sign_unplace failed during close: ' .. tostring(err))
        end
        vim.diagnostic.reset(self.ns)
        ns_pool.release(self.ns)
    end)
    if log._file then
        log._file:write('\n')
        log._file:flush()
    end
    self.client.close(function()
        self.threads = {}
        self.message_callbacks = {}
        self.message_requests = {}
        self.message_timers = {}
    end)
end

--- Send a request with an explicit timeout, reusing Session:request's
--- timeout machinery instead of a second timer implementation.
---@param command string
---@param arguments any?
---@param timeout_ms integer
---@param callback fun(err: dap.ErrorResponse?, response: any?)?
--- `request` with a timeout, preserving the original contract: this never
--- yields, even when `callback` is nil. The internal wrapper owns delivery;
--- a missing user callback gets a timeout surfaced as an INFO notification,
--- exactly as before the request machinery grew its own timeout support.
---@param command string
---@param arguments any?
---@param timeout_ms integer
---@param callback fun(err: dap.ErrorResponse?, response: any?)?
function Session:request_with_timeout(command, arguments, timeout_ms, callback)
    local function cb(err, response)
        if callback then
            callback(err, response)
        elseif err and err.timed_out then
            utils.notify(err.message, vim.log.levels.INFO)
        end
    end
    self:request(command, arguments, cb, { timeout_ms = timeout_ms })
end

---@alias dap.EvalCb fun(err: dap.ErrorResponse?, result: dap.EvaluateResponse?)?
---@alias dap.VarsCb fun(err: dap.ErrorResponse?, result: dap.VariableResponse?)?
---@alias dap.ThreadCb fun(err: dap.ErrorResponse?, result: dap.ThreadResponse?)?
---@alias dap.StackCb fun(err: dap.ErrorResponse?, result: dap.StackTraceResponse?)?

--- Send a request to the debug adapter
---
---Dual-mode: yields and returns the response when called without a callback
---from a coroutine; otherwise delivers the response to `on_result`.
---
---Fail-fast: a request on a closed session invokes `on_result` immediately
---with an error (or returns the error in coroutine mode) instead of sending
---into the void. Every request carries the session generation captured at
---send time, and a bounded timeout (`opts.timeout_ms`, default 30s,
---0 disables); a hung adapter can no longer leak the pending request
---forever. Response callbacks run inside `pcall`; a throwing callback is
---logged, not fatal.
---@param command string command name
---@param arguments any? command arguments
---@param on_result fun(err: dap.ErrorResponse?, result: any)? response callback
---@param opts? {timeout_ms?: integer} request timeout; nil selects the default
---@return dap.ErrorResponse? err, any response # (if running in coroutine and on_response is empty)
---@overload fun(self: dap.Session, command: "evaluate", arguments: dap.EvaluateArguments,
--- on_result: dap.EvalCb)
---@overload fun(self: dap.Session, command: "variables", arguments: dap.VariablesArguments,
--- on_result: dap.VarsCb)
---@overload fun(self: dap.Session, command: "threads", arguments: nil, on_result: dap.ThreadCb)
---@overload fun(self: dap.Session, command: "stackTrace", arguments: dap.StackTraceArguments,
--- on_result: dap.StackCb)
function Session:request(command, arguments, on_result, opts)
    if self.closed then
        local err = setmetatable({ message = 'session is closed' }, err_mt)
        if on_result then
            on_result(err, nil)
            return nil
        end
        return err, nil
    end
    local timeout_ms =
        bounded_number(opts and opts.timeout_ms, REQUEST_TIMEOUT_DEFAULT_MS, REQUEST_TIMEOUT_MAX_MS)
    local payload = {
        seq = self.seq,
        type = 'request',
        command = command,
        arguments = arguments,
    }
    log:debug('request', payload)
    local current_seq = self.seq
    self.seq = self.seq + 1
    ---@type dap.session.PendingRequest
    local pending = {
        command = command,
        generation = self.generation,
        is_coroutine = false,
        callback = function(_, _) end,
    }
    local co, is_main
    if not on_result then
        co, is_main = coroutine.running()
        if co and not is_main then
            pending.is_coroutine = true
            pending.callback = coresume(co)
        end
        -- else: missing callback is intentional; the noop above prevents
        -- error logging in Session:handle_body
    else
        local user_cb = on_result
        pending.callback = function(err, response)
            local ok, cb_err = pcall(user_cb, err, response)
            if not ok then
                log:warn('request callback error for ' .. command .. ': ' .. tostring(cb_err))
            end
        end
    end
    self.message_callbacks[current_seq] = pending
    self.message_requests[current_seq] = arguments
    if timeout_ms > 0 then
        local timer = assert(uv.new_timer(), 'Must be able to create timer')
        self.message_timers[current_seq] = timer
        timer:start(timeout_ms, 0, function()
            stop_timer(timer)
            vim.schedule(function()
                local p = self.message_callbacks[current_seq]
                if not p then
                    return -- response already arrived
                end
                self.message_callbacks[current_seq] = nil
                self.message_requests[current_seq] = nil
                self.message_timers[current_seq] = nil
                local err = setmetatable({
                    message = 'Request `' .. command .. '` timed out after ' .. timeout_ms .. 'ms',
                    timed_out = true,
                }, err_mt)
                if self.generation ~= p.generation then
                    deliver_stale(p, err)
                    return
                end
                local ok, cb_err = pcall(p.callback, err, nil)
                if not ok then
                    log:warn(
                        'request timeout callback error for '
                            .. command
                            .. ': '
                            .. tostring(cb_err)
                    )
                end
            end)
        end)
    end
    local send_ok, send_err = pcall(send_payload, self.client, payload)
    if not send_ok then
        stop_timer(self.message_timers[current_seq])
        self.message_timers[current_seq] = nil
        self.message_callbacks[current_seq] = nil
        self.message_requests[current_seq] = nil
        local err = setmetatable({
            message = 'failed to send ' .. command .. ' request: ' .. tostring(send_err),
        }, err_mt)
        if co then
            return err, nil
        end
        pending.callback(err, nil)
        return nil
    end
    if co then
        -- Intentional await-in-sync: dual-mode (only yields when called inside
        -- a coroutine); marking it async would falsely taint sync callers.
        return coroutine.yield()
    end
end

function Session:response(request, payload)
    payload.seq = self.seq
    self.seq = self.seq + 1
    payload.type = 'response'
    payload.request_seq = request.seq
    payload.command = request.command
    log:debug('response', payload)
    send_payload(self.client, payload)
end

--- Initialize the debug session
---@param config dap.Configuration
function Session:initialize(config)
    vim.schedule(repl.clear)
    local adapter_responded = false
    -- Declared before `on_initialize` so the callback captures this upvalue;
    -- assigned below before the request is sent.
    local timer

    ---@param err0 dap.ErrorResponse?
    ---@param result dap.Capabilities?
    local function on_initialize(err0, result)
        adapter_responded = true
        stop_timer(timer)
        self.on_close['dap.initialize_watchdog'] = nil
        if err0 then
            utils.notify(
                'Could not initialize debug adapter: ' .. tostring(err0),
                vim.log.levels.ERROR
            )
            -- An adapter that rejects `initialize` can never become usable;
            -- close the half-open session instead of leaking it. This matches
            -- the launch/attach error path below.
            self:close()
            return
        end
        self.capabilities = vim.tbl_extend('force', self.capabilities, result or {})
        self:request(config.request, config, function(err)
            adapter_responded = true
            if err then
                utils.notify(
                    string.format('Error on %s: %s', config.request, err),
                    vim.log.levels.ERROR
                )
                self:close()
            end
        end)
    end
    local params = {
        clientID = 'neovim',
        clientName = 'neovim',
        adapterID = self.adapter.id or 'nvim-dap',
        pathFormat = 'path',
        columnsStartAt1 = true,
        linesStartAt1 = true,
        supportsRunInTerminalRequest = true,
        supportsVariableType = true,
        supportsProgressReporting = true,
        supportsStartDebuggingRequest = true,
        locale = os.getenv('LANG') or 'en_US',
    }
    -- The watchdog below owns the initialize timeout, so the request
    -- itself carries no default timeout (0 disables it). The watchdog is
    -- armed before the request is sent: on a closed session `request`
    -- fails fast and `on_initialize` runs synchronously, so the timer
    -- must already exist for it to stop.
    local adapter = self.adapter
    local sec_to_wait =
        bounded_number(
            (adapter.options or {}).initialize_timeout_sec,
            INITIALIZE_TIMEOUT_DEFAULT_SEC,
            INITIALIZE_TIMEOUT_MAX_SEC
        )
    timer = assert(uv.new_timer(), 'Must be able to create timer')
    -- The session owns the watchdog: if it closes before the adapter
    -- responds, the timer must not outlive the session it guards.
    self.on_close['dap.initialize_watchdog'] = function()
        stop_timer(timer)
    end
    timer:start(sec_to_wait * sec_to_ms, 0, function()
        stop_timer(timer)
        if not adapter_responded and not self.closed then
            -- A half-open session is worse than none: without this the
            -- session lingers with no capabilities and no way to recover.
            self:close()
            vim.schedule(function()
                utils.notify(
                    string.format(
                        (
                            "Debug adapter didn't respond to `initialize` within %ds; "
                            .. 'the session was closed. Either the adapter is too slow '
                            .. 'or there is a problem with your adapter or `%s` '
                            .. 'configuration. Check the logs for errors (:help dap.set_log_level)'
                        ),
                        sec_to_wait,
                        config.type
                    ),
                    vim.log.levels.ERROR
                )
            end)
        end
    end)
    self:request('initialize', params, on_initialize, { timeout_ms = 0 })
end

---@param args string|dap.EvaluateArguments expression as string, or evaluate arguments
---@param fn fun(err?: dap.ErrorResponse, result?: dap.EvaluateResponse)
---@return dap.ErrorResponse?, any
function Session:evaluate(args, fn)
    if type(args) == 'string' then
        args = {
            expression = args,
            context = 'repl',
        }
    end
    args.frameId = args.frameId or (self.current_frame or {}).id
    return self:request('evaluate', args, fn)
end

function Session:disconnect(opts, cb)
    opts = vim.tbl_extend('force', {
        restart = false,
        terminateDebuggee = nil,
    }, opts or {})
    local disconnect_timeout_sec =
        bounded_number(
            (self.adapter.options or {}).disconnect_timeout_sec,
            DISCONNECT_TIMEOUT_DEFAULT_SEC,
            DISCONNECT_TIMEOUT_MAX_SEC
        )
    local disconnect_timeout_ms = disconnect_timeout_sec * sec_to_ms
    self:request_with_timeout('disconnect', opts, disconnect_timeout_ms, function(err, resp)
        self:close()
        log:info('Session closed due to disconnect')
        if cb then
            cb(err, resp)
        end
    end)
end

---@param frame? dap.StackFrame
function Session:_frame_set(frame)
    if not frame then
        return
    end
    self.current_frame = frame
    coroutine.wrap(function()
        local jumped = jump_to_frame(self, frame, false)
        if jumped then
            progress.report(
                string.format('Set frame: %s:%s:%s', frame.name, frame.line, frame.column)
            )
        end
        self:_request_scopes(frame)
    end)()
end

function Session:_frame_delta(delta)
    if not self.stopped_thread_id then
        utils.notify('Cannot move frame if not stopped', vim.log.levels.ERROR)
        return
    end
    local frames = self.threads[self.stopped_thread_id].frames
    assert(frames, 'Stopped thread must have frames')
    local frameidx = index_of(frames, function(i)
        return i.id == self.current_frame.id
    end)
    assert(frameidx, 'id of current frame must be present in frames')

    frameidx = frameidx + delta
    if frameidx < 1 then
        frameidx = 1
        utils.notify("Can't move past first frame", vim.log.levels.INFO)
    elseif frameidx > #frames then
        frameidx = #frames
        utils.notify("Can't move past last frame", vim.log.levels.INFO)
    end
    self:_frame_set(frames[frameidx])
end

function Session.event_exited() end

function Session.event_module() end

function Session.event_process() end

function Session.event_loadedSource() end

---@param event dap.ThreadEvent
function Session:event_thread(event)
    if event.reason == 'exited' then
        self.threads[event.threadId] = nil
    else
        local thread = self.threads[event.threadId]
        if thread then
            thread.stopped = false
            if self.stopped_thread_id == thread.id then
                self.stopped_thread_id = nil
                self.current_frame = nil
            end
        else
            self.dirty.threads = true
            self.threads[event.threadId] = {
                id = event.threadId,
                name = 'Unknown',
            }
        end
    end
end

---@param event dap.ContinuedEvent
function Session:event_continued(event)
    if event.allThreadsContinued == nil or event.allThreadsContinued == true then
        for _, t in pairs(self.threads) do
            t.stopped = false
        end
        self.stopped_thread_id = nil
        self.current_frame = nil
        vim.fn.sign_unplace(self.sign_group)
    else
        if self.stopped_thread_id == event.threadId then
            self.stopped_thread_id = nil
            self.current_frame = nil
            vim.fn.sign_unplace(self.sign_group)
        end
        local thread = self.threads[event.threadId]
        if thread and thread.stopped then
            thread.stopped = false
        end
    end
end

---@param session dap.Session
---@param event dap.BreakpointEvent
function Session.event_breakpoint(session, event)
    if event.reason == 'changed' then
        local bp = event.breakpoint
        if bp.id then
            breakpoints.update(bp)
        end
    elseif event.reason == 'new' then
        local bp = event.breakpoint
        if bp.id then
            local bufnr = source_to_bufnr(session, bp.source)
            if bufnr then
                breakpoints.set({}, bufnr, bp.line)
                breakpoints.set_state(bufnr, bp)
            end
        end
    elseif event.reason == 'removed' then
        local bp = event.breakpoint
        if bp.id then
            breakpoints.remove_by_id(bp.id)
        end
    end
end

function Session:event_capabilities(body)
    self.capabilities = vim.tbl_extend('force', self.capabilities, body.capabilities)
end

---@param body dap.ProgressStartEvent
function Session.event_progressStart(_, body)
    if body.message then
        progress.report(body.title .. ': ' .. body.message)
    else
        progress.report(body.title)
    end
end

---@param body dap.ProgressUpdateEvent
function Session.event_progressUpdate(_, body)
    if body.message then
        progress.report(body.message)
    end
end

---@param body dap.ProgressEndEvent
function Session:event_progressEnd(body)
    if body.message then
        progress.report(body.message)
    else
        progress.report('Running: ' .. (self.config.name or '[No Name]'))
    end
end

return Session
