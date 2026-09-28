--[[
#################################################################
# /qompassai/lua/dap/log.lua
# Qompass AI Log
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
local M = {}
---@type table<string, dap.log.Log>
local loggers = {}
M._loggers = loggers
---@enum dap.log.Level
M.levels = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

---@alias dap.log.Levels "TRACE"|"DEBUG"|"INFO"|"WARN"|"ERROR"
local default_level = M.levels.INFO
local log_date_format = '!%F %H:%M:%S'
---@param level dap.log.Level|dap.log.Levels
---@return dap.log.Level? level
---@return string? err
local function tolevel(level)
    if type(level) == 'string' then
        local nr = M.levels[tostring(level):upper()]
        if not nr then
            return nil,
                string.format(
                    'Log level must be one of (trace, debug, info, warn, error), got: %q',
                    level
                )
        end
        return nr
    end
    -- Numeric levels must name a real level; anything else is a caller bug.
    if type(level) == 'number' and level >= 0 and level <= 4 and math.floor(level) == level then
        return level
    end
    return nil,
        string.format(
            'Log level must be one of (trace, debug, info, warn, error), got: %s',
            tostring(level)
        )
end

---@class dap.log.Log
---@field _fname string
---@field _path string
---@field _file file*?
---@field _level dap.log.Level
local Log = {}
local log_mt = {
    __index = Log,
}

---@return boolean ok
---@return string? err
function Log:write(...)
    local ok, err = self:open()
    if not ok then
        return nil, err
    end
    self._file:write(...)
    self._file:flush()
    return true
end

---@return boolean ok
---@return string? err
function Log:open()
    if not self._file then
        local f, err = io.open(self._path, 'w+')
        if not f then
            return nil, err
        end
        self._file = f
    end
    return true
end

---@param level dap.log.Level|string
---@return boolean ok
---@return string? err
function Log:set_level(level)
    local nr, err = tolevel(level)
    if not nr then
        return false, err
    end
    self._level = nr
    return true
end

function Log:get_path()
    return self._path
end

function Log:close()
    if self._file then
        self._file:flush()
        self._file:close()
        self._file = nil
    end
end

function Log:remove()
    self:close()
    os.remove(self._path)
    loggers[self._fname] = nil
end

---@param level string
---@param levelnr integer
---@param ... any message parts to format into the log line
---@return boolean
function Log:_log(level, levelnr, ...)
    local argc = select('#', ...)
    if levelnr < self._level then
        return false
    end
    if argc == 0 then
        return true
    end
    local info = debug.getinfo(3, 'Sl')
    -- getinfo can return nil if _log is called directly at a shallow stack
    -- depth; never let caller-location reporting crash the log call.
    local fileinfo = '?'
    if info then
        local _, end_ = info.short_src:find('nvim-dap/lua', 1, true)
        local src = end_ and info.short_src:sub(end_ + 2) or info.short_src
        fileinfo = string.format('%s:%s', src, info.currentline)
    end
    local parts = {
        table.concat({ '[', level, '] ', os.date(log_date_format), ' ', fileinfo }, ''),
    }
    for i = 1, argc do
        local arg = select(i, ...)
        if arg == nil then
            table.insert(parts, 'nil')
        else
            table.insert(parts, vim.inspect(arg))
        end
    end
    self:write(table.concat(parts, '\t'), '\n')
    return true
end
function Log:trace(...)
    self:_log('TRACE', M.levels.TRACE, ...)
end
function Log:debug(...)
    self:_log('DEBUG', M.levels.DEBUG, ...)
end
function Log:info(...)
    self:_log('INFO', M.levels.INFO, ...)
end
function Log:warn(...)
    self:_log('WARN', M.levels.WARN, ...)
end
function Log:error(...)
    self:_log('ERROR', M.levels.ERROR, ...)
end
---@param level dap.log.Level|dap.log.Levels
---@return boolean ok
---@return string? err
function M.set_level(level)
    local nr, err = tolevel(level)
    if not nr then
        return false, err
    end
    for _, logger in pairs(loggers) do
        logger._level = nr
    end
    default_level = nr
    return true
end
---@param fname string
---@return string? path
---@return string? log_dir
---@return string? err
local function getpath(fname)
    local path_sep = vim.uv.os_uname().sysname == 'Windows' and '\\' or '/'
    -- Manual flatten: vim.tbl_flatten is deprecated.
    local joinpath = (vim.fs or {}).joinpath or function(...)
        local flat = {}
        local function add(part)
            if type(part) == 'table' then
                for _, item in ipairs(part) do
                    add(item)
                end
            else
                flat[#flat + 1] = part
            end
        end
        for _, part in ipairs({ ... }) do
            add(part)
        end
        return table.concat(flat, path_sep)
    end
    local log_dir = vim.fn.stdpath('log')
    if type(log_dir) ~= 'string' then
        return nil,
            nil,
            'could not determine log directory: stdpath("log") returned ' .. type(log_dir)
    end
    return joinpath(log_dir, fname), log_dir
end
---@param filename string
---@return dap.log.Log? logger
---@return string? err
function M.create_logger(filename)
    local logger = loggers[filename]
    if logger then
        local ok, err = logger:open()
        if not ok then
            return nil, err
        end
        return logger
    end
    local path, log_dir, err = getpath(filename)
    if not path then
        return nil, err
    end
    vim.fn.mkdir(log_dir, 'p')
    local log = {
        _fname = filename,
        _path = path,
        _level = default_level,
    }
    logger = setmetatable(log, log_mt)
    loggers[filename] = logger
    local ok, open_err = logger:open()
    if not ok then
        loggers[filename] = nil
        return nil, open_err
    end
    return logger
end

--- A no-op logger with the same shape as `dap.log.Log`.
---
--- Safe fallback when `create_logger` fails: logging is best-effort
--- infrastructure and must never break the debugger.
---@return dap.log.Log
function M.null_logger()
    local noop = function()
        return true
    end
    return setmetatable({
        _fname = '',
        _path = '',
        _level = M.levels.ERROR,
        get_path = function()
            return ''
        end,
    }, {
        __index = function()
            return noop
        end,
    })
end
return M
