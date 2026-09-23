-- /qompassai/Diver/lua/acp/util.lua
-- Bounded host boundaries shared by the ACP modules.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local api, fs, uv = vim.api, vim.fs, vim.uv
local M = {}
M.BYTES_MAX = 8 * 1024 * 1024
M.FILE_BYTES_MAX = 1024 * 1024

function M.string(value, limit)
    return type(value) == 'string'
        and #value > 0
        and #value <= (limit or 4096)
        and not value:find('%z')
end

function M.integer(value, low, high)
    return type(value) == 'number'
        and value == value
        and value % 1 == 0
        and value >= low
        and value <= high
end

function M.argv(value)
    if type(value) ~= 'table' or not vim.islist(value) or #value < 1 or #value > 128 then
        return false
    end
    for _, part in ipairs(value) do
        if type(part) ~= 'string' or #part > 32768 or part:find('%z') then
            return false
        end
    end
    return value[1] ~= ''
end

function M.error(message, code)
    return { code = code or -32602, message = tostring(message):sub(1, 4096) }
end

function M.notify(message, level)
    vim.notify(tostring(message), level or vim.log.levels.WARN, { title = 'ACP' })
end

function M.call(callback, ...)
    if not callback then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        M.notify('Callback failed: ' .. tostring(err), vim.log.levels.ERROR)
    end
end

function M.close_timer(timer)
    if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
    end
end

function M.timer(milliseconds, callback)
    local timer = assert(uv.new_timer())
    timer:start(milliseconds, 0, function()
        M.close_timer(timer)
        vim.schedule(callback)
    end)
    return timer
end

function M.absolute(path)
    return M.string(path) and (path:sub(1, 1) == '/' or path:match('^%a:[/\\]') ~= nil)
end

function M.root(path)
    local real = uv.fs_realpath(path or vim.fn.getcwd())
    if not real or (uv.fs_stat(real) or {}).type ~= 'directory' then
        return nil, 'Workspace must be an existing local directory'
    end
    return fs.normalize(real)
end

function M.contains(root, path)
    root, path = fs.normalize(root), fs.normalize(path)
    if vim.fn.has('win32') == 1 then
        root, path = root:lower(), path:lower()
    end
    local prefix = root:gsub('/$', '') .. '/'
    return path == root or path:sub(1, #prefix) == prefix
end

-- Reject symlink components below the canonical root; never expand shell tokens.
function M.path(root, path, allow_missing)
    if not M.absolute(path) then
        return nil, 'Expected an absolute local path'
    end
    path = fs.normalize(path)
    if not M.contains(root, path) then
        return nil, 'Path is outside the session workspace'
    end
    local relative = path:sub(#root:gsub('/$', '') + 2)
    local current = root
    local count = 0
    for part in relative:gmatch('[^/]+') do
        count = count + 1
        if count > 64 then
            return nil, 'Path depth exceeds 64 components'
        end
        current = fs.joinpath(current, part)
        local stat = uv.fs_lstat(current)
        if stat and stat.type == 'link' then
            return nil, 'Symlinks are not allowed for client file access'
        end
        if not stat and not (allow_missing and current == path) then
            return nil, 'Path does not exist: ' .. current
        end
    end
    return path
end

function M.read(path, limit)
    local before = uv.fs_lstat(path)
    if not before or before.type ~= 'file' then
        return nil, 'Not a regular file: ' .. path
    end
    if before.size > (limit or M.FILE_BYTES_MAX) then
        return nil, 'File exceeds byte limit'
    end
    local descriptor, err = uv.fs_open(path, 'r', 0)
    if not descriptor then
        return nil, tostring(err)
    end
    local stat = uv.fs_fstat(descriptor)
    if not stat or stat.ino ~= before.ino or stat.dev ~= before.dev or stat.size ~= before.size then
        uv.fs_close(descriptor)
        return nil, 'File changed while opening it'
    end
    local data, read_error = uv.fs_read(descriptor, stat.size, 0)
    local closed, close_error = uv.fs_close(descriptor)
    if not data or not closed then
        return nil, tostring(read_error or close_error)
    end
    return data
end

function M.mkdir(path)
    local existing = uv.fs_lstat(path)
    if existing then
        if existing.type ~= 'directory' then
            return nil, 'Expected a real directory: ' .. path
        end
        return true
    end
    local ok, err = pcall(vim.fn.mkdir, path, 'p', 448)
    if not ok or not uv.fs_stat(path) then
        return nil, tostring(err)
    end
    return true
end

function M.write(path, content, exclusive)
    if type(content) ~= 'string' or #content > M.BYTES_MAX then
        return nil, 'Invalid file content size'
    end
    local stat = uv.fs_lstat(path)
    if stat and (exclusive or stat.type ~= 'file') then
        return nil, 'Refusing to replace path: ' .. path
    end
    local temporary = path .. '.acp-' .. tostring(uv.hrtime())
    local target = exclusive and path or temporary
    local descriptor, err = uv.fs_open(target, 'wx', stat and bit.band(stat.mode, 511) or 384)
    if not descriptor then
        return nil, tostring(err)
    end
    local written, write_error = uv.fs_write(descriptor, content, 0)
    local synced, sync_error = uv.fs_fsync(descriptor)
    local closed, close_error = uv.fs_close(descriptor)
    if written ~= #content or not synced or not closed then
        local removed, remove_error = uv.fs_unlink(target)
        return nil,
            tostring(write_error or sync_error or close_error or (not removed and remove_error))
    end
    if exclusive then
        return true
    end
    local moved, move_error = uv.fs_rename(temporary, path)
    if not moved then
        local removed, remove_error = uv.fs_unlink(temporary)
        return nil, tostring(move_error or (not removed and remove_error))
    end
    return true
end

-- Iterative budget rejects excessive nesting and bounds cyclic local tables.
function M.structure(value)
    local queue, head, nodes = { { value, 0 } }, 1, 1
    while queue[head] do
        local item = queue[head]
        head = head + 1
        if type(item[1]) == 'table' then
            if item[2] > 32 then
                return nil, 'JSON depth or cyclic table limit'
            end
            for _, child in pairs(item[1]) do
                nodes = nodes + 1
                if nodes > 65536 then
                    return nil, 'JSON node limit'
                end
                if type(child) == 'table' then
                    queue[#queue + 1] = { child, item[2] + 1 }
                end
            end
        end
    end
    return true
end

function M.json(value)
    local valid, failure = M.structure(value)
    if not valid then
        return nil, failure
    end
    local ok, encoded = pcall(vim.json.encode, value)
    if not ok then
        return nil, 'JSON encoding failed: ' .. tostring(encoded)
    end
    if #encoded > M.BYTES_MAX then
        return nil, 'JSON exceeds byte limit'
    end
    return encoded
end

function M.decode(text)
    if type(text) ~= 'string' or #text > M.BYTES_MAX then
        return nil, 'JSON response exceeds byte limit'
    end
    local ok, value = pcall(vim.json.decode, text, { luanil = { object = false } })
    if not ok or type(value) ~= 'table' then
        return nil, 'Expected a JSON object'
    end
    local valid, err = M.structure(value)
    if not valid then
        return nil, err
    end
    return value
end

function M.id()
    local bytes, err = uv.random(16)
    if not bytes then
        return nil, tostring(err)
    end
    local hex = (
        bytes:gsub('.', function(char)
            return ('%02x'):format(char:byte())
        end)
    )
    return hex:sub(1, 8)
        .. '-'
        .. hex:sub(9, 12)
        .. '-4'
        .. hex:sub(14, 16)
        .. '-a'
        .. hex:sub(18, 20)
        .. '-'
        .. hex:sub(21)
end

function M.escape(value)
    return (
        value:gsub('[^%w%-._~]', function(char)
            return ('%%%02X'):format(char:byte())
        end)
    )
end

-- Replace malformed UTF-8 for display/terminal responses, never for filesystem writes.
function M.utf8(text)
    return (
        text:gsub('[\128-\255][\128-\191]*', function(sequence)
            local first, second = sequence:byte(1, 2)
            local length = #sequence
            local valid = (first >= 194 and first <= 223 and length == 2)
                or (first >= 224 and first <= 239 and length == 3 and not (first == 224 and second < 160) and not (first == 237 and second >= 160))
                or (
                    first >= 240
                    and first <= 244
                    and length == 4
                    and not (first == 240 and second < 144)
                    and not (first == 244 and second >= 144)
                )
            return valid and sequence or '�'
        end)
    )
end

-- Sanitize display text only. Keep raw bytes in bounded transport/model state.
function M.display(text)
    text = M.utf8(tostring(text or ''))
    text =
        text:gsub('\27%].-\27\\', ''):gsub('\27%][^\7]*\7', ''):gsub('\27%[[%d;?]*[ -/]*[@-~]', '')
    return (text:gsub('[%z\1-\8\11\12\14-\31\127]', ''))
end

function M.open_file(path, how)
    local allowed = { edit = true, split = true, vsplit = true, tabedit = true }
    if not allowed[how or 'edit'] then
        return nil, 'Unsupported window command'
    end
    api.nvim_cmd(
        { cmd = how or 'edit', args = { path }, magic = { bar = false, file = false } },
        {}
    )
    return true
end
return M
