-- #################################################################
-- /qompassai/Diver/lua/games/love2d/libs.lua
-- Qompass AI LÖVE2D Library Catalog
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
-- Curated subset of love2d-community/awesome-love2d (snapshot 2026-09-27).
-- Every entry pins an exact commit, a source URL, a SHA-256 of the pinned
-- tarball, and a license.
--
-- Checksum honesty: none of these upstreams publish release checksums, so
-- each digest below was computed locally on 2026-09-27 from the tarball of
-- the pinned commit (codeload.github.com/<repo>/tar.gz/<sha>). The commit
-- SHA is the real pin; the digest proves the bytes we hashed are the bytes
-- you get. `vendor()` re-verifies before unpacking and refuses mismatches.
local config = require('games.love2d.config')
local shared_util = require('games.shared.util')

local M = {}

-- Largest single library tarball vendor() will accept.
local TARBALL_SIZE_MAX_BYTES = 50 * 1024 * 1024

---@class Love2dLibEntry
---@field key string catalog key
---@field name string human-readable name
---@field category string awesome-love2d category
---@field repo string owner/name on GitHub
---@field pin string pinned commit SHA (the real version pin)
---@field url string pinned tarball URL
---@field sha256 string digest of the pinned tarball (self-computed)
---@field license string SPDX-ish license name
---@field provenance string how pin + digest were established
---@field files string[] lua sources inside the tarball to vendor
---@field dest_subdir string destination subdir under the vendor root
---@field require_hint string example require path after vendoring

---@type Love2dLibEntry[]
M.CATALOG = {
    {
        key = 'hump',
        name = 'hump',
        category = 'helpers',
        repo = 'vrld/hump',
        pin = '08937cc0ecf72d1a964a8de6cd552c5e136bf0d4',
        url = 'https://codeload.github.com/vrld/hump/tar.gz/08937cc0ecf72d1a964a8de6cd552c5e136bf0d4',
        sha256 = '442a7167eb9b33908e880b6c35cedce0eab22b86bf474f162312c867bc6eef25',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = {
            'camera.lua',
            'class.lua',
            'gamestate.lua',
            'signal.lua',
            'timer.lua',
            'vector.lua',
            'vector-light.lua',
        },
        dest_subdir = 'hump',
        require_hint = "require('hump.gamestate')",
    },
    {
        key = 'bump',
        name = 'bump.lua',
        category = 'physics',
        repo = 'kikito/bump.lua',
        pin = '95d9e40b8aee295fc9d9b78ca214a829d6c21555',
        url = 'https://codeload.github.com/kikito/bump.lua/tar.gz/95d9e40b8aee295fc9d9b78ca214a829d6c21555',
        sha256 = 'e02519e41d3591a4b5dd2eaaf300c0bf55fcd6fb43467af7b01032e2bf5850a7',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = { 'bump.lua' },
        dest_subdir = '',
        require_hint = "require('bump')",
    },
    {
        key = 'anim8',
        name = 'anim8',
        category = 'animation',
        repo = 'kikito/anim8',
        pin = 'bd38defa844ab2dfa3bf416a10c45ce376ba4c50',
        url = 'https://codeload.github.com/kikito/anim8/tar.gz/bd38defa844ab2dfa3bf416a10c45ce376ba4c50',
        sha256 = '1381b784b69828afc6453c8dc0e7792cf5b1fcfaa66571a2ba9d9f086bad6870',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = { 'anim8.lua' },
        dest_subdir = '',
        require_hint = "require('anim8')",
    },
    {
        key = 'lurker',
        name = 'lurker',
        category = 'dev',
        repo = 'rxi/lurker',
        pin = '03d1373911f586c1c6d5d557527b5d510190fd94',
        url = 'https://codeload.github.com/rxi/lurker/tar.gz/03d1373911f586c1c6d5d557527b5d510190fd94',
        sha256 = '608c014856f723f90354bd2e0be5f76e01ad10e9fdb6680acee705cb88d0c8db',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = { 'lurker.lua' },
        dest_subdir = '',
        require_hint = "require('lurker')",
    },
    {
        key = 'lovebird',
        name = 'lovebird',
        category = 'debug',
        repo = 'rxi/lovebird',
        pin = 'e84abe7b56a65ccb3ec6288e1955b6d772d41431',
        url = 'https://codeload.github.com/rxi/lovebird/tar.gz/e84abe7b56a65ccb3ec6288e1955b6d772d41431',
        sha256 = '5e3e4f25a461b4f9bd1b4c4e83b9f08dfd9eef8db1b96e3d4ac628b9fff44ea4',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = { 'lovebird.lua' },
        dest_subdir = '',
        require_hint = "require('lovebird')",
    },
    {
        key = 'peachy',
        name = 'peachy',
        category = 'aseprite',
        repo = 'josh-perry/peachy',
        pin = '80b109833285520f0d259f37ef130d3fe022579d',
        url = 'https://codeload.github.com/josh-perry/peachy/tar.gz/80b109833285520f0d259f37ef130d3fe022579d',
        sha256 = 'a9726a05ffd12e010383a3d3147d1de390f510b6bff26165da0e65d8b0e8d475',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = { 'peachy/init.lua', 'peachy/lib/json.lua' },
        dest_subdir = 'peachy',
        require_hint = "require('peachy')",
    },
    {
        key = 'g3d',
        name = 'g3d',
        category = 'pseudo-3d',
        repo = 'groverburger/g3d',
        pin = '639120acd754dc5c34402e41eb1687b1a5a3ffa8',
        url = 'https://codeload.github.com/groverburger/g3d/tar.gz/639120acd754dc5c34402e41eb1687b1a5a3ffa8',
        sha256 = '304f140c89b8b6dc4d7b04e899205619cb7c20f773f7acea3797f571e7417c8b',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = {
            'g3d/init.lua',
            'g3d/camera.lua',
            'g3d/collisions.lua',
            'g3d/matrices.lua',
            'g3d/model.lua',
            'g3d/objloader.lua',
            'g3d/vectors.lua',
        },
        dest_subdir = 'g3d',
        require_hint = "require('g3d')",
    },
    {
        key = 'baton',
        name = 'baton',
        category = 'input',
        repo = 'tesselode/baton',
        pin = '6723dd9f99ce8a20e553a7b818a1ebcd32cacbaf',
        url = 'https://codeload.github.com/tesselode/baton/tar.gz/6723dd9f99ce8a20e553a7b818a1ebcd32cacbaf',
        sha256 = 'cc05e327ce3f983f9ac546f8f42e4f1c427d379c8e9dcc188825e019d54d5afa',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = { 'baton.lua' },
        dest_subdir = '',
        require_hint = "require('baton')",
    },
    {
        key = 'lume',
        name = 'lume',
        category = 'helpers',
        repo = 'rxi/lume',
        pin = '98847e7812cf28d3d64b289b03fad71dc704547d',
        url = 'https://codeload.github.com/rxi/lume/tar.gz/98847e7812cf28d3d64b289b03fad71dc704547d',
        sha256 = '10e354ba98a7ed9ae016be15aafbca3c719b02e42822bc9e1f100c497259d90e',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = { 'lume.lua' },
        dest_subdir = '',
        require_hint = "require('lume')",
    },
    {
        key = 'loveprofiler',
        name = 'loveprofiler',
        category = 'profiling',
        repo = 'dknight/loveprofiler',
        pin = 'e79c71c65772e8c41a0787416ba5980cfdcb19c1',
        url = 'https://codeload.github.com/dknight/loveprofiler/tar.gz/e79c71c65772e8c41a0787416ba5980cfdcb19c1',
        sha256 = '8a167114651960b7b91983b823ff792cf391d8be88f0b02f3771ceb7215e2daa',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = {
            'init.lua',
            'defaults.lua',
            'drivers/canvas.lua',
            'drivers/console.lua',
        },
        dest_subdir = 'loveprofiler',
        require_hint = "require('loveprofiler')",
    },
    {
        key = 'knife',
        name = 'knife',
        category = 'helpers',
        repo = 'airstruck/knife',
        pin = '5ccd9b425f2c5363389534c7e12b9df05b18ad8e',
        url = 'https://codeload.github.com/airstruck/knife/tar.gz/5ccd9b425f2c5363389534c7e12b9df05b18ad8e',
        sha256 = 'a3f146eba9cbd0abeeb1d779081edab65a8c89b138c96c0069ebf022a3e77622',
        license = 'MIT',
        provenance = 'self-computed 2026-09-27; upstream publishes no checksum',
        files = {
            'knife/base.lua',
            'knife/behavior.lua',
            'knife/bind.lua',
            'knife/chain.lua',
            'knife/convoke.lua',
            'knife/event.lua',
            'knife/gun.lua',
            'knife/memoize.lua',
            'knife/serialize.lua',
            'knife/system.lua',
            'knife/test.lua',
            'knife/timer.lua',
        },
        dest_subdir = 'knife',
        require_hint = "require('knife.timer')",
    },
}

---@param key string catalog key
---@return Love2dLibEntry? entry or nil
function M.get(key)
    assert(type(key) == 'string')
    for _, entry in ipairs(M.CATALOG) do
        if entry.key == key then
            return entry
        end
    end
    return nil
end

---@return string[] catalog keys in order
function M.keys()
    local out = {}
    for _, entry in ipairs(M.CATALOG) do
        out[#out + 1] = entry.key
    end
    return out
end

-- Structural audit of the catalog: every entry must carry a name, a
-- 40-hex pin, a source URL containing that pin, a 64-hex digest, and a
-- license. Returns true + empty list when the catalog is sound.
---@return boolean ok
---@return string[] problems
function M.catalog_integrity()
    local problems = {}
    local seen = {}
    for i, entry in ipairs(M.CATALOG) do
        local where = 'catalog[' .. i .. ']'
        if type(entry.key) ~= 'string' or entry.key == '' then
            problems[#problems + 1] = where .. ': missing key'
        elseif seen[entry.key] then
            problems[#problems + 1] = where .. ': duplicate key ' .. entry.key
        else
            seen[entry.key] = true
        end
        if type(entry.pin) ~= 'string' or not entry.pin:match('^%x+$') or #entry.pin ~= 40 then
            problems[#problems + 1] = where .. ': pin is not a 40-hex commit SHA'
        end
        if type(entry.url) ~= 'string' or not entry.url:find(entry.pin or '', 1, true) then
            problems[#problems + 1] = where .. ': url does not contain the pin'
        end
        if type(entry.sha256) ~= 'string' or not entry.sha256:match('^%x+$') or #entry.sha256 ~= 64 then
            problems[#problems + 1] = where .. ': sha256 is not 64 hex chars'
        end
        if type(entry.license) ~= 'string' or entry.license == '' then
            problems[#problems + 1] = where .. ': missing license'
        end
        if type(entry.files) ~= 'table' or #entry.files == 0 then
            problems[#problems + 1] = where .. ': no vendored files listed'
        end
    end
    return #problems == 0, problems
end

---@param path string file to hash
---@param expected_sha string 64-hex digest
---@return boolean ok
---@return string? err
function M.verify_artifact(path, expected_sha)
    assert(type(path) == 'string' and path ~= '')
    assert(type(expected_sha) == 'string' and expected_sha:match('^%x+$') ~= nil)
    if vim.fn.filereadable(path) ~= 1 then
        return false, 'not a readable file: ' .. path
    end
    local stat = vim.uv.fs_stat(path)
    if stat ~= nil and stat.size > TARBALL_SIZE_MAX_BYTES then
        return false, 'tarball exceeds size cap'
    end
    local completed = vim.system({ 'sha256sum', path }, { text = true }):wait()
    if completed.code ~= 0 then
        return false, 'sha256sum failed for ' .. path
    end
    local actual = (completed.stdout or ''):match('^%x+')
    if actual == nil or actual:lower() ~= expected_sha:lower() then
        return false, 'checksum mismatch for ' .. path
    end
    return true, nil
end

---@param entry Love2dLibEntry
---@param dest string tarball destination path
---@return boolean ok
---@return string? err
local function download_entry(entry, dest)
    vim.fn.mkdir(vim.fs.dirname(dest), 'p')
    local completed = vim.system({
        'curl',
        '-sSL',
        '--retry',
        '3',
        '--max-time',
        tostring(math.floor(config.download_timeout_ms / 1000)),
        '-o',
        dest,
        entry.url,
    }, { text = true }):wait()
    if completed.code ~= 0 then
        return false, ('download failed (%s): %s'):format(entry.url, shared_util.trim(completed.stderr or ''))
    end
    return M.verify_artifact(dest, entry.sha256)
end

-- Copy the entry's listed files out of the unpacked tarball.
---@param entry Love2dLibEntry
---@param unpacked_root string tarball top dir
---@param dest_dir string vendor destination
---@return string[]? vendored relative paths
---@return string? err
local function copy_entry_files(entry, unpacked_root, dest_dir)
    local vendored = {}
    for _, rel in ipairs(entry.files) do
        local safe = rel ~= '' and rel:find('%.%.', 1, true) == nil
        if not safe then
            return nil, 'unsafe file entry in catalog: ' .. tostring(rel)
        end
        local src = unpacked_root .. '/' .. rel
        if vim.fn.filereadable(src) ~= 1 then
            return nil, ('pinned tarball is missing listed file: %s'):format(rel)
        end
        local dest_sub = entry.dest_subdir ~= '' and (entry.dest_subdir .. '/') or ''
        local dest = dest_dir .. '/' .. dest_sub .. rel
        vim.fn.mkdir(vim.fs.dirname(dest), 'p')
        local copied = vim.system({ 'cp', src, dest }, { text = true }):wait()
        if copied.code ~= 0 then
            return nil, 'copy failed: ' .. rel
        end
        vendored[#vendored + 1] = dest_sub .. rel
    end
    return vendored, nil
end

-- Download (unless opts.artifact_path is given), verify the digest, unpack,
-- and copy the entry's Lua sources into dest_dir. Fails closed on any
-- checksum mismatch or missing file.
---@param key string catalog key
---@param dest_dir string vendor destination directory
---@param opts? { artifact_path?: string } pre-downloaded tarball (tests/offline)
---@return string[]? vendored relative paths
---@return string? err
function M.vendor(key, dest_dir, opts)
    opts = opts or {}
    assert(type(key) == 'string' and key ~= '')
    assert(type(dest_dir) == 'string' and dest_dir ~= '')
    local entry = M.get(key)
    if entry == nil then
        return nil, 'unknown library: ' .. key
    end
    local tarball = opts.artifact_path
    local tmp_tarball = nil
    if tarball == nil then
        tmp_tarball = vim.fn.tempname() .. '-' .. key .. '.tar.gz'
        local ok, err = download_entry(entry, tmp_tarball)
        if not ok then
            vim.fn.delete(tmp_tarball)
            return nil, err
        end
        tarball = tmp_tarball
    else
        local ok, err = M.verify_artifact(tarball, entry.sha256)
        if not ok then
            return nil, err
        end
    end
    local tmp_unpack = vim.fn.tempname() .. '-' .. key .. '-unpacked'
    vim.fn.mkdir(tmp_unpack, 'p')
    local unpacked = vim.system({ 'tar', '-xzf', tarball, '-C', tmp_unpack }, { text = true }):wait()
    if tmp_tarball ~= nil then
        vim.fn.delete(tmp_tarball)
    end
    if unpacked.code ~= 0 then
        vim.fn.delete(tmp_unpack, 'rf')
        return nil, 'tarball unpack failed for ' .. key
    end
    -- codeload tarballs unpack to <reponame>-<sha>/.
    local top = tmp_unpack .. '/' .. entry.repo:match('[^/]+$') .. '-' .. entry.pin
    if vim.fn.isdirectory(top) ~= 1 then
        vim.fn.delete(tmp_unpack, 'rf')
        return nil, 'unexpected tarball layout for ' .. key
    end
    vim.fn.mkdir(dest_dir, 'p')
    local vendored, cerr = copy_entry_files(entry, top, dest_dir)
    vim.fn.delete(tmp_unpack, 'rf')
    if vendored == nil then
        return nil, cerr
    end
    return vendored, nil
end

return M
