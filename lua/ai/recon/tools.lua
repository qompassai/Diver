-- /qompassai/Diver/lua/ai/recon/tools.lua
-- Bounded wrappers around external recon CLI binaries.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: the recon skills name real command-line tools
-- (nmap, httpx, nuclei, ...). This module is the phone book for
-- those tools: where the binary lives, whether it is installed,
-- and how to run it with strict limits. Nothing here invents
-- success: a missing binary is reported, not faked.
---@module 'ai.recon.tools'

local M = {}

local ARG_MAX = 64 ---@type integer Max argv entries per invocation
local OUTPUT_MAX = 102400 ---@type integer Max bytes kept from stdout (100 KiB)
local TIMEOUT_MS = 120000 ---@type integer Hard kill after 120 seconds

---@class ReconToolDef
---@field active boolean True when the tool sends traffic to the target
---@field bin string Binary name as found on PATH
---@field desc string One-line description

---Tool phone book. `active` marks tools that touch the target
---(port scans, fuzzing, vulnerability probes); the rest only read
---public data (DNS, whois) or fetch a single URL.
M.DEFS = {
    amass = { active = false, bin = 'amass', desc = 'Subdomain enumeration and mapping' },
    curl = { active = true, bin = 'curl', desc = 'HTTP client' },
    dig = { active = false, bin = 'dig', desc = 'DNS lookup' },
    ffuf = { active = true, bin = 'ffuf', desc = 'Fast web fuzzer (paths, vhosts)' },
    gobuster = { active = true, bin = 'gobuster', desc = 'Directory/DNS/vhost enumerator' },
    httpx = { active = true, bin = 'httpx', desc = 'HTTP prober (tech detect, status, titles)' },
    jwt_tool = { active = false, bin = 'jwt_tool', desc = 'JWT token tester' },
    masscan = { active = true, bin = 'masscan', desc = 'High-speed port scanner' },
    nmap = { active = true, bin = 'nmap', desc = 'Port/service discovery scanner' },
    nuclei = { active = true, bin = 'nuclei', desc = 'Templated vulnerability scanner' },
    subfinder = { active = false, bin = 'subfinder', desc = 'Passive subdomain enumeration' },
    ['testssl.sh'] = { active = true, bin = 'testssl.sh', desc = 'TLS/SSL configuration tester' },
    whatweb = { active = true, bin = 'whatweb', desc = 'Website technology fingerprinter' },
    whois = { active = false, bin = 'whois', desc = 'Domain registration lookup' },
}

---True when the binary is installed and executable.
---@param name string Tool key from DEFS
---@return boolean
function M.available(name)
    local def = M.DEFS[name]
    if def == nil then
        return false
    end
    return vim.fn.executable(def.bin) == 1
end

---List tool keys, marking availability.
---@return table[] Array of { name, desc, active, available }
function M.list()
    local out = {}
    for name, def in pairs(M.DEFS) do
        out[#out + 1] = {
            active = def.active,
            available = M.available(name),
            desc = def.desc,
            name = name,
        }
    end
    table.sort(out, function(a, b)
        return a.name < b.name
    end)
    return out
end

---@param value any
---@return boolean
local function is_safe_arg(value)
    return type(value) == 'string' and #value >= 1 and #value <= 1024 and value:find('%z') == nil
end

---Run a tool with bounded argv. The callback receives
---(ok, result) where result = { code, stdout, stderr }.
---Missing binaries and bad argv report errors; they never run.
---@param name string Tool key from DEFS
---@param args string[] argv (without the binary itself)
---@param callback fun(ok: boolean, result: table)
function M.run(name, args, callback)
    assert(type(name) == 'string', 'name must be a string')
    assert(type(args) == 'table', 'args must be a table')
    assert(type(callback) == 'function', 'callback must be a function')
    local def = M.DEFS[name]
    if def == nil then
        callback(false, { error = 'unknown tool: ' .. name })
        return
    end
    if not M.available(name) then
        callback(false, { error = 'tool not installed: ' .. def.bin })
        return
    end
    if #args > ARG_MAX then
        callback(false, { error = 'argv exceeds ' .. ARG_MAX .. ' entries' })
        return
    end
    for i, arg in ipairs(args) do
        if not is_safe_arg(arg) then
            callback(false, { error = 'args[' .. i .. '] is not a safe bounded string' })
            return
        end
    end
    local argv = { def.bin }
    for _, arg in ipairs(args) do
        argv[#argv + 1] = arg
    end
    vim.system(argv, { text = true, timeout = TIMEOUT_MS }, function(obj)
        local stdout = obj.stdout or ''
        local stderr = obj.stderr or ''
        if #stdout > OUTPUT_MAX then
            stdout = stdout:sub(1, OUTPUT_MAX) .. '\n[truncated]'
        end
        if #stderr > OUTPUT_MAX then
            stderr = stderr:sub(1, OUTPUT_MAX) .. '\n[truncated]'
        end
        vim.schedule(function()
            callback(obj.code == 0, {
                code = obj.code,
                signal = obj.signal,
                stderr = stderr,
                stdout = stdout,
            })
        end)
    end)
end

return M
