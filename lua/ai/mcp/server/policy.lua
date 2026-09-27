-- /qompassai/Diver/lua/ai/mcp/server/policy.lua
-- Qompass AI MCP Server Policy (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Fail-closed policy for the MCP server: path scoping, per-tool approval
-- classes, run_command argv[0] allowlist, and audit logging.
--
-- Plain words: every path argument is normalized, absolutized, and checked
-- against the workspace roots before anything touches the filesystem; a
-- `..` that climbs out of the roots is rejected, symlinks are resolved and
-- re-checked, and secret locations (~/.ssh and friends) are denied even
-- when they sit inside a root. Writes need an explicit confirmation grant;
-- run_command only runs bare argv[0] names from an allowlist that defaults
-- to empty (deny-all), and commands never go through a shell.
--
-- Refusals return (nil, { code, message }) and never raise: code -32602
-- for malformed/out-of-scope input, -32000 for policy denials. Audit
-- logging never throws and never hard-depends on ai.security.auditlog.

local M = {}

local PATH_LENGTH_MAX = 4096
local ARG_LENGTH_MAX = 4096
local ARG_COUNT_MAX = 32

---Bounds for the run_command timeout_ms argument. Exported so the tool
---schema shares one source of truth with the policy module.
M.COMMAND_TIMEOUT_MS_MIN = 1000
M.COMMAND_TIMEOUT_MS_MAX = 120000

local INVALID_PARAMS_CODE = -32602
local POLICY_DENIED_CODE = -32000

local SECRET_DIR_PARTS = {
    ['.ssh'] = true,
    ['.aws'] = true,
    ['.gnupg'] = true,
    ['.pki'] = true,
}
local SECRET_BASENAMES = {
    ['.env'] = true,
    ['id_rsa'] = true,
    ['id_dsa'] = true,
    ['id_ecdsa'] = true,
    ['id_ed25519'] = true,
}
local SECRET_SUFFIXES = { '.pem', '.key' }

local APPROVAL_AUTO = 'auto'
local APPROVAL_CONFIRM = 'confirm'
local APPROVAL_DENY = 'deny'

-- Reads are auto-approved; everything that mutates or reaches the outside
-- world needs an explicit grant. Unknown tools are denied, never defaulted.
local TOOL_CLASS = {
    read_file = APPROVAL_AUTO,
    list_files = APPROVAL_AUTO,
    search_text = APPROVAL_AUTO,
    get_diagnostics = APPROVAL_AUTO,
    write_file = APPROVAL_CONFIRM,
    edit_file = APPROVAL_CONFIRM,
    run_command = APPROVAL_CONFIRM,
}

---@class McpPolicyError
---@field code integer -32602 for bad input, -32000 for policy denial.
---@field message string Human-readable refusal reason.

---@class McpPolicyOpts
---@field roots string[]? Absolute workspace roots; defaults to cwd.
---@field confirm_grants table<string, boolean>? Static per-tool write approval.
---@field grant_token string? Token compared against tools/call `_meta.grant`.
---@field run_allowlist string[]? Bare argv[0] names; default is deny-all.
---@field realpath fun(path: string): string?? Symlink resolver; nil disables.

---@param code integer
---@param message string
---@return McpPolicyError
local function policy_error(code, message)
    return { code = code, message = message }
end

---@return string
local function default_cwd()
    if vim ~= nil and vim.fn ~= nil and vim.fn.getcwd ~= nil then
        local ok, cwd = pcall(vim.fn.getcwd)
        if ok and type(cwd) == 'string' and cwd ~= '' then
            return cwd
        end
    end
    return os.getenv('PWD') or '/tmp'
end

-- Lexically collapse `.` and `..` without touching the filesystem, so the
-- root check below sees the true shape of the path. A `..` past the
-- filesystem root stays at the root and then fails the root check.
---@param path string
---@return string
local function collapse(path)
    local is_abs = path:sub(1, 1) == '/'
    local parts = {}
    for part in path:gmatch('[^/]+') do
        if part == '..' then
            if #parts > 0 and parts[#parts] ~= '..' then
                parts[#parts] = nil
            elseif not is_abs then
                parts[#parts + 1] = '..'
            end
        elseif part ~= '.' then
            parts[#parts + 1] = part
        end
    end
    local out = table.concat(parts, '/')
    if is_abs then
        return '/' .. out
    end
    return out == '' and '.' or out
end

---@return fun(path: string): string? realpath or nil when unavailable
local function default_realpath()
    if vim ~= nil and vim.uv ~= nil and vim.uv.fs_realpath ~= nil then
        return function(path)
            local ok, resolved = pcall(vim.uv.fs_realpath, path)
            if ok and type(resolved) == 'string' then
                return resolved
            end
            return nil
        end
    end
    return nil
end

local config = {
    roots = {},
    confirm_grants = {},
    grant_token = nil,
    run_allowlist = {},
    realpath = default_realpath(),
}

-- Idempotent: re-setup replaces the whole policy atomically.
---@param opts McpPolicyOpts?
---@return boolean
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'opts must be a table')
    opts = opts or {}
    local roots = {}
    if opts.roots ~= nil then
        assert(type(opts.roots) == 'table', 'roots must be an array of strings')
        for _, root in ipairs(opts.roots) do
            assert(type(root) == 'string' and root ~= '', 'each root must be a non-empty string')
            local abs = root:sub(1, 1) == '/' and root or (default_cwd() .. '/' .. root)
            roots[#roots + 1] = collapse(abs)
        end
    end
    if #roots == 0 then
        roots[1] = collapse(default_cwd())
    end
    local grants = {}
    if opts.confirm_grants ~= nil then
        assert(type(opts.confirm_grants) == 'table', 'confirm_grants must be a table')
        for tool, allowed in pairs(opts.confirm_grants) do
            grants[tool] = allowed and true or false
        end
    end
    local allowlist = {}
    if opts.run_allowlist ~= nil then
        assert(type(opts.run_allowlist) == 'table', 'run_allowlist must be an array')
        for _, name in ipairs(opts.run_allowlist) do
            assert(type(name) == 'string' and name ~= '', 'allowlist entries must be strings')
            allowlist[name] = true
        end
    end
    local token = opts.grant_token
    if token ~= nil then
        assert(type(token) == 'string' and token ~= '', 'grant_token must be a non-empty string')
    end
    local realpath = opts.realpath
    if realpath == nil then
        realpath = default_realpath()
    end
    config = {
        roots = roots,
        confirm_grants = grants,
        grant_token = token,
        run_allowlist = allowlist,
        realpath = realpath,
    }
    return true
end

---@return string[] copy of the configured roots
function M.roots()
    local out = {}
    for _, root in ipairs(config.roots) do
        out[#out + 1] = root
    end
    return out
end

---@param abs string collapsed absolute path
---@return boolean ok
---@return integer? code
---@return string? message
local function check_scoped(abs)
    local rooted = false
    for _, root in ipairs(config.roots) do
        if abs == root or abs:sub(1, #root + 1) == root .. '/' then
            rooted = true
            break
        end
    end
    if not rooted then
        return false, INVALID_PARAMS_CODE, 'path escapes workspace roots'
    end
    for part in abs:gmatch('[^/]+') do
        if SECRET_DIR_PARTS[part] then
            return false, POLICY_DENIED_CODE, 'denied: path under secret directory .' .. part
        end
    end
    local base = abs:match('([^/]+)$') or ''
    if SECRET_BASENAMES[base] then
        return false, POLICY_DENIED_CODE, 'denied: secret file name ' .. base
    end
    for _, suffix in ipairs(SECRET_SUFFIXES) do
        if #base > #suffix and base:sub(-#suffix) == suffix then
            return false, POLICY_DENIED_CODE, 'denied: credential file suffix ' .. suffix
        end
    end
    return true
end

-- Normalize, absolutize (relative paths anchor at the first root), and
-- scope a caller-supplied path. Symlinks are resolved and re-checked so a
-- link inside the roots cannot point outside them.
---@param path string
---@return string? scoped absolute path
---@return McpPolicyError? err
function M.scope_path(path)
    if type(path) ~= 'string' or path == '' then
        return nil, policy_error(INVALID_PARAMS_CODE, 'path must be a non-empty string')
    end
    if #path > PATH_LENGTH_MAX then
        local msg = 'path exceeds ' .. PATH_LENGTH_MAX .. ' bytes'
        return nil, policy_error(INVALID_PARAMS_CODE, msg)
    end
    if path:find('%c') then
        return nil, policy_error(INVALID_PARAMS_CODE, 'path contains control characters')
    end
    local abs = path:sub(1, 1) == '/' and collapse(path) or collapse(config.roots[1] .. '/' .. path)
    local ok, code, message = check_scoped(abs)
    if not ok then
        return nil, policy_error(code, message)
    end
    if config.realpath ~= nil then
        local resolved = config.realpath(abs)
        if resolved ~= nil and resolved ~= abs then
            local ok2, code2, message2 = check_scoped(collapse(resolved))
            if not ok2 then
                return nil, policy_error(code2, 'symlink target denied: ' .. message2)
            end
            return collapse(resolved)
        end
    end
    return abs
end

-- Approval class gate. Headless servers cannot prompt, so `confirm` tools
-- are denied unless the operator pre-approved them at setup or the call
-- carries the configured grant token in `_meta.grant`.
---@param tool string
---@param meta table?
---@return boolean allowed
---@return string? reason
function M.check_approval(tool, meta)
    local class = TOOL_CLASS[tool] or APPROVAL_DENY
    if class == APPROVAL_AUTO then
        return true
    end
    if class == APPROVAL_DENY then
        return false, 'tool denied by policy: ' .. tostring(tool)
    end
    if config.confirm_grants[tool] then
        return true
    end
    if
        type(meta) == 'table'
        and type(meta.grant) == 'string'
        and config.grant_token ~= nil
        and meta.grant == config.grant_token
    then
        return true
    end
    return false, 'tool requires a confirmation grant: ' .. tostring(tool)
end

-- Validate a run_command argv: dense string array, bounded, no NUL bytes,
-- bare argv[0] (no `/`, so PATH resolution only) present in the allowlist,
-- optional cwd scoped like any other path. Never a shell string.
---@param argv table
---@param cwd string?
---@return { argv: string[], cwd: string? }? checked
---@return McpPolicyError? err
function M.check_command(argv, cwd)
    if type(argv) ~= 'table' then
        return nil, policy_error(INVALID_PARAMS_CODE, 'cmd must be an argv array')
    end
    local count = #argv
    if count < 1 or count > ARG_COUNT_MAX then
        local msg = 'cmd must have 1..' .. ARG_COUNT_MAX .. ' elements'
        return nil, policy_error(INVALID_PARAMS_CODE, msg)
    end
    local dense = 0
    for key in pairs(argv) do
        if type(key) ~= 'number' or key < 1 or key > count or key % 1 ~= 0 then
            return nil, policy_error(INVALID_PARAMS_CODE, 'cmd must be a dense array')
        end
        dense = dense + 1
    end
    if dense ~= count then
        return nil, policy_error(INVALID_PARAMS_CODE, 'cmd must be a dense array')
    end
    for _, part in ipairs(argv) do
        if type(part) ~= 'string' or part == '' then
            return nil, policy_error(INVALID_PARAMS_CODE, 'cmd elements must be non-empty strings')
        end
        if #part > ARG_LENGTH_MAX then
            local msg = 'cmd element exceeds ' .. ARG_LENGTH_MAX .. ' bytes'
            return nil, policy_error(INVALID_PARAMS_CODE, msg)
        end
        if part:find('%z') then
            return nil, policy_error(INVALID_PARAMS_CODE, 'cmd element contains a NUL byte')
        end
    end
    local program = argv[1]
    if program:find('/', 1, true) then
        local msg = 'argv[0] must be a bare command name, not a path'
        return nil, policy_error(INVALID_PARAMS_CODE, msg)
    end
    if not config.run_allowlist[program] then
        return nil, policy_error(POLICY_DENIED_CODE, 'command not in allowlist: ' .. program)
    end
    local scoped_cwd = nil
    if cwd ~= nil then
        local resolved, cerr = M.scope_path(cwd)
        if resolved == nil then
            return nil, cerr
        end
        scoped_cwd = resolved
    end
    return { argv = argv, cwd = scoped_cwd }
end

-- Append one audit record. Never throws and never hard-depends on
-- ai.security.auditlog: a missing or broken audit module degrades to a
-- false return, never a failed tool call.
---@param tool string
---@param target string?
---@param decision string?
---@return boolean recorded
function M.audit(tool, target, decision)
    local ok, auditlog = pcall(require, 'ai.security.auditlog')
    if not ok or type(auditlog) ~= 'table' or type(auditlog.append) ~= 'function' then
        return false
    end
    local recorded, result = pcall(auditlog.append, {
        tool = tostring(tool),
        target = tostring(target or ''),
        via = 'mcp-server',
        decision = tostring(decision or ''),
    })
    return recorded and result == true
end

return M
