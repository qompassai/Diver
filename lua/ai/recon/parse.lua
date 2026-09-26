-- /qompassai/Diver/lua/ai/recon/parse.lua
-- Parsers for recon tool output.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: recon tools print text. This module turns that
-- text into Lua tables Neovim can work with: httpx JSON lines
-- become host records, nmap grepable output becomes port lists.
-- Pure Lua, no dependencies -- the recommended LuaRocks (lpeg,
-- luaexpat) only matter for heavier grammars; see recon.rocks.
---@module 'ai.recon.parse'

local M = {}

local LINE_MAX = 4096 ---@type integer Longest single line parsed
local LINES_MAX = 20000 ---@type integer Most lines parsed per call

---@param text string
---@return string[] lines
local function split_lines(text)
    local lines = {}
    local count = 0
    for line in (text .. '\n'):gmatch('([^\n]*)\n') do
        count = count + 1
        if count > LINES_MAX then
            break
        end
        lines[#lines + 1] = line:sub(1, LINE_MAX)
    end
    return lines
end

---Parse generic JSON-lines output (httpx -json, etc.).
---Skips blank lines and malformed rows, reporting the skip count.
---@param text string
---@return table[] records
---@return integer skipped
function M.json_lines(text)
    assert(type(text) == 'string', 'text must be a string')
    local records = {}
    local skipped = 0
    for _, line in ipairs(split_lines(text)) do
        if line:match('%S') then
            local ok, decoded = pcall(vim.json.decode, line)
            if ok and type(decoded) == 'table' then
                records[#records + 1] = decoded
            else
                skipped = skipped + 1
            end
        end
    end
    return records, skipped
end

---Parse httpx JSON output into host records.
---Each record: { url, host, port, status, title, tech, error? }.
---@param text string httpx -json output
---@return table[] hosts
---@return integer skipped
function M.httpx(text)
    assert(type(text) == 'string', 'text must be a string')
    local records, skipped = M.json_lines(text)
    local hosts = {}
    for _, r in ipairs(records) do
        hosts[#hosts + 1] = {
            url = r.url,
            host = r.host,
            port = r.port,
            status = r.status_code,
            title = r.title,
            tech = r.tech,
            error = r.error,
        }
    end
    return hosts, skipped
end

---@param ports_str string e.g. "80/open/tcp//http///, 443/open/tcp//https///"
---@return table[] ports Array of { port, state, proto, service }
local function parse_og_ports(ports_str)
    local ports = {}
    for chunk in ports_str:gmatch('[^,]+') do
        local port, state, proto, service = chunk:match('^%s*(%d+)/(%a+)/(%a+)//([^/]*)')
        if port ~= nil then
            ports[#ports + 1] = {
                port = tonumber(port),
                state = state,
                proto = proto,
                service = service ~= '' and service or nil,
            }
        end
    end
    return ports
end

---Parse nmap grepable output (-oG) into host records.
---Each record: { host, status, ports = { {port, state, proto, service} } }.
---@param text string nmap -oG output
---@return table[] hosts
function M.nmap_grepable(text)
    assert(type(text) == 'string', 'text must be a string')
    local hosts = {}
    local by_host = {}
    for _, line in ipairs(split_lines(text)) do
        local host, status = line:match('^Host:%s+(%S+)%s+%(([^)]*)%)%s+Status:%s+(%a+)')
        if host ~= nil then
            local rec = { host = host, status = status, ports = {} }
            hosts[#hosts + 1] = rec
            by_host[host] = rec
        else
            local host2, ports_str = line:match('^Host:%s+(%S+)%s+%([^)]*%)%s+Ports:%s+(.*)$')
            if host2 ~= nil and by_host[host2] ~= nil then
                by_host[host2].ports = parse_og_ports(ports_str)
            end
        end
    end
    return hosts
end

return M
