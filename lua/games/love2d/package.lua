-- #################################################################
-- /qompassai/Diver/lua/games/love2d/package.lua
-- Qompass AI LÖVE2D .love Packager
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
-- Zips a LÖVE project directory into a .love file deterministically:
-- entries are sorted, every staged file gets the same fixed mtime, and
-- zip runs with -X (no UID/GID extras) under TZ=UTC. Identical trees
-- produce byte-identical archives.
--
-- Security: entry names are validated against traversal (`..`, absolute
-- paths, backslashes); per-file and total size caps from config.lua guard
-- against zip bombs; symlinks are skipped, never followed.
local config = require('games.love2d.config')
local shared_util = require('games.shared.util')

local M = {}

-- Deepest directory nesting the walker will descend.
local WALK_DEPTH_MAX = 32
-- Chunk size for binary-safe file copies.
local COPY_CHUNK_BYTES = 65536
-- Longest single zip entry name we accept.
local ENTRY_PATH_MAX = 512

-- Directories never packaged (dev overlay, VCS metadata).
local SKIP_DIRS = {
    ['.love'] = true,
    ['.git'] = true,
}

---@param rel string relative entry name
---@return boolean safe
---@return string? reason
function M.entry_is_safe(rel)
    if type(rel) ~= 'string' or rel == '' then
        return false, 'empty entry name'
    end
    if #rel > ENTRY_PATH_MAX then
        return false, 'entry name too long'
    end
    if rel:sub(1, 1) == '/' then
        return false, 'absolute path: ' .. rel
    end
    if rel:find('\\', 1, true) ~= nil then
        return false, 'backslash in entry name: ' .. rel
    end
    if rel:find('%c') ~= nil then
        return false, 'control character in entry name'
    end
    for segment in rel:gmatch('[^/]+') do
        if segment == '..' then
            return false, 'path traversal: ' .. rel
        end
    end
    return true, nil
end

---@param project_dir string
---@return string[]? sorted relative file paths
---@return string? err
---@return integer skipped_symlinks
local function collect_entries(project_dir)
    local entries, skipped = {}, 0
    -- Explicit stack: { dir, prefix, depth }. No recursion (repo AGENTS.md).
    local stack = { { dir = project_dir, prefix = '', depth = 0 } }
    while #stack > 0 do
        local frame = table.remove(stack)
        if frame.depth > WALK_DEPTH_MAX then
            return nil, 'directory nesting too deep under ' .. frame.prefix, skipped
        end
        local handle = vim.uv.fs_scandir(frame.dir)
        if handle == nil then
            return nil, 'cannot scan directory: ' .. frame.dir, skipped
        end
        local subdirs = {}
        while true do
            local name, ftype = vim.uv.fs_scandir_next(handle)
            if name == nil then
                break
            end
            if #entries + 1 > config.package_file_count_max then
                return nil, 'file count exceeds cap of ' .. config.package_file_count_max, skipped
            end
            local rel = frame.prefix == '' and name or (frame.prefix .. '/' .. name)
            if ftype == 'directory' then
                if not SKIP_DIRS[name] then
                    subdirs[#subdirs + 1] = { dir = frame.dir .. '/' .. name, prefix = rel, depth = frame.depth + 1 }
                end
            elseif ftype == 'file' then
                local safe, reason = M.entry_is_safe(rel)
                if not safe then
                    return nil, reason, skipped
                end
                entries[#entries + 1] = rel
            elseif ftype == 'link' then
                skipped = skipped + 1
            end
        end
        for _, sub in ipairs(subdirs) do
            stack[#stack + 1] = sub
        end
    end
    table.sort(entries)
    return entries, nil, skipped
end

---@param project_dir string
---@param entries string[]
---@param opts? { allow_missing_conf?: boolean }
---@return boolean ok
---@return string? err
function M.validate_project(project_dir, entries, opts)
    opts = opts or {}
    assert(type(project_dir) == 'string' and project_dir ~= '')
    assert(type(entries) == 'table')
    local seen = {}
    for _, rel in ipairs(entries) do
        seen[rel] = true
    end
    if not seen['main.lua'] then
        return false, 'project has no main.lua: ' .. project_dir
    end
    if not seen['conf.lua'] and not opts.allow_missing_conf then
        return false, 'project has no conf.lua (pass allow_missing_conf to skip)'
    end
    local total = 0
    for _, rel in ipairs(entries) do
        local stat = vim.uv.fs_stat(project_dir .. '/' .. rel)
        if stat == nil then
            return false, 'cannot stat: ' .. rel
        end
        if stat.size > config.package_file_size_max_bytes then
            return false, ('file too large (%d bytes): %s'):format(stat.size, rel)
        end
        total = total + stat.size
        if total > config.package_total_size_max_bytes then
            return false, 'project exceeds total size cap'
        end
    end
    return true, nil
end

---@param src string
---@param dest string
---@return boolean ok
---@return string? err
local function copy_file(src, dest)
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

---@param project_dir string
---@param out_love string destination .love path
---@param opts? { allow_missing_conf?: boolean }
---@return string? out path on success
---@return table|string info table on success, error string on failure
function M.package(project_dir, out_love, opts)
    opts = opts or {}
    assert(type(project_dir) == 'string' and project_dir ~= '')
    assert(type(out_love) == 'string' and out_love ~= '')
    if vim.fn.isdirectory(project_dir) ~= 1 then
        return nil, 'not a directory: ' .. project_dir
    end
    local entries, err, skipped = collect_entries(project_dir)
    if entries == nil then
        -- Contract: collect_entries reports an error exactly when it fails.
        return nil, assert(err, 'love2d: collect_entries failed without an error')
    end
    if #entries == 0 then
        return nil, 'project is empty: ' .. project_dir
    end
    local ok, verr = M.validate_project(project_dir, entries, opts)
    if not ok then
        -- Contract: validate_project reports an error exactly when it fails.
        return nil, assert(verr, 'love2d: validate_project failed without an error')
    end
    -- Stage into a temp dir: copies, then fixed mtimes + uniform modes so the
    -- resulting zip is deterministic.
    local stage = vim.fn.tempname() .. '-love-stage'
    vim.fn.mkdir(stage, 'p')
    -- Fixed mtime for 2000-01-01T00:00:00Z (matches config.package_zip_epoch).
    local FIXED_EPOCH = 946684800
    local total_bytes = 0
    local stage_err = nil
    for _, rel in ipairs(entries) do
        local staged = stage .. '/' .. rel
        vim.fn.mkdir(vim.fs.dirname(staged), 'p')
        local cok, cerr = copy_file(project_dir .. '/' .. rel, staged)
        if not cok then
            stage_err = cerr
            break
        end
        vim.uv.fs_chmod(staged, 420) -- 0644
        vim.uv.fs_utime(staged, FIXED_EPOCH, FIXED_EPOCH)
        local stat = vim.uv.fs_stat(staged)
        if stat == nil then
            stage_err = 'could not stat staged file: ' .. rel
            break
        end
        total_bytes = total_bytes + stat.size
    end
    if stage_err ~= nil then
        vim.fn.delete(stage, 'rf')
        return nil, stage_err
    end
    vim.fn.mkdir(vim.fs.dirname(out_love), 'p')
    vim.fn.delete(out_love)
    local list_text = table.concat(entries, '\n') .. '\n'
    local zipped = vim.system(
        { 'zip', '-X', '-9', '-@', out_love },
        { cwd = stage, stdin = list_text, text = true, env = { TZ = 'UTC' } }
    ):wait()
    vim.fn.delete(stage, 'rf')
    if zipped.code ~= 0 then
        return nil, 'zip failed: ' .. shared_util.trim(zipped.stderr or '')
    end
    local stat = vim.uv.fs_stat(out_love)
    if stat == nil then
        return nil, 'zip reported success but no archive appeared'
    end
    return out_love,
        {
            entries = #entries,
            bytes = stat.size,
            source_bytes = total_bytes,
            skipped_symlinks = skipped,
        }
end

return M
