--- Joint-attention client for the editor (MATE protocol sketch).
---
--- Landed in the live config 2026-10-12 on Matt's word (MATE decision
--- 5); written against the strict Lua contract. Mirror to the diver
--- repo follows Matt's live validation, per the live-first workflow.
---
--- The protocol (see crates/phlow-attention in the phlow repo): agents
--- that did not design conventions together coordinate by attending to
--- the same environment-grounded objects. Each agent derives an
--- ordered *focus* from a shared *saliency snapshot* of the workspace;
--- the snapshot's canonical hash is the frame. Alignment between two
--- foci is defined only inside one frame; when two agents' top target
--- coincides, the lexicographically smaller agent id holds it and the
--- other defers.
---
--- This module is the client side: it computes a snapshot from editor
--- state, derives the editor's focus, and publishes/reads foci through
--- the existing MCP client (`ai.mcp.client`) to the phlow server's
--- `flow_attention_*` tools. Publishing requires the named server
--- session to be running already — this module never spawns servers
--- and never invents success: a down session is a structured
--- `unavailable` callback error, not a silent drop.
---
--- Frame honesty: a snapshot is only the same frame as another agent's
--- when computed from the same signal set. This editor-side producer
--- has diagnostics and open-buffer state but no SCIP graph, so its
--- centrality term is 0 and its frames will (correctly) refuse to
--- align with a SCIP-fed producer's frames. The shared-frame path is
--- `M.derive` over a snapshot received from the producer of record;
--- `M.snapshot_from_editor` is for editor-only coordination.

local client = require('ai.mcp.client')

---@class AttentionFocus
---@field agent_id string
---@field snapshot_hash string
---@field seq integer
---@field targets string[]

---@class AttentionSnapshot
---@field hash string
---@field scores table<string, number>

---@class AttentionAlignment
---@field score number
---@field shared_targets integer
---@field top_shared boolean

---@class AttentionDecision
---@field decision string
---@field holder string?
---@field reason string?
---@field target string?

-- Protocol constants. These mirror crates/phlow-attention exactly;
-- changing one side without the other breaks frame agreement.
local AGENT_ID_MAX_BYTES = 128
local FOCUS_TARGETS_MAX = 8
local OPEN_IN_EDITOR_BONUS = 0.01
local SNAPSHOT_TARGETS_MAX = 4096
local TARGET_ID_MAX_BYTES = 512
local WEIGHT_DIAGNOSTIC_ERRORS = 0.25
local WEIGHT_DIAGNOSTIC_WARNINGS = 0.10
local WEIGHT_GRAPH_CENTRALITY = 0.20
local WEIGHT_NAMED_IN_TASK = 0.35
local WEIGHT_RECENCY = 0.10

-- Editor-scan bounds: this module reads editor state, never the disk.
local BUFFERS_SCANNED_MAX = 128
local DIAGNOSTIC_SEVERITY_ERROR = 1
local DIAGNOSTIC_SEVERITY_WARN = 2
local TOOL_TIMEOUT_MS = 5000

---@type { server: string }
local config = { server = 'phlow' }

--- Clamp to the unit interval; non-finite input narrows to 0, exactly
--- like the reference implementation's poisoning bound.
---@param value number
---@return number
local function unit(value)
    if value ~= value or value == math.huge or value == -math.huge then
        return 0.0
    end
    if value < 0.0 then
        return 0.0
    end
    if value > 1.0 then
        return 1.0
    end
    return value
end

---@param count integer
---@param saturation number
---@return number
local function saturating(count, saturation)
    if count <= 0 then
        return 0.0
    end
    return count / (count + saturation)
end

--- The saliency function, term for term the reference formula.
---@param named_in_task boolean
---@param errors integer
---@param warnings integer
---@param centrality number
---@param recency number
---@param open_in_editor boolean
---@return number
local function saliency(named_in_task, errors, warnings, centrality, recency, open_in_editor)
    local score = 0.0
    if named_in_task then
        score = score + WEIGHT_NAMED_IN_TASK
    end
    score = score + WEIGHT_DIAGNOSTIC_ERRORS * saturating(errors, 4.0)
    score = score + WEIGHT_DIAGNOSTIC_WARNINGS * saturating(warnings, 8.0)
    score = score + WEIGHT_GRAPH_CENTRALITY * unit(centrality)
    score = score + WEIGHT_RECENCY * unit(recency)
    if open_in_editor then
        score = score + OPEN_IN_EDITOR_BONUS
    end
    return unit(score)
end

--- Identifier rules shared with the reference implementation.
---@param raw string
---@param max_bytes integer
---@return boolean
local function id_is_valid(raw, max_bytes)
    return raw ~= '' and #raw <= max_bytes and raw:find('%c') == nil
end

--- The canonical frame: one `id<TAB>score` line per target, ids
--- sorted, scores at six decimals; the SHA-256 of that text is the
--- frame identity two agents compare before aligning anything.
---@param scores table<string, number>
---@return string
local function canonical_frame(scores)
    local ids = {}
    for id in pairs(scores) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local lines = {}
    for _, id in ipairs(ids) do
        lines[#lines + 1] = string.format('%s\t%.6f\n', id, scores[id])
    end
    return table.concat(lines)
end

--- Targets of a focus as a set, for overlap arithmetic.
---@param focus AttentionFocus
---@return table<string, boolean>
local function target_set(focus)
    local set = {}
    for _, target in ipairs(focus.targets) do
        set[target] = true
    end
    return set
end

--- Decode a tool result's text content into a table. The MCP envelope
--- is validated field by field; a malformed reply is an error, never
--- a partially trusted table.
---@param result table
---@return table? payload
---@return string? err
local function decode_tool_payload(result)
    local content = result.content
    if type(content) ~= 'table' or type(content[1]) ~= 'table' or type(content[1].text) ~= 'string' then
        return nil, 'attention: malformed tool result envelope'
    end
    local ok, decoded = pcall(vim.json.decode, content[1].text)
    if not ok or type(decoded) ~= 'table' then
        return nil, 'attention: tool result is not a JSON object'
    end
    if result.isError == true then
        local message = decoded.error
        if type(message) ~= 'string' then
            message = 'attention tool reported an error'
        end
        return nil, message
    end
    return decoded, nil
end

---@param name string
---@param args table
---@param callback fun(err: string?, payload: table?)
local function call_attention_tool(name, args, callback)
    client.request(config.server, 'tools/call', {
        name = name,
        arguments = args,
    }, function(err, result)
        if err ~= nil then
            callback('attention: unavailable: ' .. err, nil)
            return
        end
        if type(result) ~= 'table' then
            callback('attention: unavailable: empty tool result', nil)
            return
        end
        local payload, decode_err = decode_tool_payload(result)
        if payload == nil then
            callback(decode_err, nil)
            return
        end
        callback(nil, payload)
    end, TOOL_TIMEOUT_MS)
end

local M = {}

--- Alignment between two foci, or nil + error across frames. Mirrors
--- the reference: both foci are validated, hashes must match, and the
--- score is the Jaccard overlap of the target sets.
---@param a AttentionFocus
---@param b AttentionFocus
---@return AttentionAlignment? alignment
---@return string? err
function M.alignment(a, b)
    if a.snapshot_hash ~= b.snapshot_hash then
        return nil, 'snapshot mismatch: foci from different frames are not comparable'
    end
    local b_set = target_set(b)
    local shared = 0
    for _, target in ipairs(a.targets) do
        if b_set[target] then
            shared = shared + 1
        end
    end
    local union = #a.targets + #b.targets - shared
    local score = 1.0
    if union > 0 then
        score = shared / union
    end
    return {
        score = score,
        shared_targets = shared,
        top_shared = a.targets[1] ~= nil and a.targets[1] == b.targets[1],
    },
        nil
end

--- The coordination rule, computed locally and identically by both
--- sides: same top target → serialize under the smaller agent id;
--- mismatched frames or invalid foci → reject; otherwise parallel.
---@param a AttentionFocus
---@param b AttentionFocus
---@return AttentionDecision
function M.decide(a, b)
    if not id_is_valid(a.agent_id, AGENT_ID_MAX_BYTES) or not id_is_valid(b.agent_id, AGENT_ID_MAX_BYTES) then
        return { decision = 'reject', reason = 'invalid_focus' }
    end
    if a.snapshot_hash ~= b.snapshot_hash then
        return { decision = 'reject', reason = 'snapshot_mismatch' }
    end
    local top_a = a.targets[1]
    local top_b = b.targets[1]
    if top_a ~= nil and top_a == top_b then
        return {
            decision = 'serialize',
            holder = a.agent_id < b.agent_id and a.agent_id or b.agent_id,
            target = top_a,
        }
    end
    return { decision = 'parallel' }
end

--- Derive a focus from a snapshot: the snapshot's own ranking, taken
--- verbatim — ordering is never agent-chosen. `filter` (a set of
--- target ids) restricts the ranking without reordering it.
---@param snapshot AttentionSnapshot
---@param agent_id string
---@param seq integer
---@param filter table<string, boolean>?
---@return AttentionFocus? focus
---@return string? err
function M.derive(snapshot, agent_id, seq, filter)
    if not id_is_valid(agent_id, AGENT_ID_MAX_BYTES) then
        return nil, 'attention: invalid agent id'
    end
    local ranked = {}
    for id, score in pairs(snapshot.scores) do
        ranked[#ranked + 1] = { id = id, score = score }
    end
    table.sort(ranked, function(left, right)
        if left.score ~= right.score then
            return left.score > right.score
        end
        return left.id < right.id
    end)
    local targets = {}
    for _, entry in ipairs(ranked) do
        if #targets >= FOCUS_TARGETS_MAX then
            break
        end
        if filter == nil or filter[entry.id] then
            targets[#targets + 1] = entry.id
        end
    end
    return {
        agent_id = agent_id,
        snapshot_hash = snapshot.hash,
        seq = seq,
        targets = targets,
    },
        nil
end

--- Compute the editor-side snapshot: one entry per named buffer
--- (workspace-relative path as target id), scored from task naming,
--- live diagnostics, and open state. Buffers without a file name and
--- paths outside the working directory are skipped — a target id
--- must name a workspace file on every agent.
---@param task_text string
---@return AttentionSnapshot
function M.snapshot_from_editor(task_text)
    local cwd = vim.fn.getcwd()
    local scores = {}
    local scanned = 0
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if scanned >= BUFFERS_SCANNED_MAX or vim.tbl_count(scores) >= SNAPSHOT_TARGETS_MAX then
            break
        end
        scanned = scanned + 1
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name ~= '' and name:sub(1, #cwd + 1) == cwd .. '/' then
                local relative = name:sub(#cwd + 2)
                if id_is_valid(relative, TARGET_ID_MAX_BYTES) then
                    local errors = 0
                    local warnings = 0
                    for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
                        if diagnostic.severity == DIAGNOSTIC_SEVERITY_ERROR then
                            errors = errors + 1
                        elseif diagnostic.severity == DIAGNOSTIC_SEVERITY_WARN then
                            warnings = warnings + 1
                        end
                    end
                    local named = task_text:find(relative, 1, true) ~= nil
                    scores[relative] = saliency(named, errors, warnings, 0.0, 0.0, true)
                end
            end
        end
    end
    return { hash = vim.fn.sha256(canonical_frame(scores)), scores = scores }
end

--- Publish a focus through the MCP client to the phlow server's
--- coordination board. The server binds the publish to the client's
--- transport identity, so `focus.agent_id` must be the name this
--- editor registered as at initialize.
---@param focus AttentionFocus
---@param callback fun(err: string?, payload: table?)
function M.publish(focus, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    call_attention_tool('flow_attention_publish', { focus = focus }, callback)
end

--- Read a partner's advertised focus from the board. A successful
--- payload's `focus` field is the partner's focus document, or nil
--- when the partner has not published.
---@param agent_id string
---@param callback fun(err: string?, payload: table?)
function M.read_focus(agent_id, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    call_attention_tool('flow_attention_focus', { agent_id = agent_id }, callback)
end

--- Ask the board for the coordination decision against a partner.
---@param agent_id string
---@param callback fun(err: string?, payload: table?)
function M.request_decision(agent_id, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    call_attention_tool('flow_attention_decide', { agent_id = agent_id }, callback)
end

---@class AttentionSetupOpts
---@field server string?

--- Select the MCP server name the attention tools are called on
--- (default `phlow`, the runtime that hosts the board).
---@param opts AttentionSetupOpts
function M.setup(opts)
    if opts.server ~= nil then
        assert(type(opts.server) == 'string' and opts.server ~= '', 'server must be non-empty')
        config.server = opts.server
    end
end

return M
