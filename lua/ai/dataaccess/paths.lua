-- /qompassai/Diver/lua/ai/dataaccess/paths.lua
-- Qompass AI Data Access Path Validation (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Validates filesystem paths before a file-backed data adapter (sqlite,
-- duckdb) or a credential-file field (mysql defaults_file, psql
-- passfile) ever sees them.
--
-- Plain words: this is the bouncer for file paths. It only lets in
-- absolute paths that stay where they point (no ".." escapes), carry
-- no shell metacharacters, and -- for databases -- end in an extension
-- the adapter actually understands. Credential files get one extra
-- rule: they must already exist and be readable only by their owner
-- (mode 0600 or 0400), so a world-readable password file is refused
-- instead of used.
--
-- Nothing here touches the network or spawns processes.

local M = {}

local PATH_BYTES_MAX = 4096
local EXTENSION_BYTES_MAX = 16

-- Characters that are meaningless in a legitimate database path but
-- meaningful to a shell: rejecting them keeps a path that ever leaks
-- into a log line or an error message inert.
local META_PATTERN = '[;|&$`"\'\\\n\r\t*?~#%[%]{}()<>!^]'

local FILE_EXTENSIONS = {
    sqlite = { db = true, sqlite = true, sqlite3 = true },
    duckdb = { db = true, ddb = true, duckdb = true },
}

---@param value any
---@return boolean
local function is_clean_string(value)
    return type(value) == 'string' and value ~= '' and value:find('%z') == nil
end

---@param path string Assumed non-empty, NUL-free.
---@return boolean
local function has_dotdot_segment(path)
    for segment in path:gmatch('[^/]+') do
        if segment == '..' then
            return true
        end
    end
    return false
end

---@param path string Assumed validated.
---@return string extension Lowercased, without the dot.
local function extension_of(path)
    local ext = path:match('%.([^%.%/]+)$') or ''
    return ext:lower()
end

---Validate a database file path for a file-backed adapter. Rejects
---relative paths, ".." escapes, NUL bytes, shell metacharacters, and
---extensions the adapter does not claim.
---@param adapter_name string 'sqlite' or 'duckdb'.
---@param path any Caller-supplied path.
---@return boolean ok
---@return string? err
function M.validate_db_path(adapter_name, path)
    assert(type(adapter_name) == 'string', 'adapter_name must be a string')
    local known = FILE_EXTENSIONS[adapter_name]
    if known == nil then
        return false, 'not a file-backed adapter: ' .. adapter_name
    end
    if not is_clean_string(path) then
        return false, 'path must be a non-empty string without NUL bytes'
    end
    if #path > PATH_BYTES_MAX then
        return false, 'path exceeds ' .. PATH_BYTES_MAX .. ' bytes'
    end
    if path:sub(1, 1) ~= '/' then
        return false, 'path must be absolute'
    end
    if has_dotdot_segment(path) then
        return false, 'path must not contain ".." segments'
    end
    if path:find(META_PATTERN) ~= nil then
        return false, 'path contains rejected metacharacters'
    end
    local ext = extension_of(path)
    if #ext > EXTENSION_BYTES_MAX or not known[ext] then
        return false, 'extension .' .. ext .. ' is not a ' .. adapter_name .. ' database'
    end
    return true, nil
end

---Validate a credential file (mysql defaults_file, psql passfile).
---The file must exist, be a regular file, and grant no permissions to
---group or others; anything looser is refused rather than used.
---@param path any Caller-supplied path.
---@return boolean ok
---@return string? err
function M.validate_credential_file(path)
    if not is_clean_string(path) then
        return false, 'credential file path must be a non-empty string without NUL bytes'
    end
    if #path > PATH_BYTES_MAX then
        return false, 'credential file path exceeds ' .. PATH_BYTES_MAX .. ' bytes'
    end
    if path:sub(1, 1) ~= '/' then
        return false, 'credential file path must be absolute'
    end
    if has_dotdot_segment(path) then
        return false, 'credential file path must not contain ".." segments'
    end
    if path:find(META_PATTERN) ~= nil then
        return false, 'credential file path contains rejected metacharacters'
    end
    local stat = vim.uv.fs_stat(path)
    if stat == nil then
        return false, 'credential file does not exist: ' .. path
    end
    if stat.type ~= 'file' then
        return false, 'credential file is not a regular file: ' .. path
    end
    local mode = stat.mode or 0
    -- 0o777 & mode keeps only the permission bits; 0o077 masks the
    -- group/other bits, which must all be zero (0600 or 0400 pass).
    if bit.band(mode, 63) ~= 0 then
        return false, 'credential file must not be readable by group or others: ' .. path
    end
    return true, nil
end

return M
