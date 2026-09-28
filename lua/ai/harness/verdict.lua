-- /qompassai/diver/lua/ai/harness/verdict.lua
-- Qompass AI Agent Harness: deterministic acceptance verdicts (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The harness, not the model, decides whether acceptance criteria passed.
-- Deterministic graders first: command exit status, diagnostics counts,
-- schema validation, custom predicates. An LLM judge is out of scope for
-- Phase 1; genuinely semantic outcomes use kind 'custom' with an explicit
-- predicate the caller supplies.

local M = {}

M.KINDS = { 'command', 'diagnostics', 'schema', 'custom' }

local ACCEPTANCE_MAX = 32

---@class AiHarnessCheck
---@field kind string
---@field pass boolean
---@field detail string

---@param argv string[]
---@return table
local function default_run_command(argv)
    if vim ~= nil and vim.system ~= nil then
        local result = vim.system(argv, { text = true }):wait()
        return { exit = result.code, output = result.stdout or '' }
    end
    return { exit = nil, error = 'command execution unavailable outside Neovim' }
end

---@param item table
---@return boolean ok
---@return string? err
local function validate_item(item)
    if type(item) ~= 'table' then
        return nil, 'acceptance item must be a table'
    end
    local known = false
    for _, kind in ipairs(M.KINDS) do
        if item.kind == kind then
            known = true
            break
        end
    end
    if not known then
        return nil, 'unknown acceptance kind: ' .. tostring(item.kind)
    end
    if item.kind == 'command' then
        if type(item.argv) ~= 'table' or #item.argv == 0 then
            return nil, 'command acceptance needs a non-empty argv'
        end
    elseif item.kind == 'diagnostics' then
        if type(item.max_errors) ~= 'number' or item.max_errors < 0 then
            return nil, 'diagnostics acceptance needs max_errors >= 0'
        end
    elseif item.kind == 'schema' then
        if type(item.value) == nil or type(item.schema) ~= 'table' then
            return nil, 'schema acceptance needs value and schema'
        end
    elseif item.kind == 'custom' then
        if type(item.check) ~= 'function' then
            return nil, 'custom acceptance needs a check function'
        end
    end
    return true
end

---@param value table
---@param schema table
---@return boolean ok
---@return string? err
local function check_schema(value, schema)
    if type(value) ~= 'table' then
        return nil, 'schema value must be a table'
    end
    for field, want in pairs(schema.types or {}) do
        if type(value[field]) ~= want then
            return nil, 'field ' .. field .. ' must be ' .. want
        end
    end
    for _, field in ipairs(schema.required or {}) do
        if value[field] == nil then
            return nil, 'missing required field ' .. field
        end
    end
    return true
end

---@param run table
---@param item table
---@param deps table
---@return AiHarnessCheck
local function run_check(run, item, deps)
    if item.kind == 'command' then
        local result = deps.run_command(item.argv)
        if result.exit == nil then
            return { kind = item.kind, pass = false, detail = tostring(result.error) }
        end
        return {
            kind = item.kind,
            pass = result.exit == 0,
            detail = 'exit=' .. tostring(result.exit),
        }
    elseif item.kind == 'diagnostics' then
        local diagnostics = deps.get_diagnostics(run)
        local errors = diagnostics.errors or 0
        return {
            kind = item.kind,
            pass = errors <= item.max_errors,
            detail = 'errors=' .. errors .. ' max=' .. item.max_errors,
        }
    elseif item.kind == 'schema' then
        local ok, err = check_schema(item.value, item.schema)
        return { kind = item.kind, pass = ok == true, detail = ok == true and 'valid' or tostring(err) }
    else
        local ok, check_err = pcall(item.check, run)
        if not ok then
            return { kind = item.kind, pass = false, detail = 'check raised: ' .. tostring(check_err) }
        end
        return { kind = item.kind, pass = check_err ~= false and true or false, detail = 'custom' }
    end
end

---Evaluate acceptance criteria for a run. `deps.run_command` and
---`deps.get_diagnostics` are injected; defaults use vim.system when
---available and report unavailable otherwise.
---@param run table
---@param acceptance table[]
---@param deps? table
---@return table? verdict {pass: boolean, checks: AiHarnessCheck[]}
---@return string? err
function M.evaluate(run, acceptance, deps)
    if type(run) ~= 'table' then
        return nil, 'run must be a table'
    end
    if type(acceptance) ~= 'table' or #acceptance == 0 then
        return nil, 'acceptance must be a non-empty array'
    end
    if #acceptance > ACCEPTANCE_MAX then
        return nil, 'acceptance list exceeds bound'
    end
    deps = deps or {}
    local run_command = deps.run_command or default_run_command
    local get_diagnostics = deps.get_diagnostics or function()
        return { errors = 0, unavailable = true }
    end
    local verdict = { pass = true, checks = {} }
    for i, item in ipairs(acceptance) do
        local valid, err = validate_item(item)
        if not valid then
            return nil, 'acceptance[' .. i .. ']: ' .. tostring(err)
        end
        local check = run_check(run, item, {
            run_command = run_command,
            get_diagnostics = get_diagnostics,
        })
        verdict.checks[#verdict.checks + 1] = check
        if not check.pass then
            verdict.pass = false
        end
    end
    return verdict
end

return M
