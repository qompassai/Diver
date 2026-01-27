-- /qompassai/Diver/lua/utils/media/rpc.lua
-- Qompass AI Media RPC Util
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local uv = vim.uv
local mpack = vim.mpack
local StdioStream = {} ---@class media.rpc.StdioStream : media.rpc.Stream
StdioStream.__index = StdioStream
function StdioStream.open()
    local self = setmetatable({
        _in = assert(uv.new_pipe(false)),
        _out = assert(uv.new_pipe(false)),
    }, StdioStream)
    self._in:open(0)
    self._out:open(1)
    return self
end

function StdioStream:write(data)
    self._out:write(data)
end

function StdioStream:read_start(cb)
    self._in:read_start(function(err, chunk)
        if err then
            error(err)
        end
        cb(chunk)
    end)
end

function StdioStream:read_stop()
    self._in:read_stop()
end

function StdioStream:close()
    self._in:close()
    self._out:close()
end

local SocketStream = {} ---@class media.rpc.SocketStream : media.rpc.Stream
SocketStream.__index = SocketStream
function SocketStream.open(file)
    local socket = assert(uv.new_pipe(false))
    local self = setmetatable({
        _socket = socket,
        _stream_error = nil,
    }, SocketStream)
    uv.pipe_connect(socket, file, function(err)
        self._stream_error = self._stream_error or err
    end)
    return self
end

function SocketStream.connect(host, port)
    local socket = assert(uv.new_tcp())
    local self = setmetatable({
        _socket = socket,
        _stream_error = nil,
    }, SocketStream)
    uv.tcp_connect(socket, host, port, function(err)
        self._stream_error = self._stream_error or err
    end)
    return self
end

function SocketStream:write(data)
    if self._stream_error then
        error(self._stream_error)
    end
    uv.write(self._socket, data, function(err)
        if err then
            error(self._stream_error or err)
        end
    end)
end

function SocketStream:read_start(cb)
    if self._stream_error then
        error(self._stream_error)
    end
    uv.read_start(self._socket, function(err, chunk)
        if err then
            error(err)
        end
        cb(chunk)
    end)
end

function SocketStream:read_stop()
    if self._stream_error then
        error(self._stream_error)
    end
    uv.read_stop(self._socket)
end

function SocketStream:close()
    uv.close(self._socket)
end

local ProcStream = {} ---@class media.rpc.ProcStream : media.rpc.Stream
ProcStream.__index = ProcStream
function ProcStream.spawn(argv, env, io_extra, on_exit)
    local self = setmetatable({
        collect_text = false,
        output = function(self_)
            if not self_.collect_text then
                error('set collect_text=true')
            end
            return (self_.stderr .. self_.stdout):gsub('\r\n', '\n')
        end,
        stdout = '',
        stderr = '',
        stdout_eof = false,
        stderr_eof = false,
        _child_stdin = assert(uv.new_pipe(false)),
        _child_stdout = assert(uv.new_pipe(false)),
        _child_stderr = assert(uv.new_pipe(false)),
        _exiting = false,
        _on_exit = on_exit,
    }, ProcStream)
    local prog = argv[1]
    local args = {}
    for i = 2, #argv do
        args[#args + 1] = argv[i]
    end
    --- @diagnostic disable-next-line: missing-fields
    self._proc, self._pid = uv.spawn(prog, {
        stdio = { self._child_stdin, self._child_stdout, self._child_stderr, io_extra },
        args = args,
        --- @diagnostic disable-next-line: assign-type-mismatch
        env = env,
    }, function(status, signal)
        self.signal = signal
        self.status = (0 ~= (status or 0) or 0 == (signal or 0)) and status or (128 + (signal or 0))
        if self._on_exit then
            self._on_exit(self._closed)
        end
    end)
    if not self._proc then
        local err = self._pid
        error(err)
    end
    return self
end

function ProcStream:write(data)
    self._child_stdin:write(data)
end

function ProcStream:on_read(stream, cb, err, chunk)
    if err then
        error(err)
    elseif chunk then
        if stream == 'stderr' then
            self.stderr = self.stderr .. chunk
        elseif stream == 'stdout' and self.collect_text then
            self.stdout = (self.stdout .. chunk):gsub('\r\n', '\n')
        end
    else
        self[stream .. '_eof'] = true
    end
    if cb then
        cb(chunk)
    end
end

function ProcStream:wait()
    while not (self.stdout_eof and self.stderr_eof and (self.status or self.signal)) do
        uv.run('once')
    end
end

function ProcStream:read_start(on_stdout, on_stderr)
    self._child_stdout:read_start(function(err, chunk)
        self:on_read('stdout', on_stdout, err, chunk)
    end)
    self._child_stderr:read_start(function(err, chunk)
        self:on_read('stderr', on_stderr, err, chunk)
    end)
end

function ProcStream:read_stop()
    self._child_stdout:read_stop()
    self._child_stderr:read_stop()
end

function ProcStream:close(signal, noblock)
    if self._closed then
        return
    end
    self._closed = uv.now()
    self:read_stop()
    self._child_stdin:close()
    self._child_stdout:close()
    self._child_stderr:close()
    if type(signal) == 'string' then
        self._proc:kill('sig' .. signal)
    end
    if not noblock then
        while self.status == nil do
            uv.run('once')
        end
        return self.status, self.signal
    end
end

local Response = {} ---@class media.rpc.Response
Response.__index = Response
function Response.new(rpc_stream, request_id)
    return setmetatable({
        _rpc_stream = rpc_stream,
        _request_id = request_id,
    }, Response)
end

function Response:send(value, is_error)
    local data = self._rpc_stream._session:reply(self._request_id)
    if is_error then
        data = data .. self._rpc_stream._pack(value)
        data = data .. self._rpc_stream._pack(mpack.NIL)
    else
        data = data .. self._rpc_stream._pack(mpack.NIL)
        data = data .. self._rpc_stream._pack(value)
    end
    self._rpc_stream._stream:write(data)
end

local RpcStream = {} ---@class media.rpc.RpcStream
RpcStream.__index = RpcStream
function RpcStream.new(stream)
    return setmetatable({
        _stream = stream,
        _pack = mpack.Packer(),
        _session = mpack.Session({
            unpack = mpack.Unpacker({
                ext = {
                    [0] = function(_c, s)
                        return mpack.decode(s)
                    end,
                    [1] = function(_c, s)
                        return mpack.decode(s)
                    end,
                    [2] = function(_c, s)
                        return mpack.decode(s)
                    end,
                },
            }),
        }),
    }, RpcStream)
end

function RpcStream:write(method, args, response_cb)
    local data
    if response_cb then
        assert(type(response_cb) == 'function')
        data = self._session:request(response_cb)
    else
        data = self._session:notify()
    end
    data = data .. self._pack(method) .. self._pack(args)
    self._stream:write(data)
end

function RpcStream:read_start(on_request, on_notification, on_eof)
    self._stream:read_start(function(data)
        if not data then
            on_eof()
            return
        end
        local type_, id_or_cb, method_or_error, args_or_result
        local pos = 1
        local len = #data
        while pos <= len do
            type_, id_or_cb, method_or_error, args_or_result, pos = self._session:receive(data, pos)
            if type_ == 'request' then
                on_request(method_or_error, args_or_result, Response.new(self, id_or_cb))
            elseif type_ == 'notification' then
                on_notification(method_or_error, args_or_result)
            elseif type_ == 'response' then
                if method_or_error == mpack.NIL then
                    method_or_error = nil
                else
                    args_or_result = nil
                end
                id_or_cb(method_or_error, args_or_result)
            end
        end
    end)
end

function RpcStream:read_stop()
    self._stream:read_stop()
end

function RpcStream:close(signal, noblock)
    self._stream:close(signal, noblock)
end

local Session = {} ---@class media.rpc.Session
Session.__index = Session

if package.loaded['jit'] then
    Session.safe_pcall = pcall
else
    Session.safe_pcall = require('coxpcall').pcall
end
local function resume_co(co, ...)
    local status, result = coroutine.resume(co, ...)
    if coroutine.status(co) == 'dead' then
        if not status then
            error(result)
        end
        return
    end
    assert(coroutine.status(co) == 'suspended')
    result(co)
end
local function coroutine_exec(func, ...)
    local args = { ... }
    local on_complete
    if #args > 0 and type(args[#args]) == 'function' then
        on_complete = table.remove(args)
    end
    resume_co(coroutine.create(function()
        local status, result, flag = Session.safe_pcall(func, unpack(args))
        if on_complete then
            coroutine.yield(function()
                on_complete(status, result, flag)
            end)
        end
    end))
end
function Session.new(stream)
    return setmetatable({
        _rpc_stream = RpcStream.new(stream),
        _pending_messages = {},
        _prepare = uv.new_prepare(),
        _timer = uv.new_timer(),
        _is_running = false,
        closed = false,
    }, Session)
end

function Session:next_message(timeout)
    local on_request = function(method, args, response)
        table.insert(self._pending_messages, {
            'request',
            method,
            args,
            response,
        })
        uv.stop()
    end
    local on_notification = function(method, args)
        table.insert(self._pending_messages, {
            'notification',
            method,
            args,
        })
        uv.stop()
    end
    if self._is_running then
        error('Event loop already running')
    end
    if #self._pending_messages > 0 then
        return table.remove(self._pending_messages, 1)
    end
    if self.closed then
        return nil
    end
    self:_run(on_request, on_notification, timeout)
    return table.remove(self._pending_messages, 1)
end

function Session:notify(method, ...)
    self._rpc_stream:write(method, { ... })
end

function Session:request(method, ...)
    local args = { ... }
    local err, result
    if self._is_running then
        err, result = self:_yielding_request(method, args)
    else
        err, result = self:_blocking_request(method, args)
    end
    if err then
        return false, err
    end
    return true, result
end

function Session:run(request_cb, notification_cb, setup_cb, timeout)
    local on_request = function(method, args, response)
        coroutine_exec(request_cb, method, args, function(status, result, flag)
            if status then
                response:send(result, flag)
            else
                response:send(result, true)
            end
        end)
    end
    local on_notification = function(method, args)
        coroutine_exec(notification_cb, method, args)
    end
    self._is_running = true
    if setup_cb then
        coroutine_exec(setup_cb)
    end
    while #self._pending_messages > 0 do
        local msg = table.remove(self._pending_messages, 1)
        if msg[1] == 'request' then
            on_request(msg[2], msg[3], msg[4])
        else
            on_notification(msg[2], msg[3])
        end
    end
    self:_run(on_request, on_notification, timeout)
    self._is_running = false
end

function Session:stop()
    uv.stop()
end

function Session:close(signal, noblock)
    if not self._timer:is_closing() then
        self._timer:close()
    end
    if not self._prepare:is_closing() then
        self._prepare:close()
    end
    self._rpc_stream:close(signal, noblock)
    self.closed = true
end

function Session:_yielding_request(method, args)
    return coroutine.yield(function(co)
        self._rpc_stream:write(method, args, function(err, result)
            resume_co(co, err, result)
        end)
    end)
end

function Session:_blocking_request(method, args)
    local err, result
    local on_request = function(method_, args_, response)
        table.insert(self._pending_messages, {
            'request',
            method_,
            args_,
            response,
        })
    end
    local on_notification = function(method_, args_)
        table.insert(self._pending_messages, {
            'notification',
            method_,
            args_,
        })
    end
    self._rpc_stream:write(method, args, function(e, r)
        err = e
        result = r
        uv.stop()
    end)
    self:_run(on_request, on_notification)
    return (err or self.eof_err), result
end

function Session:_run(request_cb, notification_cb, timeout)
    if type(timeout) == 'number' then
        self._prepare:start(function()
            self._timer:start(timeout, 0, function()
                uv.stop()
            end)
            self._prepare:stop()
        end)
    end
    self._rpc_stream:read_start(request_cb, notification_cb, function()
        uv.stop()
        --- @diagnostic disable-next-line: invisible
        local stderr = self._rpc_stream._stream.stderr --[[@as string?]]
        stderr = '' ~= ((stderr or ''):match('^%s*(.*%S)') or '') and ' stderr:\n' .. stderr or ''
        self.eof_err = {
            1,
            'EOF was received from Nvim. Likely the Nvim process crashed.' .. stderr,
        }
    end)
    local ret, err, _ = uv.run()
    if ret == nil then
        error(err)
    end
    self._prepare:stop()
    self._timer:stop()
    self._rpc_stream:read_stop()
end

local Client = {} ---@class media.rpc.Client
Client.__index = Client
if false then
    Client.api = vim.api
    Client.fn = vim.fn
end
local function create_callindex(call_func)
    return setmetatable({}, {
        __index = function(tbl, method_name)
            local generated_func = function(...)
                return select(2, assert(call_func(method_name, ...)))
            end
            tbl[method_name] = generated_func
            return generated_func
        end,
    })
end
function Client.new(stream)
    local session = Session.new(stream)
    local self = setmetatable({
        _session = session,
    }, Client)
    self.api = create_callindex(function(method, ...)
        return self:request(method, ...)
    end)
    self.fn = create_callindex(function(func_name, ...)
        return self:request('nvim_call_function', func_name, { ... })
    end)

    return self
end

function Client:request(method, ...)
    return self._session:request(method, ...)
end

function Client:notify(method, ...)
    self._session:notify(method, ...)
end

function Client:close()
    self._session:close()
end

local rpc = {} ---@type media.rpc.Module
function rpc.connect(file_or_address)
    local addr, port = string.match(file_or_address, '(.*):(%d+)')
    local stream = (addr and port) and SocketStream.connect(addr, tonumber(port)) or SocketStream.open(file_or_address)
    return Client.new(stream)
end

rpc.Client = Client
rpc.Session = Session
rpc.RpcStream = RpcStream
rpc.StdioStream = StdioStream
rpc.SocketStream = SocketStream
rpc.ProcStream = ProcStream
return rpc