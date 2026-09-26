-- /qompassai/Diver/lua/ai/inference/kv_policy.lua
-- KV-cache quantization precision policy (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Plain words: this module does NOT quantize anything and cannot make
-- a model use fewer bits. It encodes the precision rules from
-- DeepSeek-V4.1-Flash (arXiv:2609.19969, Sec. 2.4.4) as a checkable
-- policy table, so an inference setup can be validated against them:
--   * global/main KV cache may use 4-bit (FP4 with quantization-aware
--     training in the paper);
--   * local / sliding-window-attention KV keeps higher precision: the
--     paper retains FP8 because local attention is
--     quantization-sensitive;
--   * indexer queries/keys may use 4-bit;
--   * quantize AFTER RoPE, never before (RoPE changes the value
--     distribution quantization relies on);
--   * Engram-style conditional memory embeddings stay at 8-bit.
-- Use M.validate(cfg) to check a setup; an empty violation list
-- means compliant. Fields you do not describe are not judged.

local M = {}

---@class AiKvPolicyComponent
---@field min_bits integer minimum allowed bits for the component
---@field recommended string recommended precision label
---@field note string why this rule exists

---@class AiKvPolicy
---@field version integer policy schema version
---@field source string where the rules come from
---@field components table<string, AiKvPolicyComponent>

---@type AiKvPolicy
local POLICY = {
    version = 1,
    source = 'DeepSeek-V4.1-Flash, arXiv:2609.19969, Sec. 2.4.4 (guidelines; not an implementation)',
    components = {
        global_kv = {
            min_bits = 4,
            recommended = 'fp4',
            note = 'Global KV tolerates 4-bit with quantization-aware training.',
        },
        local_kv = {
            min_bits = 8,
            recommended = 'fp8',
            note = 'Local/SWA KV is quantization-sensitive; keep 8-bit or higher.',
        },
        indexer_q = {
            min_bits = 4,
            recommended = 'fp4',
            note = 'Indexer queries tolerate 4-bit.',
        },
        indexer_k = {
            min_bits = 4,
            recommended = 'fp4',
            note = 'Indexer keys tolerate 4-bit.',
        },
        engram = {
            min_bits = 8,
            recommended = 'fp8',
            note = 'Engram memory embeddings/projections stay at 8-bit.',
        },
    },
}

-- Aliases accepted by M.recommend; canonical names are the keys above.
local COMPONENT_ALIASES = {
    swa_kv = 'local_kv',
    sliding_window_kv = 'local_kv',
    index_query = 'indexer_q',
    index_key = 'indexer_k',
}

-- Fixed check order so validate() output is deterministic.
---@type string[]
local COMPONENT_ORDER = { 'global_kv', 'local_kv', 'indexer_q', 'indexer_k', 'engram' }

-- Which validate() cfg field feeds each component. indexer_q and
-- indexer_k share the indexer_bits field; both are reported.
local COMPONENT_FIELDS = {
    global_kv = 'kv_bits',
    local_kv = 'swa_bits',
    indexer_q = 'indexer_bits',
    indexer_k = 'indexer_bits',
    engram = 'engram_bits',
}

---Return a deep copy of the policy table. Callers may mutate the
---copy; the module's canonical policy never changes.
---@return AiKvPolicy
function M.policy()
    return vim.deepcopy(POLICY)
end

---@param component any
---@return string? canonical
local function canonical_component(component)
    if type(component) ~= 'string' then
        return nil
    end
    if POLICY.components[component] ~= nil then
        return component
    end
    return COMPONENT_ALIASES[component]
end

---Recommended precision label for a policy component, e.g. 'fp4'.
---Accepts aliases: 'swa_kv' and 'sliding_window_kv' map to local_kv.
---@param component string
---@return string? precision
---@return string? err
function M.recommend(component)
    local canonical = canonical_component(component)
    if canonical == nil then
        return nil, 'recommend: unknown component ' .. vim.inspect(component)
    end
    return POLICY.components[canonical].recommended, nil
end

---@param violations string[]
---@param field string
---@param component string
---@param bits any
local function check_bits(violations, field, component, bits)
    local rule = POLICY.components[component]
    if type(bits) ~= 'number' or bits % 1 ~= 0 or bits < 1 then
        violations[#violations + 1] = field .. ': must be a positive integer number of bits'
        return
    end
    if bits < rule.min_bits then
        violations[#violations + 1] = component
            .. ': '
            .. tostring(bits)
            .. ' bits below policy minimum of '
            .. tostring(rule.min_bits)
            .. ' bits'
    end
end

---Validate an inference setup against the policy. cfg fields are all
---optional; absent fields are not judged:
---  kv_bits      global/main KV cache bits
---  rope_order   'after' (required when present); 'before' violates
---  swa_bits     local/sliding-window KV bits
---  indexer_bits indexer query/key bits (checked for both)
---  engram_bits  Engram memory embedding bits
---@param cfg table
---@return string[]? violations empty when compliant; deterministic order
---@return string? err
function M.validate(cfg)
    if type(cfg) ~= 'table' then
        return nil, 'validate: cfg must be a table'
    end
    ---@type string[]
    local violations = {}
    for _, component in ipairs(COMPONENT_ORDER) do
        local field = COMPONENT_FIELDS[component]
        if cfg[field] ~= nil then
            check_bits(violations, field, component, cfg[field])
        end
    end
    if cfg.rope_order ~= nil then
        if cfg.rope_order ~= 'after' then
            violations[#violations + 1] = 'rope_order: quantizing '
                .. vim.inspect(cfg.rope_order)
                .. ' RoPE violates policy (must quantize after RoPE)'
        end
    end
    return violations, nil
end

return M
