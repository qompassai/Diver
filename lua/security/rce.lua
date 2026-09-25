--- RCE guard — the "stranger-danger" rule for running other programs.
---
--- Plain-language version: sometimes Neovim needs to ask the computer to run
--- another program, like `git`. There are two ways to ask. The safe way is to
--- hand over a *list* of words: "run git, with the words status and
--- --porcelain". The dangerous way is to hand over one *sentence* and let a
--- shell figure it out: "run this: git status --porcelain". The sentence way
--- is dangerous because sneaky words like `$(`, backticks, `;`, `|` and `&`
--- suddenly get a second, powerful meaning. This module is the bouncer: it
--- only accepts word lists, it refuses sentences, and it can spot the sneaky
--- words hiding inside text so we never feed them to a shell.
---
--- Sources: `:h vim.system` (cmd is string|string[]; argv form never invokes a
--- shell), `:h shellescape()` (the only sanctioned way to embed one value in
--- a shell string -- and we avoid shell strings entirely instead).
---@module 'security.rce'

local M = {}

local OUTPUT_BYTES_MAX = 1048576 -- 1 MiB cap on captured subprocess output.
local TIMEOUT_MS_DEFAULT = 30000 -- 30 s default wait bound.
local TIMEOUT_MS_MAX = 300000 -- 5 min hard ceiling on any single wait.
local TIMEOUT_EXIT_CODE = 124 -- vim.system's "killed after timeout" code.
local FINDINGS_MAX = 64 -- cap on scan_string findings returned.
local OCCURRENCES_MAX = 16 -- cap on matches reported per metacharacter.

---@class security.RceExecOptions
---@field timeout_ms? integer Max time to wait for the child (default 30000, hard max 300000).
---@field cwd? string Working directory for the child process.
---@field env? table<string,string> Extra environment variables for the child.

---@class security.RceFinding
---@field kind string Human-readable metacharacter name.
---@field at integer 1-based byte offset of the match in the scanned string.

-- Shell metacharacters that gain a second meaning when a shell re-reads a
-- string. Matched with plain (non-pattern) search so nothing here is itself
-- interpreted as a pattern.
---@type { kind: string, token: string }[]
local METACHARACTERS = {
    { kind = 'command substitution', token = '$(' },
    { kind = 'command substitution', token = ')' },
    { kind = 'backtick substitution', token = '`' },
    { kind = 'command separator', token = ';' },
    { kind = 'pipe', token = '|' },
    { kind = 'background operator', token = '&' },
}

---Validate that argv is a non-empty list of strings.
---@param argv any
---@return string[]|nil argv_copy A private copy safe to hand to vim.system.
---@return string|nil err
local function validate_argv(argv)
    if type(argv) == 'string' then
        return nil, 'safe_exec refuses string commands (shell-injection risk): pass an argv list'
    end
    if type(argv) ~= 'table' then
        return nil, 'safe_exec expects an argv table, got ' .. type(argv)
    end
    local argc = #argv
    if argc < 1 then
        return nil, 'safe_exec expects a non-empty argv table'
    end
    -- Copy so a caller mutating the table after the call cannot change the spawn.
    local argv_copy = {}
    for index = 1, argc do
        if type(argv[index]) ~= 'string' then
            return nil, 'safe_exec argv[' .. index .. '] must be a string, got ' .. type(argv[index])
        end
        argv_copy[index] = argv[index]
    end
    return argv_copy, nil
end

---Run a subprocess from an argv list. String commands are refused outright.
---This is the only sanctioned way for security.* code to spawn processes:
---vim.system with a string[] cmd never invokes a shell (see :h vim.system).
---@param argv string|string[] Command name plus arguments, e.g. { 'git', 'status', '--', path }.
---A bare string is refused (shell-injection risk) and reported as an error.
---@param opts? security.RceExecOptions
---@return vim.SystemCompleted|nil result Completed process result on success.
---@return string|nil err Human-readable reason on expected failure.
function M.safe_exec(argv, opts)
    local spawn_argv, argv_err = validate_argv(argv)
    if argv_err ~= nil then
        return nil, argv_err
    end
    assert(spawn_argv ~= nil, 'validate_argv returned no error but no argv')

    opts = opts or {}
    local timeout_ms = opts.timeout_ms
    if timeout_ms == nil then
        timeout_ms = TIMEOUT_MS_DEFAULT
    end
    if type(timeout_ms) ~= 'number' or timeout_ms < 1 or timeout_ms > TIMEOUT_MS_MAX then
        return nil, 'timeout_ms must be a number in [1, ' .. TIMEOUT_MS_MAX .. ']'
    end

    -- vim.system throws when the command cannot be started; capture and
    -- propagate instead of letting it escape (no bare pcall swallowing).
    local spawn_ok, system_obj = pcall(vim.system, spawn_argv, {
        text = true,
        cwd = opts.cwd,
        env = opts.env,
    })
    if not spawn_ok or system_obj == nil then
        return nil, 'spawn failed: ' .. tostring(system_obj)
    end

    -- wait() force-kills with SIGKILL on timeout and reports code 124.
    local result = system_obj:wait(timeout_ms)
    if result == nil or result.code == TIMEOUT_EXIT_CODE then
        return nil, 'process timed out after ' .. timeout_ms .. ' ms and was killed'
    end

    -- Bound what we hand back. The child already exited, so this only caps
    -- retained memory, never the child's behavior.
    if result.stdout ~= nil and #result.stdout > OUTPUT_BYTES_MAX then
        result.stdout = result.stdout:sub(1, OUTPUT_BYTES_MAX)
    end
    if result.stderr ~= nil and #result.stderr > OUTPUT_BYTES_MAX then
        result.stderr = result.stderr:sub(1, OUTPUT_BYTES_MAX)
    end
    return result, nil
end

---Scan a string for shell metacharacters. This is a heuristic tripwire, not
---a parser: it flags `$(`, `)`, backticks, `;`, `|` and `&` wherever they
---appear, quoted or not. Callers decide whether a finding is dangerous in
---context (e.g. a `;` inside a quoted argument is fine; a `$(` in a value
---destined for :terminal is not).
---@param s string
---@return security.RceFinding[]|nil findings Empty table when clean.
---@return string|nil err
function M.scan_string(s)
    if type(s) ~= 'string' then
        return nil, 'scan_string expects a string, got ' .. type(s)
    end
    local findings = {}
    local finding_count = 0
    for _, meta in ipairs(METACHARACTERS) do
        local start_at = 1
        local occurrences = 0
        while finding_count < FINDINGS_MAX and occurrences < OCCURRENCES_MAX do
            local found_at = s:find(meta.token, start_at, true)
            if found_at == nil then
                break
            end
            finding_count = finding_count + 1
            occurrences = occurrences + 1
            findings[finding_count] = { kind = meta.kind, at = found_at }
            start_at = found_at + 1
        end
    end
    return findings, nil
end

return M
