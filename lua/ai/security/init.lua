-- /qompassai/Diver/lua/ai/security/init.lua
-- Qompass AI AI-Security Entry Point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Content scanner that runs over files/images BEFORE they enter AI
-- context or get executed, plus a tool-call confirmation policy
-- other modules (MCP, A2A) can adopt. Native Neovim APIs only.
--
-- CAPABILITIES
--   * scan_file(path, opts): reads (never executes) a file and reports
--     magic-byte/extension mismatches, polyglot markers, null bytes
--     in text, suspicious metadata keywords, prompt-injection
--     patterns, zero-width obfuscation, and base64-wrapped payloads.
--   * scan_text(text, opts): the text-only checks for strings already in
--     memory (clipboard, buffer, tool output).
--   * Both accept opts.provenance = { source, allowlisted }: an
--     unallowlisted source earns a provenance.untrusted_source finding.
--   * Both pass the base verdict through a composite escalation
--     (multiple medium codes, high+other, or the promptware kill-chain
--     pair escalate to malicious).
--   * quarantine(path): moves a suspicious file into an isolated
--     data directory; the original path no longer resolves to it.
--   * confirm_tool_call(server, tool, args, callback): vim.ui.select
--     confirmation with default-deny; consults a persistent
--     allowlist first so approved tools do not re-prompt. Login-lure
--     phrasing in the args adds an explicit "no credentials" warning.
--   * check_sampling_request(origin, target): refuses
--     server-originated sampling; only 'user' may originate it.
--   * MCP tool-metadata vetting lives in ai.security.mcp_vet
--     (vet_tool_metadata), run at registration/discovery time before
--     tool descriptions enter context.
--
-- LIMITS (read before relying on this module)
--   * No OCR engine: text rendered inside image pixels is NOT
--     inspected. A screenshot of an injection is invisible here.
--   * Metadata scanning is heuristic keyword matching over the file
--     head, not a real EXIF/PNG-chunk parse; crafted chunk layouts
--     can hide keywords outside the scanned window.
--   * Base64 is decoded exactly one level. Double-encoded or
--     otherwise re-encoded payloads are not unwrapped.
--   * Injection patterns are English-centric Lua patterns. Paraphrased,
--     translated, or typo-mutated phrasing can evade them; absence of
--     a finding is not proof of safety.
--   * All reads are bounded (see scanner.FILE_READ_BYTES_MAX and the
--     *_MAX constants); content past the caps is never inspected.
--   * confirm_tool_call is advisory UI: it cannot stop a module that
--     calls tools without asking, and headless sessions always deny.
--   * A 'clean' verdict means "no known markers found", not "safe".

local scanner = require('ai.security.scanner')

local M = {}

-- Named bounds.
local ALLOWLIST_MAX = 256
local ARGS_PREVIEW_MAX = 512
local AUTH_LURE_SCAN_MAX = 4096

-- Login-lure phrasing: an auth prompt smuggled inside tool arguments is
-- the phishing-shaped indirect injection. Plain-substring matches over
-- lowercased text; keep the set small and explicit.
local AUTH_LURE_PHRASES = {
    'sign in to continue',
    'login required',
    'verify your account',
    'enter your password',
    're-authenticate',
    'session expired',
}

local AUTH_LURE_WARNING = 'WARNING: this tool call involves an authentication prompt — never enter credentials.'

local setup_done = false

---@return string data_dir Per-user security data directory
local function data_dir()
    return vim.fn.stdpath('data') .. '/ai/security'
end

---@return string path Path of the persisted allowlist JSON
local function allowlist_path()
    return data_dir() .. '/allowlist.json'
end

---@return string dir Quarantine directory
local function quarantine_dir()
    return data_dir() .. '/quarantine'
end

---@param value any
---@param name string
---@return boolean ok
---@return string? err
local function check_string(value, name)
    if type(value) ~= 'string' then
        return false, name .. ' must be a string'
    end
    if value == '' then
        return false, name .. ' must not be empty'
    end
    if value:find('%z', 1, true) then
        return false, name .. ' contains NUL'
    end
    return true, nil
end

---@param entries any
---@return boolean ok
local function valid_allowlist(entries)
    if type(entries) ~= 'table' then
        return false
    end
    if #entries > ALLOWLIST_MAX then
        return false
    end
    for _, entry in ipairs(entries) do
        if type(entry) ~= 'table' then
            return false
        end
        if type(entry.server) ~= 'string' or type(entry.tool) ~= 'string' then
            return false
        end
    end
    return true
end

---@class ScanProvenance
---@field source string Where the text came from (URL, RAG document id, clipboard, ...)
---@field allowlisted boolean Caller-vouched trust flag; true skips the untrusted-source finding

-- Cap on the source string echoed into a finding detail.
local SOURCE_DETAIL_MAX = 200

--- Tag a report with its provenance when the source is not allowlisted.
--- This is the only scanner-enforceable mitigation for narrative RAG
--- poisoning: once poisoned text is retrieved, the scanner cannot tell
--- which sentences came from the attacker, so the finding tags the whole
--- report with the source instead of pretending sentence-level blame.
---
--- "ToxicRAG: Compromising Retrieval-Augmented Generation Systems via
--- Single-Shot Knowledge Poisoning Attacks" -- Haozhe Lu, Jiaqi Li,
--- Xiang Li, et al. (2026), arXiv:2609.11082,
--- https://arxiv.org/abs/2609.11082
---@param findings table[] Findings to append to
---@param provenance ScanProvenance?
---@return string? err Validation error; the finding is appended only on success
local function apply_provenance(findings, provenance)
    assert(type(findings) == 'table')
    if provenance == nil then
        return nil
    end
    if type(provenance) ~= 'table' then
        return 'provenance must be a table'
    end
    local ok, err = check_string(provenance.source, 'provenance.source')
    if not ok then
        return err
    end
    if type(provenance.allowlisted) ~= 'boolean' then
        return 'provenance.allowlisted must be a boolean'
    end
    if not provenance.allowlisted then
        local short = provenance.source:sub(1, SOURCE_DETAIL_MAX)
        findings[#findings + 1] = {
            severity = 'low',
            code = 'provenance.untrusted_source',
            detail = 'untrusted source: ' .. short .. ' (not allowlisted)',
        }
    end
    return nil
end

--- Composite verdict escalation, applied AFTER the base verdict.
---
--- First, a base 'clean' with any findings lifts to 'suspicious' (the
--- same floor the base verdict applies; needed because provenance
--- findings are appended after the base scan). Then escalates to
--- 'malicious' when any of these hold:
---   (a) findings carry >= 2 distinct medium-severity codes;
---   (b) any high-severity finding co-occurs with any other finding
---       (the base verdict already flags a lone high, so this only
---       reaffirms);
---   (c) the promptware kill-chain pair 'promptware.persistence' and
---       'promptware.recon' co-occur ('promptware.c2' optionally adds a
---       third leg).
--- Never downgrades below the lifted base.
---
--- "The Promptware Kill Chain..." -- Oleg Brodt, Elad Feldman, Bruce
--- Schneier, Ben Nassi (2026), arXiv:2601.09625,
--- https://arxiv.org/abs/2601.09625
---@param findings table[]
---@param base 'clean'|'suspicious'|'malicious'
---@return 'clean'|'suspicious'|'malicious'
local function composite_verdict(findings, base)
    assert(type(findings) == 'table')
    local verdict = base
    if verdict == 'clean' and #findings > 0 then
        verdict = 'suspicious'
    end
    local medium_codes = {}
    local high_count = 0
    local codes = {}
    for _, finding in ipairs(findings) do
        local code = finding.code
        if code ~= nil then
            codes[code] = true
            if finding.severity == 'medium' then
                medium_codes[code] = true
            end
        end
        if finding.severity == 'high' then
            high_count = high_count + 1
        end
    end
    local escalate = vim.tbl_count(medium_codes) >= 2
    if high_count >= 1 and #findings >= 2 then
        escalate = true
    end
    if codes['promptware.persistence'] and codes['promptware.recon'] then
        escalate = true
    end
    if escalate and verdict ~= 'malicious' then
        return 'malicious'
    end
    return verdict
end

--- Load the tool allowlist. A missing file is not an error: it means
--- nothing has been approved yet.
---@return table? entries Array of { server: string, tool: string }
---@return string? err
function M.allowlist_load()
    local handle = io.open(allowlist_path(), 'r')
    if handle == nil then
        return {}, nil
    end
    local raw = handle:read('*a')
    handle:close()
    if raw == nil or raw == '' then
        return {}, nil
    end
    local ok, decoded = pcall(vim.json.decode, raw)
    if not ok or not valid_allowlist(decoded) then
        return nil, 'allowlist is corrupt: ' .. allowlist_path()
    end
    return decoded, nil
end

--- Persist the tool allowlist. Entries are sorted for deterministic output.
---@param entries table Array of { server: string, tool: string }
---@return boolean ok
---@return string? err
function M.allowlist_save(entries)
    if not valid_allowlist(entries) then
        return false, 'allowlist entries are invalid or exceed the limit'
    end
    local sorted = {}
    for _, entry in ipairs(entries) do
        sorted[#sorted + 1] = { server = entry.server, tool = entry.tool }
    end
    table.sort(sorted, function(a, b)
        return (a.server .. '\0' .. a.tool) < (b.server .. '\0' .. b.tool)
    end)
    local ok, encoded = pcall(vim.json.encode, sorted)
    if not ok then
        return false, 'allowlist encode failed'
    end
    assert(type(encoded) == 'string')
    vim.fn.mkdir(data_dir(), 'p')
    local handle = io.open(allowlist_path(), 'w')
    if handle == nil then
        return false, 'cannot write ' .. allowlist_path()
    end
    handle:write(encoded)
    handle:close()
    return true, nil
end

---@param server string
---@param tool string
---@return boolean approved
function M.allowlist_check(server, tool)
    if type(server) ~= 'string' or type(tool) ~= 'string' then
        return false
    end
    local entries = M.allowlist_load()
    if entries == nil then
        return false
    end
    for _, entry in ipairs(entries) do
        if entry.server == server and entry.tool == tool then
            return true
        end
    end
    return false
end

---@param server string
---@param tool string
---@return boolean ok
---@return string? err
function M.allowlist_add(server, tool)
    local ok, err = check_string(server, 'server')
    if not ok then
        return false, err
    end
    ok, err = check_string(tool, 'tool')
    if not ok then
        return false, err
    end
    local entries, load_err = M.allowlist_load()
    if entries == nil then
        return false, load_err
    end
    for _, entry in ipairs(entries) do
        if entry.server == server and entry.tool == tool then
            return true, nil
        end
    end
    entries[#entries + 1] = { server = server, tool = tool }
    return M.allowlist_save(entries)
end

---@class ScanTextOpts
---@field filename? string Display name used in finding details
---@field provenance? ScanProvenance Provenance of the scanned text

--- Scan text already in memory. Pure function: no I/O, no execution.
--- The base verdict then passes through the composite escalation.
---@param text string
---@param opts? ScanTextOpts
---@return SecurityReport? report
---@return string? err
function M.scan_text(text, opts)
    local ok, err = check_string(text, 'text')
    if not ok then
        return nil, err
    end
    assert(opts == nil or type(opts) == 'table', 'scan_text opts must be a table or nil')
    local report = scanner.scan_text(text)
    local provenance_err = apply_provenance(report.findings, opts and opts.provenance or nil)
    if provenance_err ~= nil then
        return nil, provenance_err
    end
    report.verdict = composite_verdict(report.findings, report.verdict)
    return report, nil
end

---@class ScanFileOpts
---@field provenance? ScanProvenance Provenance of the file content

--- Scan a file by reading it (bounded). Never executes the content.
--- The base verdict then passes through the composite escalation.
---@param path string
---@param opts? ScanFileOpts
---@return SecurityReport? report
---@return string? err
function M.scan_file(path, opts)
    local ok, err = check_string(path, 'path')
    if not ok then
        return nil, err
    end
    assert(opts == nil or type(opts) == 'table', 'scan_file opts must be a table or nil')
    local handle = io.open(path, 'rb')
    if handle == nil then
        return nil, 'cannot open file: ' .. path
    end
    -- Read one byte past the cap so truncation is detectable.
    local data = handle:read(scanner.FILE_READ_BYTES_MAX + 1)
    handle:close()
    if data == nil then
        return nil, 'cannot read file: ' .. path
    end
    local truncated = #data > scanner.FILE_READ_BYTES_MAX
    if truncated then
        data = data:sub(1, scanner.FILE_READ_BYTES_MAX)
    end
    local ext = path:match('%.([^%.%/\\]+)$') or ''
    local report = scanner.scan_bytes(data, {
        extension = ext:lower(),
        filename = vim.fs.basename(path),
    })
    if truncated then
        local cap = tostring(scanner.FILE_READ_BYTES_MAX)
        local detail = 'File exceeds the ' .. cap .. '-byte read cap; tail was not scanned'
        report.findings[#report.findings + 1] = {
            severity = 'low',
            code = 'scan.truncated',
            detail = detail,
        }
        if report.verdict == 'clean' then
            report.verdict = 'suspicious'
        end
    end
    local provenance_err = apply_provenance(report.findings, opts and opts.provenance or nil)
    if provenance_err ~= nil then
        return nil, provenance_err
    end
    report.verdict = composite_verdict(report.findings, report.verdict)
    return report, nil
end

--- Move a suspicious file into the quarantine directory. The move is
--- atomic on one filesystem; the original path stops resolving to it.
---@param path string
---@return string? quarantine_path Destination path on success
---@return string? err
function M.quarantine(path)
    local ok, err = check_string(path, 'path')
    if not ok then
        return nil, err
    end
    local uv = vim.uv
    if uv == nil then
        return nil, 'vim.uv unavailable'
    end
    vim.fn.mkdir(quarantine_dir(), 'p')
    local base = vim.fs.basename(path)
    if base == nil or base == '' then
        return nil, 'cannot derive a file name from ' .. path
    end
    local dest = quarantine_dir() .. '/' .. base .. '-' .. tostring(os.time())
    local rename_ok, rename_err = uv.fs_rename(path, dest)
    if not rename_ok then
        return nil, 'quarantine move failed: ' .. tostring(rename_err)
    end
    return dest, nil
end

---@param args_text string Lowercased concatenated tool argument text
---@return boolean lure True when login-lure phrasing is present
local function has_auth_lure(args_text)
    assert(type(args_text) == 'string')
    for _, phrase in ipairs(AUTH_LURE_PHRASES) do
        if args_text:find(phrase, 1, true) then
            return true
        end
    end
    return false
end

--- Ask the user to confirm a tool call. Default-deny: a dismissed or
--- unavailable prompt denies. Allowlisted server/tool pairs skip the
--- prompt. The decision arrives via callback because vim.ui.select
--- is asynchronous. When the tool arguments carry login-lure phrasing,
--- the prompt carries an explicit "no credentials" warning line.
---
--- "LoginTrap: Uncovering Task-Agnostic Phishing-Style Indirect Prompt
--- Injection Attacks against LLM-based Web Agents" -- Longtao Guo, Zelin
--- Zhang, Kaifeng Huang, et al. (2026), arXiv:2608.04741,
--- https://arxiv.org/abs/2608.04741
---@param server string
---@param tool string
---@param args table Tool arguments (previewed, truncated)
---@param callback fun(allowed: boolean, reason: string)
function M.confirm_tool_call(server, tool, args, callback)
    assert(type(server) == 'string', 'server must be a string')
    assert(type(tool) == 'string', 'tool must be a string')
    assert(type(args) == 'table', 'args must be a table')
    assert(type(callback) == 'function', 'callback must be a function')
    if server == '' or tool == '' then
        callback(false, 'denied: empty server or tool name')
        return
    end
    if M.allowlist_check(server, tool) then
        callback(true, 'allowlisted')
        return
    end
    if #vim.api.nvim_list_uis() == 0 then
        -- No UI to present the prompt on (e.g. --headless): default-deny.
        callback(false, 'denied: no UI attached (default-deny)')
        return
    end
    local preview = vim.inspect(args):sub(1, ARGS_PREVIEW_MAX)
    local prompt_lines = {
        'AI tool call request',
        'Server: ' .. server,
        'Tool: ' .. tool,
        'Args: ' .. preview,
    }
    local args_text = vim.inspect(args):lower():sub(1, AUTH_LURE_SCAN_MAX)
    if has_auth_lure(args_text) then
        table.insert(prompt_lines, 1, AUTH_LURE_WARNING)
    end
    local prompt = table.concat(prompt_lines, '\n')
    local ok, select_err = pcall(vim.ui.select, { 'Deny', 'Allow once' }, {
        prompt = prompt,
    }, function(choice)
        -- choice is nil when the user dismisses the prompt: deny.
        if choice == 'Allow once' then
            callback(true, 'allowed once by user')
        else
            callback(false, 'denied (default-deny)')
        end
    end)
    if not ok then
        -- No usable UI (e.g. headless): stay denied, say why.
        callback(false, 'denied: confirmation UI unavailable (' .. tostring(select_err) .. ')')
    end
end

--- Refuse server-originated sampling requests. In MCP a sampling
--- request lets a server ask the client (the model) to generate text;
--- a malicious server can abuse that channel to steer the model, so
--- only the user may originate sampling.
---
--- "Breaking the Protocol: Security Analysis of the Model Context
--- Protocol Specification and Prompt Injection Vulnerabilities in
--- Tool-Integrated LLM Agents" -- Narek Maloyan, Dmitry Namiot (2026),
--- arXiv:2601.17549, https://arxiv.org/abs/2601.17549
---@param origin string Who originates the request: 'user' or a server name
---@param target string What the sampling is for (documented; unused by the policy)
---@return boolean allowed
---@return string? reason
function M.check_sampling_request(origin, target)
    assert(type(target) == 'string', 'target must be a string')
    if type(origin) ~= 'string' or origin == '' then
        return false, 'refused: sampling origin must be a non-empty string'
    end
    if origin == 'user' then
        return true
    end
    return false, "refused: sampling requests must originate from the user, not server '" .. origin .. "'"
end

---@param opts? table Reserved for future options; currently unused.
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'security.setup expects a table or nil')
    if setup_done then
        return
    end
    setup_done = true
    vim.fn.mkdir(data_dir(), 'p')
    require('ai.security.commands')
end

return M
