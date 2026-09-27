-- #################################################################
-- /qompassai/Diver/lua/games/love2d/versions.lua
-- Qompass AI LÖVE2D Version Manager
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
-- Owns the managed LÖVE install: which release is pinned, where its
-- artifacts live, and how the binary gets onto disk. Every other module
-- asks this one for the binary and fails closed when it is absent.
--
-- Provenance (verified 2026-09-27): the pinned release is LÖVE 11.5
-- "Mysterious Mysteries", taken from the love2d.org front page
-- ("Download LÖVE 11.5"; 12.x exists only as nightlies). Artifacts live on
-- the GitHub release page; each URL below was probed and returned 200.
--
-- Checksum honesty: neither love2d.org nor the GitHub release publishes
-- checksums for 11.5 (probed love-11.5-sha256sums.txt, SHA256SUMS.txt,
-- love-11.5-checksums.txt, checksums.txt, love-11.5-sha256.txt -- all 404).
-- The sha256 values below were computed locally on 2026-09-27 from the
-- downloaded artifacts and are labeled provenance='self-computed'.
-- Cross-check them against the release notes before trusting a new mirror.
local config = require('games.love2d.config')
local shared_util = require('games.shared.util')

local M = {}

M.VERSION = '11.5'
M.CODENAME = 'Mysterious Mysteries'
M.RELEASE_PAGE_URL = 'https://github.com/love2d/love/releases/tag/11.5'
M.VERIFIED_ON = '2026-09-27'

-- Download retry budget: one initial try plus this many retries.
local DOWNLOAD_RETRIES = 3
-- Longest we wait for `love --version` before giving up.
local VERSION_PROBE_TIMEOUT_MS = 15000

---@class Love2dArtifact
---@field file string artifact file name
---@field url string exact download URL (probed 200 on VERIFIED_ON)
---@field sha256 string? self-computed digest (nil when not downloaded)
---@field provenance string how the digest was obtained
---@field purpose string what the artifact is for

---@type table<string, Love2dArtifact>
M.ARTIFACTS = {
    linux = {
        file = 'love-11.5-x86_64.AppImage',
        url = 'https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage',
        sha256 = '65a673406431eff7167a15a032bf7a2e4ba50108e091eb7b176465831f9b5e00',
        provenance = 'self-computed 2026-09-27; no upstream checksum published',
        purpose = 'Linux x86_64 runtime (AppImage; extract for a plain binary)',
    },
    win64 = {
        file = 'love-11.5-win64.zip',
        url = 'https://github.com/love2d/love/releases/download/11.5/love-11.5-win64.zip',
        sha256 = 'ba6e56be2685e53c817749c4a5007f51137136fe5a3ab64920508babc2e74369',
        provenance = 'self-computed 2026-09-27; no upstream checksum published',
        purpose = 'Windows 64-bit runtime for fused releases',
    },
    macos = {
        file = 'love-11.5-macos.zip',
        url = 'https://github.com/love2d/love/releases/download/11.5/love-11.5-macos.zip',
        sha256 = '6795bb3a1656af6a2fdfe741e150787b481886d3a280327a261a3fdded586913',
        provenance = 'self-computed 2026-09-27; no upstream checksum published',
        purpose = 'macOS runtime (love.app) for fused releases',
    },
    android = {
        file = 'love-11.5-android.apk',
        url = 'https://github.com/love2d/love/releases/download/11.5/love-11.5-android.apk',
        sha256 = nil,
        provenance = 'existence probed 2026-09-27; digest not recorded',
        purpose = 'Android runtime (sideload / store pipeline out of scope)',
    },
}

assert(M.VERSION == config.love_version, 'love2d: config.love_version must match versions.VERSION')

---@return string tools root (env LOVE2D_TOOLS_ROOT wins, for tests)
function M.tools_root()
    local override = vim.env.LOVE2D_TOOLS_ROOT
    if override ~= nil and override ~= '' then
        return override
    end
    return vim.fn.expand('~/workspace/tools/love2d')
end

---@return string install dir for the pinned release
function M.install_dir()
    return M.tools_root() .. '/' .. M.VERSION
end

---@param key string artifact key from ARTIFACTS
---@return string? path, nil when the artifact is not on disk
function M.artifact_path(key)
    local artifact = M.ARTIFACTS[key]
    if artifact == nil then
        return nil
    end
    local path = M.install_dir() .. '/artifacts/' .. artifact.file
    if vim.fn.filereadable(path) == 1 then
        return path
    end
    return nil
end

---@return string? executable managed love binary, nil when not installed
function M.binary_path()
    -- Canonical layout written by ensure_installed(); the squashfs-root
    -- fallback is the research-phase extraction (2026-09-27) kept working.
    for _, rel in ipairs({ '/app/AppRun', '/squashfs-root/AppRun' }) do
        local candidate = M.install_dir() .. rel
        if vim.fn.executable(candidate) == 1 then
            return candidate
        end
    end
    return nil
end

---@return string? e.g. '11.5', nil when the binary is missing/unparseable
function M.installed_version()
    local bin = M.binary_path()
    if bin == nil then
        return nil
    end
    local completed = vim.system({ bin, '--version' }, {
        text = true,
        timeout = VERSION_PROBE_TIMEOUT_MS,
    }):wait()
    if completed.code ~= 0 then
        return nil
    end
    -- 'LOVE 11.5 (Mysterious Mysteries)' -> '11.5'
    local version = (completed.stdout or ''):match('LOVE%s+([%d%.]+)')
    if version == nil or version == '' then
        return nil
    end
    return version
end

---@param path string file to hash
---@param expected_sha string lowercase hex digest
---@return boolean ok
---@return string? err
function M.verify_artifact(path, expected_sha)
    assert(type(path) == 'string' and path ~= '')
    assert(type(expected_sha) == 'string' and expected_sha:match('^%x+$') ~= nil)
    if vim.fn.filereadable(path) ~= 1 then
        return false, 'not a readable file: ' .. path
    end
    local completed = vim.system({ 'sha256sum', path }, { text = true }):wait()
    if completed.code ~= 0 then
        return false, 'sha256sum failed for ' .. path
    end
    local actual = (completed.stdout or ''):match('^%x+')
    if actual == nil then
        return false, 'could not parse sha256sum output for ' .. path
    end
    if actual:lower() ~= expected_sha:lower() then
        return false, ('checksum mismatch for %s'):format(path)
    end
    return true, nil
end

---@param artifact Love2dArtifact
---@param dest string destination path
---@return boolean ok
---@return string? err
function M.download(artifact, dest)
    assert(type(artifact) == 'table' and type(artifact.url) == 'string')
    assert(type(dest) == 'string' and dest ~= '')
    vim.fn.mkdir(vim.fs.dirname(dest), 'p')
    local completed = vim.system({
        'curl',
        '-sSL',
        '--retry',
        tostring(DOWNLOAD_RETRIES),
        '--max-time',
        tostring(math.floor(config.download_timeout_ms / 1000)),
        '-o',
        dest,
        artifact.url,
    }, { text = true }):wait()
    if completed.code ~= 0 then
        return false, ('download failed (%s): %s'):format(artifact.url, shared_util.trim(completed.stderr or ''))
    end
    if artifact.sha256 ~= nil then
        return M.verify_artifact(dest, artifact.sha256)
    end
    return true, nil
end

---@param opts? { force?: boolean } force redownloads even when installed
---@return string? binary path
---@return string? err
function M.ensure_installed(opts)
    opts = opts or {}
    local existing = M.binary_path()
    if existing ~= nil and not opts.force then
        return existing, nil
    end
    local artifact = M.ARTIFACTS.linux
    local dest = M.install_dir() .. '/artifacts/' .. artifact.file
    local ok, err = M.download(artifact, dest)
    if not ok then
        return nil, err
    end
    -- Extract the AppImage into install_dir/app so the binary runs without
    -- FUSE. Extraction happens in a temp dir first; we only move it into
    -- place on success.
    local tmp = vim.fn.tempname() .. '-love-extract'
    vim.fn.mkdir(tmp, 'p')
    local extracted = vim.system({ dest, '--appimage-extract' }, { cwd = tmp, text = true }):wait()
    if extracted.code ~= 0 then
        vim.fn.delete(tmp, 'rf')
        return nil, 'AppImage extraction failed'
    end
    local app_dir = M.install_dir() .. '/app'
    vim.fn.delete(app_dir, 'rf')
    local moved = vim.system({ 'mv', tmp .. '/squashfs-root', app_dir }):wait()
    vim.fn.delete(tmp, 'rf')
    if moved.code ~= 0 then
        return nil, 'could not move extracted AppImage into place'
    end
    local marker = {
        version = M.VERSION,
        codename = M.CODENAME,
        artifact_sha256 = artifact.sha256,
        artifact_provenance = artifact.provenance,
        installed_at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    local marker_path = M.install_dir() .. '/INSTALL.json'
    local encoded = vim.json.encode(marker)
    local fh = io.open(marker_path, 'w')
    if fh == nil then
        return nil, 'could not write install marker: ' .. marker_path
    end
    fh:write(encoded)
    fh:close()
    return M.binary_path(), nil
end

---@return string? binary path: env override, PATH, then managed install
function M.find_binary()
    local override = shared_util.env_first(config.env_names)
    if override ~= nil then
        local resolved = shared_util.first_executable({ override })
        if resolved ~= nil then
            return resolved
        end
        vim.notify('LÖVE2D: configured binary is not executable: ' .. override, vim.log.levels.WARN)
    end
    local on_path = shared_util.first_executable(config.binaries)
    if on_path ~= nil then
        return on_path
    end
    return M.binary_path()
end

---@return string? binary path, nil after notifying when nothing is found
function M.require_binary()
    local bin = M.find_binary()
    if bin == nil then
        vim.notify(
            'LÖVE 11.5 binary not found. Run :Love2dInstall (or set LOVE_BIN / add love to $PATH).',
            vim.log.levels.ERROR
        )
    end
    return bin
end

return M
