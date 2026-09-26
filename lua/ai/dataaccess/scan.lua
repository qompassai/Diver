-- /qompassai/Diver/lua/ai/dataaccess/scan.lua
-- Qompass AI Data Access Security Scanning (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Every query request and every result set passes through ai.security
-- before reaching an agent. check() returns one of three verdicts:
--
--   'allow'  no findings worth acting on;
--   'notify' medium/low findings: the query proceeds, but the finding
--            is logged to the JSONL audit log and the operator is told;
--   'refuse' any high-severity finding or a 'malicious' composite verdict
--            from ai.security: the query or result is refused and a
--            JSONL security event is recorded.
--
-- Fail-closed: when ai.security cannot be loaded, every check refuses.
-- There is no path through this module that delivers unscanned text to
-- an agent.
--
-- Plain words: this is the metal detector. Every question going into
-- the database and every answer coming back walks through it. If it
-- beeps loudly, the question or answer is stopped and written down;
-- if it beeps quietly, things continue but the beep is still written
-- down. If the detector itself is broken, nothing gets through at all.

local M = {}

local TEXT_BYTES_MAX = 1048576 -- 1 MiB: matches the adapters' own SQL cap.
local ROW_BYTES_MAX = 65536
local ROW_SCAN_COUNT_MAX = 5000 -- Matches the adapters' result line cap.

-- Test hook: when true, available() reports the security module as
-- missing so the fail-closed path can be exercised headless.
M._force_unavailable = false

---@return table? security
local function load_security()
    if M._force_unavailable then
        return nil
    end
    local ok, mod = pcall(require, 'ai.security')
    if not ok or type(mod) ~= 'table' then
        return nil
    end
    if type(mod.scan_text) ~= 'function' then
        return nil
    end
    return mod
end

---Resolve the security module, or nil when it is unavailable. Callers
---treat nil as "refuse everything".
---@return table? security
---@return string? err
function M.available()
    local security = load_security()
    if security == nil then
        return nil, 'security subsystem unavailable: refusing (fail closed)'
    end
    return security, nil
end

---@param findings table[]
---@return boolean high_found
local function has_high_finding(findings)
    for _, finding in ipairs(findings) do
        if type(finding) == 'table' and finding.severity == 'high' then
            return true
        end
    end
    return false
end

---Scan one text through ai.security and map the report to a verdict.
---@param security table ai.security module.
---@param text string Text to scan.
---@param provenance string Short label for the audit log.
---@return 'allow'|'notify'|'refuse' verdict
---@return table findings
---@return string? err
local function check_text(security, text, provenance)
    if #text > TEXT_BYTES_MAX then
        return 'refuse', {}, 'scan input exceeds size bound'
    end
    local report, scan_err = security.scan_text(text, {
        filename = 'dataaccess:' .. provenance,
    })
    if report == nil then
        return 'refuse', {}, 'scan failed: ' .. tostring(scan_err)
    end
    local findings = report.findings or {}
    -- Honor the scanner's composite verdict as well as individual
    -- findings: a 'malicious' verdict refuses even when no single
    -- finding carries high severity on its own.
    if report.verdict == 'malicious' or has_high_finding(findings) then
        return 'refuse', findings, nil
    end
    if report.verdict == 'suspicious' or #findings > 0 then
        return 'notify', findings, nil
    end
    return 'allow', findings, nil
end

---Scan a query request before it reaches the database.
---@param text string SQL or command text.
---@return 'allow'|'notify'|'refuse' verdict
---@return table findings
---@return string? err
function M.check_request(text)
    if type(text) ~= 'string' or text == '' then
        return 'refuse', {}, 'request text must be a non-empty string'
    end
    local security, avail_err = M.available()
    if security == nil then
        return 'refuse', {}, avail_err
    end
    return check_text(security, text, 'request')
end

---@param row_text string JSON-encoded row.
---@return 'allow'|'notify'|'refuse' verdict
---@return table findings
---@return string? err
local function check_row(security, row_text)
    if #row_text > ROW_BYTES_MAX then
        return 'refuse', {}, 'result row exceeds size bound'
    end
    return check_text(security, row_text, 'result')
end

---Scan a result set row by row before it reaches the agent. The first
---refusing row stops the scan; notify-level findings accumulate.
---@param rows table Result rows from the adapter.
---@return 'allow'|'notify'|'refuse' verdict
---@return table findings All notify-level findings seen.
---@return string? err
function M.check_result(rows)
    if type(rows) ~= 'table' then
        return 'refuse', {}, 'result rows must be a table'
    end
    local security, avail_err = M.available()
    if security == nil then
        return 'refuse', {}, avail_err
    end
    local collected = {}
    local scanned = 0
    for _, row in ipairs(rows) do
        scanned = scanned + 1
        if scanned > ROW_SCAN_COUNT_MAX then
            return 'refuse', collected, 'result exceeds row scan bound'
        end
        local ok, row_text = pcall(vim.json.encode, row)
        if not ok or type(row_text) ~= 'string' then
            return 'refuse', collected, 'result row is not JSON-encodable'
        end
        local verdict, findings, err = check_row(security, row_text)
        if verdict == 'refuse' then
            return 'refuse', findings, err or 'malicious content in result set'
        end
        if verdict == 'notify' then
            for _, finding in ipairs(findings) do
                collected[#collected + 1] = finding
            end
        end
    end
    if #collected > 0 then
        return 'notify', collected, nil
    end
    return 'allow', collected, nil
end

return M
