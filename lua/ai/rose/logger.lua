-- /qompassai/Diver/lua/ai/rose/logger.lua
-- Bounded file + notify logger for the Rose fold-in (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Minimal port of rose.nvim's logger: error/warning/info/debug with a
-- bounded on-disk log for errors and debug lines. Debug output is gated
-- on the DEBUG_ROSE environment variable. Unlike the original, this never
-- overrides vim.notify with a plugin; native notification stays in place.

local M = {
    _plugin_name = 'diver.rose',
    _logfile = vim.fn.stdpath('state') .. '/diver-rose.log',
    _max_log_lines = 10000,
    _debug_enabled = vim.env.DEBUG_ROSE ~= nil,
}

---@param path string
---@return string content  -- '' when the file cannot be read
local function read_file(path)
    local file = io.open(path, 'r')
    if not file then
        return ''
    end
    local content = file:read('*a')
    file:close()
    return content or ''
end

---@param path string
---@param content string
---@return boolean ok
local function write_file(path, content)
    local file = io.open(path, 'w')
    if not file then
        return false
    end
    local written = file:write(content)
    local closed = file:close()
    return written ~= nil and closed ~= nil
end

-- Keep only the newest _max_log_lines lines so the log cannot grow without bound.
---@return string limited
local function limit_logfile_lines()
    local lines = vim.split(read_file(M._logfile), '\n')
    while #lines > M._max_log_lines do
        table.remove(lines, 1)
    end
    return table.concat(lines, '\n')
end

---@param msg string
---@param kind string
local function write_to_logfile(msg, kind)
    local entry = string.format('[%s] %s: [%s] %s\n', os.date('%Y-%m-%d %H:%M:%S'), M._plugin_name, kind, msg)
    write_file(M._logfile, limit_logfile_lines() .. entry)
end

---@param msg string
---@param kind string
---@param level integer vim.log.levels value
local function log(msg, kind, level)
    assert(type(msg) == 'string', 'logger: msg must be a string')
    if kind == 'ErrorMsg' or kind == 'Debug' then
        write_to_logfile(msg, kind)
    end
    if kind ~= 'Debug' then
        vim.schedule(function()
            vim.notify(msg, level, { title = M._plugin_name .. ' ' .. kind })
        end)
    end
end

---@param msg string
function M.error(msg)
    log(msg, 'ErrorMsg', vim.log.levels.ERROR)
end

---@param msg string
function M.warning(msg)
    log(msg, 'WarningMsg', vim.log.levels.WARN)
end

---@param msg string
function M.info(msg)
    log(msg, 'Normal', vim.log.levels.INFO)
end

---@param msg string
function M.debug(msg)
    if M._debug_enabled then
        log(msg, 'Debug', vim.log.levels.DEBUG)
    end
end

return M
