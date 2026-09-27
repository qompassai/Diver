-- #################################################################
-- /qompassai/Diver/lua/games/love2d/dev.lua
-- Qompass AI LÖVE2D Development Loop
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
-- The inner dev loop: run the game through the managed binary, watch the
-- project tree and restart on change, and attach the debug console
-- (lovebird) and profiler (loveprofiler) development hooks.
--
-- Every entry point fails closed when the managed binary is absent: the
-- user gets an error telling them how to install it, never a dead job.
-- Moonwalk remains the default debugger; lovebird is a runtime debug
-- console (browser UI), not a replacement for breakpoints.
local versions = require('games.love2d.versions')
local libs = require('games.love2d.libs')

local M = {}

-- Debounce window before a file change triggers a restart.
local RESTART_DEBOUNCE_MS = 300
-- Deepest nesting the watcher descends.
local WATCH_DEPTH_MAX = 16
-- Most directories watched at once (bounds handle count).
local WATCH_DIR_MAX = 128

local state = {
    job = nil,
    project_dir = nil,
    watchers = {},
    debounce = nil,
}

---@return boolean a game job is currently running
function M.is_running()
    return state.job ~= nil
end

-- Stop the running game and close all watchers. Safe to call when idle.
function M.stop()
    if state.job ~= nil then
        vim.fn.jobstop(state.job)
        state.job = nil
        state.project_dir = nil
    end
    if state.debounce ~= nil then
        state.debounce:stop()
        state.debounce:close()
        state.debounce = nil
    end
    for _, watcher in ipairs(state.watchers) do
        watcher:stop()
    end
    state.watchers = {}
end

---@param project_dir string game directory or .love file
---@param bin string love binary
---@param args string[] extra love args
---@return integer? job id, nil when the job could not start
local function start_job(project_dir, bin, args)
    local cwd = project_dir
    if vim.fn.isdirectory(project_dir) ~= 1 then
        cwd = vim.fs.dirname(project_dir)
    end
    local argv = { bin, project_dir }
    for _, arg in ipairs(args or {}) do
        argv[#argv + 1] = arg
    end
    local job
    job = vim.fn.jobstart(argv, {
        cwd = cwd,
        on_exit = function(_, code)
            if state.job == job then
                state.job = nil
            end
            if code ~= 0 then
                vim.notify(('LÖVE2D: game exited with code %d'):format(code), vim.log.levels.WARN)
            end
        end,
    })
    if job <= 0 then
        return nil
    end
    return job
end

-- Run the game through the managed binary. Restarts an already-running
-- game. Returns the job id, or nil after notifying when no binary exists.
---@param project_dir string game directory or .love file
---@param args? string[] extra arguments passed to love
---@return integer? job id
function M.run(project_dir, args)
    assert(type(project_dir) == 'string' and project_dir ~= '')
    local bin = versions.require_binary()
    if bin == nil then
        return nil
    end
    local exists = vim.fn.isdirectory(project_dir) == 1 or vim.fn.filereadable(project_dir) == 1
    if not exists then
        vim.notify('LÖVE2D: no such game: ' .. project_dir, vim.log.levels.ERROR)
        return nil
    end
    M.stop()
    local job = start_job(project_dir, bin, args or {})
    if job == nil then
        vim.notify('LÖVE2D: could not start the game process', vim.log.levels.ERROR)
        return nil
    end
    state.job = job
    state.project_dir = project_dir
    return job
end

-- Install fs watchers over the project tree; a change restarts the game
-- after a short debounce. Bounded: at most WATCH_DIR_MAX directories.
---@param project_dir string
---@return boolean ok
---@return string? err
function M.watch(project_dir)
    assert(type(project_dir) == 'string' and project_dir ~= '')
    if vim.fn.isdirectory(project_dir) ~= 1 then
        return false, 'not a directory: ' .. project_dir
    end
    M.unwatch()
    local dirs = { { dir = project_dir, depth = 0 } }
    local i = 1
    while i <= #dirs and #state.watchers < WATCH_DIR_MAX do
        local frame = dirs[i]
        i = i + 1
        local watcher = vim.uv.new_fs_event()
        if watcher == nil then
            break
        end
        local started = watcher:start(frame.dir, {}, function()
            if state.debounce == nil then
                state.debounce = vim.uv.new_timer()
            end
            state.debounce:start(RESTART_DEBOUNCE_MS, 0, function()
                vim.schedule(function()
                    if state.project_dir ~= nil then
                        M.run(state.project_dir)
                    end
                end)
            end)
        end)
        if started == nil then
            watcher:stop()
        else
            state.watchers[#state.watchers + 1] = watcher
            if frame.depth < WATCH_DEPTH_MAX then
                local handle = vim.uv.fs_scandir(frame.dir)
                if handle ~= nil then
                    while true do
                        local name, ftype = vim.uv.fs_scandir_next(handle)
                        if name == nil then
                            break
                        end
                        if ftype == 'directory' and name ~= '.git' and name ~= '.love' then
                            dirs[#dirs + 1] = { dir = frame.dir .. '/' .. name, depth = frame.depth + 1 }
                        end
                    end
                end
            end
        end
    end
    if #state.watchers == 0 then
        return false, 'could not watch any directory under ' .. project_dir
    end
    return true, nil
end

-- Remove watchers installed by watch(). The game keeps running.
function M.unwatch()
    if state.debounce ~= nil then
        state.debounce:stop()
        state.debounce:close()
        state.debounce = nil
    end
    for _, watcher in ipairs(state.watchers) do
        watcher:stop()
    end
    state.watchers = {}
end

-- Vendor a dev hook library into the project root and print the snippet to
-- wire it into main.lua. Fails closed when the catalog entry is missing or
-- the tarball checksum does not match.
---@param key string catalog key ('lovebird' or 'loveprofiler')
---@param project_dir string
---@param snippet string[] lines to add to main.lua
---@param blurb string what the hook gives the developer
---@return boolean ok
---@return string? err
local function setup_hook(key, project_dir, snippet, blurb)
    assert(type(project_dir) == 'string' and project_dir ~= '')
    if vim.fn.isdirectory(project_dir) ~= 1 then
        return false, 'not a directory: ' .. project_dir
    end
    local entry = libs.get(key)
    if entry == nil then
        return false, 'unknown dev hook: ' .. key
    end
    local vendored, verr = libs.vendor(key, project_dir)
    if vendored == nil then
        return false, verr
    end
    vim.notify(
        ('LÖVE2D %s ready (%s). Add to main.lua:\n%s\nRemove before packaging.'):format(
            entry.name,
            blurb,
            table.concat(snippet, '\n')
        ),
        vim.log.levels.INFO
    )
    return true, nil
end

-- Attach the lovebird debug console (browser UI at localhost:8000).
---@param project_dir string
---@return boolean ok
---@return string? err
function M.setup_console(project_dir)
    return setup_hook('lovebird', project_dir, {
        "local lovebird = require('lovebird')",
        'function love.update(dt)',
        '  lovebird.update()',
        '  -- your update code here',
        'end',
    }, 'runtime debug console at http://localhost:8000')
end

-- Attach the loveprofiler frame profiler (canvas or console driver).
---@param project_dir string
---@return boolean ok
---@return string? err
function M.setup_profiler(project_dir)
    return setup_hook('loveprofiler', project_dir, {
        "local LoveProfiler = require('loveprofiler')",
        'function love.load()',
        '  profiler = LoveProfiler:new()',
        'end',
        'function love.draw()',
        '  profiler:start()',
        '  -- your draw code here',
        'end',
    }, 'frame profiler overlay')
end

return M
