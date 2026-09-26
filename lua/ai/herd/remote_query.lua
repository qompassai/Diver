-- /qompassai/Diver/lua/ai/herd/remote_query.lua
-- Remote end of ai.herd.remotes.query, run on the REMOTE machine via
-- ssh as: nvim --headless --noplugin
--   -l <diver_path>/lua/ai/herd/remote_query.lua
-- Reads one JSON herd-socket request from stdin, forwards it to the
-- remote herd unix socket, and prints the socket's one-line JSON reply.
-- Every path prints exactly one JSON line and exits 0, so the ssh caller
-- always gets parseable output. Uses only vim.uv, vim.json and
-- vim.fn.stdpath: no plugins, no diver config.

local LINE_BYTES_MAX = 65536
local WAIT_TIMEOUT_MS = 15000

---Socket path, computed exactly like ai.herd.api does: prefer
---vim.fn.stdpath('run'), fall back to $XDG_RUNTIME_DIR.
---@return string
local function socket_path()
    local run_dir = vim.fn.stdpath('run')
    if run_dir == '' then
        run_dir = os.getenv('XDG_RUNTIME_DIR') or ''
    end
    return run_dir .. '/herd.sock'
end

---@param message string
local function fail(message)
    io.stdout:write(vim.json.encode({ ok = false, error = message }) .. '\n')
end

local function main()
    local request_line = io.read('*l')
    assert(request_line ~= nil, 'expected one request line on stdin')
    assert(#request_line <= LINE_BYTES_MAX, 'request line is too long')
    local path = socket_path()
    if vim.uv.fs_stat(path) == nil then
        return fail('no herd socket on remote')
    end
    local pipe = assert(vim.uv.new_pipe(false), 'could not allocate pipe')
    local done, failure, response, total_bytes = false, nil, nil, 0
    local chunks = {}
    local function finish(err, line)
        failure, response, done = err, line, true
    end
    pipe:connect(path, function(connect_err)
        if connect_err ~= nil then
            return finish('connect: ' .. tostring(connect_err))
        end
        -- No write callback: a failed write surfaces as EOF below.
        pipe:write(request_line .. '\n')
        pipe:read_start(function(read_err, chunk)
            if read_err ~= nil then
                finish('read: ' .. tostring(read_err))
            elseif chunk == nil then
                finish('remote closed the connection')
            elseif total_bytes + #chunk > LINE_BYTES_MAX then
                finish('response is too long')
            else
                total_bytes = total_bytes + #chunk
                chunks[#chunks + 1] = chunk
                local buffered = table.concat(chunks)
                local newline_at = buffered:find('\n', 1, true)
                if newline_at ~= nil then
                    finish(nil, buffered:sub(1, newline_at - 1))
                end
            end
        end)
    end)
    vim.wait(WAIT_TIMEOUT_MS, function()
        return done
    end)
    pipe:close()
    if not done then
        fail('timed out waiting for the remote herd socket')
    elseif failure ~= nil then
        fail(failure)
    else
        io.stdout:write(assert(response, 'finished with no response') .. '\n')
    end
end

local ok, err = pcall(main)
if not ok then
    fail('remote_query: ' .. tostring(err))
end
