-- /qompassai/Diver/lua/ai/mcp/skills.lua
-- Loader for SKILL.md skill libraries (uphiago/recon-skills).
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: the recon-skills repo is a library of Markdown
-- procedure documents. This module reads their frontmatter
-- (name, description, category, tags), labels each skill with the
-- WebMCP safety annotations, and exposes them as callable tools.
-- The Markdown body is passed through as the tool's operating
-- procedure -- it is documentation for the agent, not code we
-- re-implement. Execution shells out to the real CLI binaries via
-- ai.recon.tools, through ai.recon.gate, with every call logged.
---@module 'ai.mcp.skills'

local M = {}

local SKILL_FILE = 'SKILL.md'
local FRONTMATTER_MAX = 8192 ---@type integer Max bytes of frontmatter parsed
local BODY_MAX = 65536 ---@type integer Max bytes of body kept (64 KiB)
local SKILL_COUNT_MAX = 512 ---@type integer Sanity bound on skills per scan

local config = {
    skills_dir = vim.fn.stdpath('data') .. '/recon-skills',
}

---Set the directory that holds the skill library.
---@param opts? table { skills_dir: string? }
function M.setup(opts)
    opts = opts or {}
    if opts.skills_dir ~= nil then
        assert(type(opts.skills_dir) == 'string', 'skills_dir must be a string')
        config.skills_dir = opts.skills_dir
    end
end

---@return string
function M.skills_dir()
    return config.skills_dir
end

---@param line string
---@return string key, string value
local function parse_scalar(line)
    local key, value = line:match('^([A-Za-z0-9_-]+):%s*(.-)%s*$')
    return key, value
end

---Parse one inline list like [a, b, c].
---@param value string
---@return string[]
local function parse_inline_list(value)
    local out = {}
    local inner = value:match('^%[(.*)%]$')
    if inner == nil then
        return out
    end
    for item in inner:gmatch('[^,]+') do
        item = item:match('^%s*(.-)%s*$')
        if item ~= '' then
            out[#out + 1] = item
        end
    end
    return out
end

---Parse YAML-ish frontmatter. Handles `key: value`, `key: [a, b]`,
---and block lists:
---  key:
---    - a
---    - b
---@param text string Frontmatter without the --- fences
---@return table
local function parse_frontmatter(text)
    local data = {}
    local current_key = nil
    for line in (text .. '\n'):gmatch('([^\n]*)\n') do
        if line:match('^%s*$') then
            current_key = nil
        else
            local item = line:match('^%s*%-%s+(.-)%s*$')
            if item ~= nil and current_key ~= nil then
                local list = data[current_key]
                if type(list) ~= 'table' then
                    list = {}
                    data[current_key] = list
                end
                list[#list + 1] = item
            else
                local key, value = parse_scalar(line)
                if key ~= nil then
                    if value == '' then
                        current_key = key
                        data[key] = {}
                    elseif value:sub(1, 1) == '[' then
                        data[key] = parse_inline_list(value)
                        current_key = nil
                    else
                        data[key] = value
                        current_key = nil
                    end
                else
                    current_key = nil
                end
            end
        end
    end
    return data
end

---Split a SKILL.md file into frontmatter table and body text.
---@param path string
---@return table? front
---@return string? body
---@return string? err
local function read_skill_file(path)
    local handle = io.open(path, 'r')
    if handle == nil then
        return nil, nil, 'cannot open ' .. path
    end
    local raw = handle:read(FRONTMATTER_MAX + BODY_MAX + 16)
    handle:close()
    if raw == nil or raw == '' then
        return nil, nil, 'empty file ' .. path
    end
    local fence1_s, fence1_e = raw:find('^%-%-%-\r?\n')
    if fence1_s == nil then
        return nil, nil, 'missing frontmatter fence in ' .. path
    end
    local fence2_s, fence2_e = raw:find('\n%-%-%-\r?\n?', fence1_e + 1)
    if fence2_s == nil then
        return nil, nil, 'unterminated frontmatter in ' .. path
    end
    local front_text = raw:sub(fence1_e + 1, fence2_s - 1)
    local body = raw:sub(fence2_e + 1, fence2_e + BODY_MAX)
    body = body:gsub('\r\n', '\n'):gsub('\r', '\n')
    return parse_frontmatter(front_text), body, nil
end

---@class ReconSkill
---@field name string
---@field description string
---@field category string
---@field tags string[]
---@field version string?
---@field compatibility string?
---@field related string[]
---@field model_invocable boolean
---@field body string
---@field dir string

---Upstream skill-name contract: lowercase alphanumerics separated
---by single hyphens. Lua patterns cannot quantify a group, so the
---"single separators" part is checked separately.
---@param name any
---@return boolean
local function valid_skill_name(name)
    if type(name) ~= 'string' then
        return false
    end
    if name:match('^[-a-z0-9]+$') == nil then
        return false
    end
    return name:match('^%-') == nil and name:match('%-$') == nil and name:match('%-%-') == nil
end

---Normalize parsed frontmatter into a ReconSkill.
---@param front table
---@param body string
---@param dir string
---@return ReconSkill? skill
---@return string? err
local function to_skill(front, body, dir)
    if type(front.name) ~= 'string' or front.name == '' then
        return nil, 'skill missing name'
    end
    if not valid_skill_name(front.name) then
        return nil, 'bad skill name: ' .. front.name
    end
    local tags = {}
    if type(front.tags) == 'table' then
        tags = front.tags
    end
    local related = {}
    if type(front.related_skills) == 'table' then
        related = front.related_skills
    end
    -- Skills can opt out of model invocation (orchestrator/reference
    -- docs the model should read but never auto-fire).
    local no_invoke = front['disable-model-invocation']
    return {
        name = front.name,
        description = tostring(front.description or ''),
        category = tostring(front.category or 'recon'),
        tags = tags,
        version = front.version ~= nil and tostring(front.version) or nil,
        compatibility = front.compatibility ~= nil and tostring(front.compatibility) or nil,
        related = related,
        model_invocable = no_invoke ~= true and no_invoke ~= 'true',
        body = body,
        dir = dir,
    },
        nil
end

local cache = {} ---@type table<string, ReconSkill>
local did_scan = false ---@type boolean

---Scan a directory tree for SKILL.md files. Returns counts.
---@param dir? string Defaults to the configured skills_dir
---@return integer loaded
---@return string[] errors
function M.scan(dir)
    dir = dir or config.skills_dir
    assert(type(dir) == 'string', 'dir must be a string')
    cache = {}
    local errors = {}
    local found = vim.fs.find(SKILL_FILE, { path = dir, type = 'file', limit = SKILL_COUNT_MAX + 1 })
    if #found > SKILL_COUNT_MAX then
        errors[#errors + 1] = 'skill count exceeds bound ' .. SKILL_COUNT_MAX
        return 0, errors
    end
    local loaded = 0
    for _, path in ipairs(found) do
        local skill_dir = path:match('^(.*)/[^/]*$') or dir
        local front, body, err = read_skill_file(path)
        if front == nil then
            errors[#errors + 1] = err or ('unreadable ' .. path)
        else
            local skill, norm_err = to_skill(front, body or '', skill_dir)
            if skill == nil then
                errors[#errors + 1] = (norm_err or 'bad skill') .. ' in ' .. path
            elseif cache[skill.name] ~= nil then
                errors[#errors + 1] = 'duplicate skill name: ' .. skill.name
            else
                cache[skill.name] = skill
                loaded = loaded + 1
            end
        end
    end
    did_scan = true
    return loaded, errors
end

---Scan once if nobody has scanned yet. Makes read paths safe to
---call without an explicit setup.
local function ensure_scanned()
    if not did_scan then
        M.scan()
    end
end

---All loaded skills, sorted by name.
---@return ReconSkill[]
function M.list()
    ensure_scanned()
    local out = {}
    for _, skill in pairs(cache) do
        out[#out + 1] = skill
    end
    table.sort(out, function(a, b)
        return a.name < b.name
    end)
    return out
end

---Look up one skill by name.
---@param name string
---@return ReconSkill?
function M.get(name)
    ensure_scanned()
    return cache[name]
end

---Build the WebMCP-shaped tool definition for a skill.
---@param skill ReconSkill
---@return table
function M.tool_def(skill)
    local ann = require('ai.security.annotations')
    return {
        name = 'recon.' .. skill.name,
        title = skill.name,
        description = skill.description ~= '' and skill.description or ('Recon skill: ' .. skill.name),
        inputSchema = {
            type = 'object',
            properties = {
                target = { type = 'string', description = 'Target host, domain, or URL' },
                args = {
                    type = 'array',
                    items = { type = 'string' },
                    description = 'Extra CLI arguments for the underlying tool',
                },
            },
            required = { 'target' },
        },
        annotations = ann.for_skill({ name = skill.name, category = skill.category, tags = skill.tags }),
        procedure = skill.body,
    }
end

---All loaded skills as WebMCP-shaped tool definitions.
---Skills flagged disable-model-invocation are excluded: they are
---reference docs, not callable tools.
---@return table[]
function M.tool_defs()
    local out = {}
    for _, skill in ipairs(M.list()) do
        if skill.model_invocable then
            out[#out + 1] = M.tool_def(skill)
        end
    end
    return out
end

---Pick the CLI tool for a skill from its compatibility line,
---falling back to the first available known tool.
---@param skill ReconSkill
---@return string? tool_name
local function pick_tool(skill)
    local tools = require('ai.recon.tools')
    if skill.compatibility ~= nil then
        local lower = skill.compatibility:lower()
        for name in pairs(tools.DEFS) do
            if lower:find(name, 1, true) and tools.available(name) then
                return name
            end
        end
    end
    return nil
end

---Execute a skill: gate it, then run its mapped CLI tool against
---the target. Skills without a mapped/installed tool return their
---procedure so the agent can follow it by hand.
---@param name string Skill name (without the recon. prefix)
---@param params table { target: string, args: string[]? }
---@param via string Call origin ('bridge', 'command', 'agent')
---@param callback fun(ok: boolean, result: table)
function M.execute(name, params, via, callback)
    assert(type(name) == 'string', 'name must be a string')
    assert(type(params) == 'table', 'params must be a table')
    assert(type(via) == 'string', 'via must be a string')
    assert(type(callback) == 'function', 'callback must be a function')
    ensure_scanned()
    local skill = cache[name]
    if skill == nil then
        callback(false, { error = 'unknown skill: ' .. name })
        return
    end
    if not skill.model_invocable then
        callback(false, { error = 'skill is reference-only (disable-model-invocation)' })
        return
    end
    local target = params.target
    if type(target) ~= 'string' or target == '' then
        callback(false, { error = 'params.target must be a non-empty string' })
        return
    end
    local ann = require('ai.security.annotations')
    local annotations = ann.for_skill({ name = skill.name, category = skill.category, tags = skill.tags })
    local gate = require('ai.recon.gate')
    gate.check('recon.' .. name, target, annotations, via, function(allowed, reason)
        if not allowed then
            callback(false, { error = 'denied: ' .. reason })
            return
        end
        local tools = require('ai.recon.tools')
        local tool_name = pick_tool(skill)
        if tool_name == nil then
            callback(true, {
                ran = false,
                reason = reason,
                note = 'no mapped CLI tool installed; follow the procedure',
                procedure = skill.body:sub(1, 4000),
            })
            return
        end
        local args = { target }
        if type(params.args) == 'table' then
            for _, a in ipairs(params.args) do
                args[#args + 1] = a
            end
        end
        tools.run(tool_name, args, function(ok, result)
            result.ran = true
            result.tool = tool_name
            result.skill = name
            result.gate = reason
            callback(ok, result)
        end)
    end)
end

return M
