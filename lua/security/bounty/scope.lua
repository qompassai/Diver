-- scope.lua
--
-- Scope intake: pull program scopes from bbscope and file them on disk.
--
-- Plain language: before you test anything, you need the written permission
-- slip -- which systems a program allows you to touch. This module asks
-- bbscope for those slips (it aggregates HackerOne, Bugcrowd, Intigriti,
-- YesWeHack, and Immunefi) and files them under
-- ~/security/bugbounties/scope/, one file per program.
---@module 'security.bounty.scope'

local M = {}

---Platforms bbscope can poll. These are bbscope's own subcommand names.
M.platforms = { 'h1', 'bc', 'it', 'ywh', 'immunefi' }

---Directory holding one scope file per program.
---@return string
function M.dir()
    return vim.fn.expand('~/security/bugbounties/scope')
end

---Scope file for one program slug.
---@param program string Program slug, e.g. 'h1-cloudflare'.
---@return string
local function scope_path(program)
    assert(type(program) == 'string' and program ~= '', 'scope: program must be a nonempty string')
    assert(
        program:match('^[A-Za-z0-9_%.%-]+$'),
        'scope: program must be path-safe (letters, digits, _, ., -)'
    )
    return M.dir() .. '/' .. program .. '.txt'
end

---@class security.bounty.ScopeEntry
---@field target string In-scope target (domain, wildcard, URL, CIDR...).
---@field description string Program-supplied description (may be '').
---@field program_url string URL of the program page (may be '').

---Poll one platform with bbscope and return its scope entries.
---Synchronous: bbscope polls take seconds, and the caller asked for scope.
---@param platform string One of M.platforms.
---@param opts? { bbp_only?: boolean } When true, only programs paying money.
---@return security.bounty.ScopeEntry[] entries
function M.poll(platform, opts)
    opts = opts or {}
    local ok_platform = false
    for _, p in ipairs(M.platforms) do
        if p == platform then
            ok_platform = true
            break
        end
    end
    assert(ok_platform, "scope.poll: unknown platform '" .. tostring(platform) .. "'")

    local argv = { 'bbscope', 'poll', platform, '-o', 'tdu', '-d', '\t' }
    if opts.bbp_only then
        argv[#argv + 1] = '--bbp-only'
    end
    -- Private programs need credentials from ~/.bbscope.yaml; without them
    -- bbscope returns only public scope. That is the safe default.
    local result = vim.system(argv, { text = true }):wait(180000)
    assert(result.code == 0, 'scope.poll: bbscope failed: ' .. (result.stderr or ''))
    local entries = {}
    for line in (result.stdout or ''):gmatch('[^\n]+') do
        local target, description, program_url = line:match('^([^\t]*)\t([^\t]*)\t([^\t]*)$')
        if target ~= nil and target ~= '' then
            entries[#entries + 1] = {
                target = target,
                description = description or '',
                program_url = program_url or '',
            }
        end
    end
    return entries
end

---File one program's scope entries to disk.
---@param program string Program slug.
---@param entries security.bounty.ScopeEntry[] Entries from M.poll.
---@return string path The scope file written.
function M.save(program, entries)
    assert(type(entries) == 'table', 'scope.save: entries must be a table')
    local path = scope_path(program)
    vim.fn.mkdir(M.dir(), 'p')
    local lines = {
        '# scope for ' .. program,
        '# fetched at ' .. os.date('!%Y-%m-%dT%H:%M:%SZ'),
        '# format: target <TAB> description <TAB> program_url',
    }
    for _, e in ipairs(entries) do
        assert(type(e.target) == 'string', 'scope.save: entry target must be a string')
        lines[#lines + 1] = e.target .. '\t' .. (e.description or '') .. '\t' .. (e.program_url or '')
    end
    vim.fn.writefile(lines, path)
    return path
end

---Read a filed scope back.
---@param program string Program slug.
---@return security.bounty.ScopeEntry[] entries
function M.load(program)
    local path = scope_path(program)
    assert(vim.uv.fs_stat(path) ~= nil, "scope.load: no scope file for '" .. program .. "' (run :BountyScope first)")
    local entries = {}
    for _, line in ipairs(vim.fn.readfile(path)) do
        if line:sub(1, 1) ~= '#' and line ~= '' then
            local target, description, program_url = line:match('^([^\t]*)\t([^\t]*)\t([^\t]*)$')
            if target ~= nil and target ~= '' then
                entries[#entries + 1] = {
                    target = target,
                    description = description or '',
                    program_url = program_url or '',
                }
            end
        end
    end
    return entries
end

---Just the target strings for a program (what recon may touch).
---@param program string Program slug.
---@return string[] targets
function M.targets(program)
    local targets = {}
    for _, e in ipairs(M.load(program)) do
        targets[#targets + 1] = e.target
    end
    return targets
end

return M
