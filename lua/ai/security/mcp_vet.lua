-- /qompassai/Diver/lua/ai/security/mcp_vet.lua
-- Qompass AI MCP Tool-Metadata Vetting (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Client-side vetting of MCP server tool metadata (names + descriptions)
-- at registration/discovery time, BEFORE the descriptions enter AI
-- context. Tool descriptions are attacker-controlled text from the
-- server: a poisoned description steers the model every time the tool is
-- considered. This is the missing client-side layer -- the server never
-- vets itself.
--
--   * M.vet_tool_metadata(tools): per-tool imperative scan plus
--     cross-tool trigger correlation. Returns a findings array; the
--     caller decides. Quarantine-on-high here means disabling or
--     removing the server via ai.mcp.registry -- ai.security.quarantine
--     moves files, not tools.
--
-- INTENDED CALL SITE
--   ai.mcp.tools.list, right after the 'tools/list' response is parsed
--   and before any description is inserted into context or presented as
--   trusted. A second natural site is ai.mcp.discovery at install time.
--
-- The imperative phrase set in this module lives ONLY here, never on
-- general text. Benign documentation is full of imperatives ("you
-- should restart the server"), so running this scan over prose would
-- drown in false positives. Here it runs over tool descriptions, where
-- instructional phrasing addressed at the model is the attack.
--
-- POLICY
--   Client-side vetting before context insertion is mandatory, not
--   defense in depth.
--   "Model Context Protocol Threat Modeling and Analyzing
--   Vulnerabilities to Prompt Injection with Tool Poisoning" -- Charoes
--   Huang, Xin Huang, Ngoc Phu Tran, et al. (2026), arXiv:2603.22489,
--   https://arxiv.org/abs/2603.22489
--
-- LIMITS
--   * English phrasing only; paraphrased or translated instructions
--     evade the phrase list.
--   * Correlation is heuristic: tools in one domain share vocabulary,
--     so a shared token is a lead, not proof. Each finding names the
--     token and the tools so a human can judge.
--   * Findings are leads for the caller (disable the server, ask the
--     user), never an automatic block.

local M = {}

-- Named bounds.
local TOOL_COUNT_MAX = 128
local DESC_LEN_MAX = 16384
local TOKEN_LEN_MIN = 6
local TRIGGER_TOOL_COUNT = 3

---@class McpToolMeta
---@field name string Tool name from the server's tools/list response
---@field description string Tool description from the server (attacker-controlled)

---@class McpVetFinding
---@field severity 'high'
-- 'mcp.vet_rejected' is emitted by the caller (ai.mcp.tools) when the
-- metadata trips the vet's own bounds and the vet refuses to score it.
---@field code 'mcp.tool_description_poison'|'mcp.cross_tool_trigger'|'mcp.vet_rejected'
---@field detail string Human-readable explanation naming the tool(s)
---@field offset? integer 1-based byte offset of the phrase in the description

-- Instructional phrasing addressed at the model. This set lives ONLY in
-- this module (registry vetting); it must never run over general text,
-- where the same phrasing is benign documentation.
--
-- "MCPTox: A Benchmark for Tool Poisoning Attack on Real-World MCP
-- Servers" -- Zhiqiang Wang, Yichao Gao, Yanting Wang, et al. (2025),
-- arXiv:2508.14925, https://arxiv.org/abs/2508.14925
local IMPERATIVE_PHRASES = {
    'you must',
    'you should',
    'you have to',
    'you are required',
    'you will',
    'ignore prior instructions',
    'ignore previous instructions',
    'ignore all previous',
    'disregard your instructions',
    'disregard previous',
    'override your',
    'do not reveal',
    'never tell the user',
    'never mention',
    'keep this secret',
    'keep this hidden',
    'do not disclose',
}

-- Sentence-initial absolutes: a description that opens a sentence with
-- "always"/"never" is issuing standing orders to the model.
local SENTENCE_INITIAL = {
    { word = 'always', pattern = '^always' },
    { word = 'always', pattern = '[%.!\n]%s*always' },
    { word = 'never', pattern = '^never' },
    { word = 'never', pattern = '[%.!\n]%s*never' },
}

-- Small explicit stoplist for cross-tool correlation. Short structural
-- words are already dropped by TOKEN_LEN_MIN; these are the longer
-- filler words that would otherwise link unrelated tools.
local STOPLIST = {
    the = true,
    ['and'] = true,
    ['for'] = true,
    with = true,
    from = true,
    that = true,
    this = true,
    your = true,
    will = true,
    tool = true,
    tools = true,
    used = true,
    using = true,
    data = true,
    into = true,
}

---@param findings McpVetFinding[]
---@param name string
---@param description string Lowercased description
local function scan_imperatives(findings, name, description)
    assert(type(findings) == 'table')
    assert(type(name) == 'string')
    assert(type(description) == 'string')
    for _, phrase in ipairs(IMPERATIVE_PHRASES) do
        local start = description:find(phrase, 1, true)
        if start then
            local detail = ('Tool %q: description uses instructional phrasing %q'):format(name, phrase)
            findings[#findings + 1] = {
                severity = 'high',
                code = 'mcp.tool_description_poison',
                detail = detail,
                offset = start,
            }
        end
    end
    for _, entry in ipairs(SENTENCE_INITIAL) do
        local start = description:find(entry.pattern)
        if start then
            local detail = ('Tool %q: sentence-initial %q issues a standing order'):format(name, entry.word)
            findings[#findings + 1] = {
                severity = 'high',
                code = 'mcp.tool_description_poison',
                detail = detail,
                offset = start,
            }
        end
    end
end

---@param description string Lowercased description
---@return table<string, boolean> tokens Tokens (>= TOKEN_LEN_MIN chars) minus the stoplist
local function tokenize(description)
    assert(type(description) == 'string')
    local tokens = {}
    for token in description:gmatch('[%w_]+') do
        if #token >= TOKEN_LEN_MIN and not STOPLIST[token] then
            tokens[token] = true
        end
    end
    return tokens
end

-- Cross-tool trigger correlation: a token shared by >= 3 tool
-- descriptions is the shape of threshold poisoning, where no single
-- description looks malicious but the trigger only fires when several
-- tools are present together.
--
-- "ShareLock: A Stealthy Multi-Tool Threshold Poisoning Attack Against
-- MCP" -- Liwei Liu, Tianzhu Han, Zijian Liu, et al. (2026),
-- arXiv:2606.27027, https://arxiv.org/abs/2606.27027
---@param tools McpToolMeta[]
---@param findings McpVetFinding[]
local function correlate_triggers(tools, findings)
    assert(type(tools) == 'table')
    assert(type(findings) == 'table')
    local token_tools = {} ---@type table<string, string[]>
    for _, tool in ipairs(tools) do
        local tokens = tokenize(tool.description:lower())
        for token in pairs(tokens) do
            local names = token_tools[token]
            if names == nil then
                names = {}
                token_tools[token] = names
            end
            names[#names + 1] = tool.name
        end
    end
    -- Sorted tokens: deterministic output regardless of pairs() order.
    local sorted = {}
    for token in pairs(token_tools) do
        sorted[#sorted + 1] = token
    end
    table.sort(sorted)
    for _, token in ipairs(sorted) do
        local names = token_tools[token]
        if #names >= TRIGGER_TOOL_COUNT then
            local detail = ('Token %q shared by %d tool descriptions: %s'):format(
                token,
                #names,
                table.concat(names, ', ')
            )
            findings[#findings + 1] = {
                severity = 'high',
                code = 'mcp.cross_tool_trigger',
                detail = detail,
            }
        end
    end
end

--- Vet MCP server tool metadata at registration/discovery time, before it
--- enters AI context. Returns findings; the caller decides (disable or
--- remove the server on high). Pure function: no I/O, no execution.
---@param tools McpToolMeta[] Array of { name, description } from tools/list
---@return McpVetFinding[] findings
function M.vet_tool_metadata(tools)
    assert(type(tools) == 'table', 'tools must be a table')
    assert(#tools <= TOOL_COUNT_MAX, 'tools exceed ' .. TOOL_COUNT_MAX)
    for index, tool in ipairs(tools) do
        assert(type(tool) == 'table', 'tools[' .. index .. '] must be a table')
        assert(type(tool.name) == 'string' and tool.name ~= '', 'tool name must be a non-empty string')
        assert(type(tool.description) == 'string', 'tool description must be a string')
        assert(#tool.description <= DESC_LEN_MAX, 'tool description exceeds ' .. DESC_LEN_MAX .. ' bytes')
    end
    local findings = {}
    for _, tool in ipairs(tools) do
        scan_imperatives(findings, tool.name, tool.description:lower())
    end
    correlate_triggers(tools, findings)
    return findings
end

return M
