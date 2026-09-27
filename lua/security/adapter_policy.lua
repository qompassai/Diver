--- Adapter launch policy — the "who gets a badge" rule for debug adapters.
---
--- Plain-language version: when Neovim launches a debug adapter (the helper
--- program a debugger talks to), that program inherits the editor's
--- surroundings: its environment variables, and the workspace's
--- .vscode/launch.json file. Both can carry traps. This module is the badge
--- desk. filter_env() builds a fresh, minimal environment from an allowlist
--- so a poisoned variable never reaches the adapter. redact() scrubs
--- secret-looking values out of log strings. trust_workspace() decides
--- whether a workspace directory is safe enough to even read
--- .vscode/launch.json from. A sibling DAP descriptor calls these; this
--- module shows no UI, prompts for nothing, and never launches anything.
---@module 'security.adapter_policy'

local M = {}

local REDACTED = '[REDACTED]' -- replacement marker for scrubbed values.
local MODE_WORLD_WRITABLE = 2 -- S_IWOTH bit in a uv fs_stat mode field.

---Whole secret-bearing key names (checked case-insensitively), plus the
---*_SUFFIX forms handled in is_secret_key: *_TOKEN, *_SECRET, *_KEY,
---*_PASSWORD. A bare "key" alone (not a suffix) still redacts — e.g. an
---env entry literally named KEY is never passed through.
---@type table<string, boolean>
local SECRET_WORDS = {
    token = true,
    secret = true,
    key = true,
    password = true,
    passwd = true,
}

---@param name string Key name to inspect.
---@return boolean
local function is_secret_key(name)
    local lower = name:lower()
    if SECRET_WORDS[lower] then
        return true
    end
    -- Lua patterns have no alternation, so the suffixes are matched singly.
    return lower:match('_token$') ~= nil
        or lower:match('_secret$') ~= nil
        or lower:match('_key$') ~= nil
        or lower:match('_password$') ~= nil
end

---@param stat uv.fs_stat.result Stat result to inspect.
---@return boolean
local function is_world_writable(stat)
    return bit.band(stat.mode, MODE_WORLD_WRITABLE) ~= 0
end

---Build a new environment table containing only allowlisted entries that
---are present in env. The input table is never mutated; values are copied
---by reference (strings are immutable, so this shares nothing mutable).
---@param env table<string,string> Source environment (e.g. vim.fn.environ()).
---@param allowlist string[] Variable names permitted through.
---@return table<string,string>|nil filtered Fresh table, or nil on bad input.
---@return string|nil err Human-readable reason on expected failure.
function M.filter_env(env, allowlist)
    if type(env) ~= 'table' then
        return nil, 'filter_env expects env to be a table, got ' .. type(env)
    end
    if type(allowlist) ~= 'table' then
        return nil, 'filter_env expects allowlist to be a table, got ' .. type(allowlist)
    end
    local filtered = {}
    for index, name in ipairs(allowlist) do
        if type(name) ~= 'string' then
            return nil, 'filter_env allowlist[' .. index .. '] must be a string, got ' .. type(name)
        end
        local value = env[name]
        if value ~= nil then
            if type(value) ~= 'string' then
                return nil, 'filter_env env[' .. name .. '] must be a string, got ' .. type(value)
            end
            filtered[name] = value
        end
    end
    return filtered, nil
end

---Scrub secret-looking values from a string. Pure function: no I/O, no
---mutation, safe to call on log lines, command echoes, and error text.
---
---Pattern list (documented, in application order):
---  1. "Authorization: Bearer <token>" (canonical header casing) -> the
---     token run is replaced with [REDACTED].
---  2. KEY=value and KEY: value pairs where KEY is secret-looking (whole
---     words token/secret/key/password/passwd, or a *_TOKEN / *_SECRET /
---     *_KEY / *_PASSWORD suffix, case-insensitive) -> the value run (up
---     to the next whitespace) is replaced with [REDACTED]; spacing and
---     the separator are preserved.
---This is a heuristic tripwire, not a secret detector: unusual shapes
---(quoted multi-word values, JSON strings) are out of scope by design.
---@param s string
---@return string|nil cleaned Redacted copy of s, or nil on bad input.
---@return string|nil err Human-readable reason on expected failure.
function M.redact(s)
    if type(s) ~= 'string' then
        return nil, 'redact expects a string, got ' .. type(s)
    end
    local cleaned = s:gsub('Authorization:%s+Bearer%s+%S+', 'Authorization: Bearer ' .. REDACTED)
    cleaned = cleaned:gsub('([A-Za-z_][%w_%-%.]*)(%s*[:=]%s*)(%S+)', function(key, sep, value)
        if is_secret_key(key) then
            return key .. sep .. REDACTED
        end
        return key .. sep .. value
    end)
    return cleaned, nil
end

---Decide whether dir is trusted enough to read .vscode/launch.json from.
---Conservative policy, checked in order; the first failure wins and its
---reason is returned so the presentation layer can explain the refusal:
---  1. dir must be a non-empty string (no prompting or guessing here —
---     the presentation layer decides how to ask the user).
---  2. dir must be $HOME itself or sit under $HOME/. Anything else
---     (notably /tmp and other shared trees) is untrusted by default.
---  3. dir itself must not be world-writable: another local user could
---     otherwise plant or swap files in it.
---  4. .vscode/launch.json, when present, must not be world-writable: a
---     shared-writable launch file is a planted-argument vector (see the
---     "no shell interpolation of workspace-controlled launch arguments"
---     baseline — we do not even *read* it unless this passes).
---fs_stat follows symlinks, so a symlink under $HOME pointing at a
---world-writable target still fails checks 3/4; the $HOME-prefix check in
---step 2 is on the given path string.
---@param dir string Workspace directory to evaluate.
---@return boolean trusted True only when every check passes.
---@return string reason Which check passed or failed.
function M.trust_workspace(dir)
    if type(dir) ~= 'string' or dir == '' then
        return false, 'trust_workspace expects a non-empty directory string'
    end
    local home = vim.env.HOME
    if type(home) ~= 'string' or home == '' then
        return false, 'cannot determine $HOME'
    end
    if dir ~= home and dir:sub(1, #home + 1) ~= home .. '/' then
        return false, 'workspace is not under $HOME'
    end
    local dir_stat = vim.uv.fs_stat(dir)
    if dir_stat == nil or dir_stat.type ~= 'directory' then
        return false, 'workspace is not an accessible directory'
    end
    if is_world_writable(dir_stat) then
        return false, 'workspace directory is world-writable'
    end
    local launch_stat = vim.uv.fs_stat(dir .. '/.vscode/launch.json')
    if launch_stat ~= nil and is_world_writable(launch_stat) then
        return false, 'workspace .vscode/launch.json is world-writable'
    end
    return true, 'workspace is under $HOME, not world-writable, launch.json check passed'
end

---Conservative default environment allowlist for debug adapters. Rationale:
---  PATH — adapters resolve their helper binaries through PATH; the caller
---    is expected to supply a sane one.
---  HOME — adapters read their own per-user settings from ~/.config.
---  TERM — subprocesses use TERM to pick output formatting; harmless.
---  LANG / LC_* — locale only affects message language and collation.
---Explicitly EXCLUDED (dynamic-linker injection risk): LD_PRELOAD and
---LD_LIBRARY_PATH are read by the dynamic linker before main() runs, so a
---poisoned value silently loads attacker code into the adapter process;
---DYLD_* are the macOS equivalents (DYLD_INSERT_LIBRARIES and friends).
---Returns a fresh table on every call so callers cannot poison a shared one.
---@return string[]
function M.default_allowlist()
    return {
        'PATH',
        'HOME',
        'TERM',
        'LANG',
        'LC_ALL',
        'LC_CTYPE',
        'LC_MESSAGES',
        'LC_NUMERIC',
        'LC_TIME',
        'LC_COLLATE',
    }
end

return M
