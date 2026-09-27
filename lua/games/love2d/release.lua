-- #################################################################
-- /qompassai/Diver/lua/games/love2d/release.lua
-- Qompass AI LÖVE2D Release Pipeline
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
-- Turns a .love file into per-OS distributables by fusing it with the
-- pinned platform runtimes (see versions.lua):
--
--   windows : love.exe + game.love concatenated into game.exe (the
--             documented LÖVE fused-binary layout), shipped with the DLLs
--   macos   : game.love dropped into love.app/Contents/Resources/
--   linux   : AppImage + game.love side by side with a launcher script.
--             Honest limitation: LÖVE documents no supported single-file
--             fuse on Linux, so we ship the honest two-file layout rather
--             than inventing one.
--
-- Fail-closed: a target whose runtime artifact is absent produces an error
-- naming the artifact -- never a half-written bundle. itch.io Butler is a
-- hook only: the operator's own `butler login` session holds the
-- credentials; nothing secret is read from or written to the repo.
local config = require('games.love2d.config')
local versions = require('games.love2d.versions')
local shared_util = require('games.shared.util')

local M = {}

local COPY_CHUNK_BYTES = 65536

---@class Love2dReleaseResult
---@field target string 'windows' | 'macos' | 'linux'
---@field ok boolean
---@field path string? bundle directory on success
---@field err string? reason on failure

---@return string[] ordered target keys
function M.targets()
    return { 'windows', 'macos', 'linux' }
end

-- Which managed artifact each target needs.
local TARGET_ARTIFACT = {
    windows = 'win64',
    macos = 'macos',
    linux = 'linux',
}

---@param target string
---@return string? artifact path
---@return string? err naming the missing artifact
local function require_artifact(target)
    local key = TARGET_ARTIFACT[target]
    local path = versions.artifact_path(key)
    if path == nil then
        local artifact = versions.ARTIFACTS[key]
        return nil,
            ('missing %s runtime artifact (%s); run :Love2dInstall to fetch %s'):format(
                target,
                artifact.file,
                artifact.url
            )
    end
    return path, nil
end

---@param zip_path string
---@return string? extracted root dir
---@return string? err
local function unzip_to_temp(zip_path)
    local tmp = vim.fn.tempname() .. '-love-unzip'
    vim.fn.mkdir(tmp, 'p')
    local done = vim.system({ 'unzip', '-q', zip_path, '-d', tmp }, { text = true }):wait()
    if done.code ~= 0 then
        vim.fn.delete(tmp, 'rf')
        return nil, 'unzip failed: ' .. shared_util.trim(done.stderr or '')
    end
    return tmp, nil
end

---@param src string
---@param dest string
---@return boolean ok
---@return string? err
local function copy_binary(src, dest)
    local input = io.open(src, 'rb')
    if input == nil then
        return false, 'cannot read: ' .. src
    end
    local output = io.open(dest, 'wb')
    if output == nil then
        input:close()
        return false, 'cannot write: ' .. dest
    end
    while true do
        local chunk = input:read(COPY_CHUNK_BYTES)
        if chunk == nil then
            break
        end
        output:write(chunk)
    end
    input:close()
    output:close()
    return true, nil
end

-- The extracted zip may wrap everything in one top-level directory.
---@param tmp string unzip root
---@return string dir holding the runtime files
local function runtime_root(tmp)
    local handle = vim.uv.fs_scandir(tmp)
    local first, first_type, count = nil, nil, 0
    if handle ~= nil then
        while true do
            local name, ftype = vim.uv.fs_scandir_next(handle)
            if name == nil then
                break
            end
            count = count + 1
            first, first_type = name, ftype
        end
    end
    if count == 1 and first_type == 'directory' then
        return tmp .. '/' .. first
    end
    return tmp
end

---@param game_love string
---@param dest_dir string
---@return string? bundle dir
---@return string? err
local function fuse_windows(game_love, dest_dir)
    local zip_path, err = require_artifact('windows')
    if zip_path == nil then
        return nil, err
    end
    local tmp, uerr = unzip_to_temp(zip_path)
    if tmp == nil then
        return nil, uerr
    end
    local root = runtime_root(tmp)
    local love_exe = root .. '/love.exe'
    if vim.fn.filereadable(love_exe) ~= 1 then
        vim.fn.delete(tmp, 'rf')
        return nil, 'win64 runtime has no love.exe'
    end
    vim.fn.mkdir(dest_dir, 'p')
    -- Ship the runtime tree (exe, dlls, licenses) as-is.
    local copied = vim.system({ 'cp', '-a', root .. '/.', dest_dir .. '/' }, { text = true }):wait()
    vim.fn.delete(tmp, 'rf')
    if copied.code ~= 0 then
        return nil, 'could not stage windows runtime'
    end
    -- Fused binary: love.exe bytes followed by the .love bytes.
    local game_exe = dest_dir .. '/game.exe'
    local ok, cerr = copy_binary(love_exe, game_exe)
    if not ok then
        return nil, cerr
    end
    local exe = io.open(game_exe, 'ab')
    local game = io.open(game_love, 'rb')
    if exe == nil or game == nil then
        if exe ~= nil then
            exe:close()
        end
        if game ~= nil then
            game:close()
        end
        return nil, 'could not open files for fusing'
    end
    while true do
        local chunk = game:read(COPY_CHUNK_BYTES)
        if chunk == nil then
            break
        end
        exe:write(chunk)
    end
    game:close()
    exe:close()
    vim.system({ 'chmod', '+x', game_exe }):wait()
    return dest_dir, nil
end

---@param game_love string
---@param dest_dir string
---@return string? bundle dir
---@return string? err
local function fuse_macos(game_love, dest_dir)
    local zip_path, err = require_artifact('macos')
    if zip_path == nil then
        return nil, err
    end
    local tmp, uerr = unzip_to_temp(zip_path)
    if tmp == nil then
        return nil, uerr
    end
    local root = runtime_root(tmp)
    local app = root .. '/love.app'
    if vim.fn.isdirectory(app) ~= 1 then
        vim.fn.delete(tmp, 'rf')
        return nil, 'macos runtime has no love.app'
    end
    vim.fn.mkdir(dest_dir, 'p')
    local staged = vim.system({ 'cp', '-a', app, dest_dir .. '/love.app' }, { text = true }):wait()
    vim.fn.delete(tmp, 'rf')
    if staged.code ~= 0 then
        return nil, 'could not stage love.app'
    end
    local resources = dest_dir .. '/love.app/Contents/Resources'
    local ok, cerr = copy_binary(game_love, resources .. '/game.love')
    if not ok then
        return nil, cerr
    end
    return dest_dir, nil
end

---@param game_love string
---@param dest_dir string
---@return string? bundle dir
---@return string? err
local function bundle_linux(game_love, dest_dir)
    local appimage, err = require_artifact('linux')
    if appimage == nil then
        return nil, err
    end
    vim.fn.mkdir(dest_dir, 'p')
    local ok, cerr = copy_binary(appimage, dest_dir .. '/love.AppImage')
    if not ok then
        return nil, cerr
    end
    ok, cerr = copy_binary(game_love, dest_dir .. '/game.love')
    if not ok then
        return nil, cerr
    end
    -- Launcher: runs the managed AppImage against the bundled .love.
    local launcher = dest_dir .. '/run.sh'
    local fh = io.open(launcher, 'w')
    if fh == nil then
        return nil, 'cannot write launcher: ' .. launcher
    end
    fh:write('#!/bin/sh\n# Generated by diver games.love2d release pipeline.\n')
    fh:write('exec "$(dirname "$0")/love.AppImage" "$(dirname "$0")/game.love" "$@"\n')
    fh:close()
    vim.system({ 'chmod', '+x', dest_dir .. '/love.AppImage', launcher }):wait()
    return dest_dir, nil
end

local FUSERS = {
    windows = fuse_windows,
    macos = fuse_macos,
    linux = bundle_linux,
}

---@param game_love string path to a .love file
---@param dest_root string bundles land in <dest_root>/<game>-<target>/
---@param opts? { game?: string, targets?: string[] }
---@return Love2dReleaseResult[] one row per requested target
function M.release(game_love, dest_root, opts)
    opts = opts or {}
    assert(type(game_love) == 'string' and game_love ~= '')
    assert(type(dest_root) == 'string' and dest_root ~= '')
    local game = opts.game or 'game'
    assert(type(game) == 'string' and game:match('^[%w_%-%.]+$') ~= nil, 'love2d: unsafe game name')
    if vim.fn.filereadable(game_love) ~= 1 then
        return {
            { target = '*', ok = false, err = 'no such .love file: ' .. game_love },
        }
    end
    local wanted = opts.targets or M.targets()
    local results = {}
    for _, target in ipairs(wanted) do
        local fuser = FUSERS[target]
        if fuser == nil then
            results[#results + 1] = { target = target, ok = false, err = 'unknown target: ' .. target }
        else
            local dest_dir = dest_root .. '/' .. game .. '-' .. target
            local path, err = fuser(game_love, dest_dir)
            if path == nil then
                results[#results + 1] = { target = target, ok = false, err = err }
            else
                results[#results + 1] = { target = target, ok = true, path = path }
            end
        end
    end
    return results
end

-- itch.io Butler hook. Credentials are NEVER handled here: the operator
-- runs `butler login` once in their own shell; this only assembles the
-- push command from user-supplied (not repo-stored) values.
---@param bundle_dir string
---@param opts { user: string, game: string, channel?: string }
---@return integer? job id
---@return string? err
function M.butler_push(bundle_dir, opts)
    assert(type(bundle_dir) == 'string' and bundle_dir ~= '')
    assert(type(opts) == 'table' and type(opts.user) == 'string' and opts.user ~= '')
    assert(type(opts.game) == 'string' and opts.game ~= '')
    if vim.fn.isdirectory(bundle_dir) ~= 1 then
        return nil, 'not a directory: ' .. bundle_dir
    end
    if vim.fn.executable(config.butler.binary) ~= 1 then
        return nil, 'butler not on PATH (install itch.io Butler first)'
    end
    local channel = opts.channel or config.butler.default_channel
    local argv = {
        config.butler.binary,
        'push',
        bundle_dir,
        opts.user .. '/' .. opts.game .. ':' .. channel,
    }
    local job = vim.fn.jobstart(argv, {
        on_exit = function(_, code)
            local level = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
            vim.notify(('Butler push %s (exit %d)'):format(bundle_dir, code), level)
        end,
    })
    if job <= 0 then
        return nil, 'could not start butler'
    end
    return job, nil
end

return M
