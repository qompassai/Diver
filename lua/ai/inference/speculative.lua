-- /qompassai/Diver/lua/ai/inference/speculative.lua
-- Speculative decoding helpers: llama.cpp integration + agent-level draft-verify (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Plain words: token-level speculative decoding needs engine support,
-- so this module does NOT implement it. It does three honest things
-- inspired by DSpark in DeepSeek-V4.1-Flash (arXiv:2609.19969):
--   (a) probe for a local llama.cpp server and build a validated
--       --draft-model config for its real speculative decoding;
--   (b) lift "confidence-scheduled verification" to the agent workflow
--       level: a cheap model drafts, a capable model verifies, and a
--       caller-supplied confidence score decides whether the expensive
--       verify step can be skipped. Unlike DSpark, nothing is trained
--       here: the confidence function is yours (a heuristic, a small
--       classifier, a logprob read-out), and "tokens" are whole
--       draft strings, not vocabulary tokens.
--   (c) pick draft length / verify batch from a caller-supplied
--       profiled throughput table. This module measures nothing; the
--       profile comes from your own benchmarks (table-driven, no fake
--       telemetry).
--
-- All network probing is loopback-only unless allow_remote is set,
-- matching lua/ai/rose/http.lua.

local M = {}

local DETECT_TIMEOUT_MS_DEFAULT = 2000
local LLAMACPP_PORT_DEFAULT = 8080
local LOOPBACK_HOSTS = { ['127.0.0.1'] = true, ['localhost'] = true, ['::1'] = true }

local DRAFT_TOKENS_MAX = 16
local DRAFT_CHARS_MAX_DEFAULT = 4000
local VERIFY_BATCH_MAX = 32
local PROFILE_ENTRIES_MAX = 64
local ACCEPT_THRESHOLD_DEFAULT = 0.8

---@class AiInferenceEndpoint
---@field host string
---@field port integer

---@class AiInferenceDetectOpts
---@field host string? default '127.0.0.1'
---@field port integer? default 8080
---@field timeout_ms integer? default 2000
---@field allow_remote boolean? default false

---@class AiInferenceDraftConfigOpts
---@field draft_model_path string required, path to the draft GGUF
---@field n_draft integer? draft tokens per step, 1..16, default 5
---@field host string? default '127.0.0.1'
---@field port integer? default 8080
---@field endpoint AiInferenceEndpoint? alternative to host/port
---@field allow_remote boolean? default false

---@class AiInferenceDraftConfig
---@field server_url string base URL of the llama.cpp server
---@field draft_model_path string validated draft model path
---@field n_draft integer validated draft length
---@field server_argv string[] suggested argv fragment (informational)

---@class AiInferenceStats
---@field drafts integer draft_fn calls
---@field draft_chars integer draft characters produced
---@field accepted_direct integer drafts accepted without verify
---@field verify_calls integer verify_fn calls
---@field verified_chars integer verified output characters

---@class AiInferenceDraftVerifyOpts
---@field prompt string required, the task given to both models
---@field confidence_fn fun(draft_text: string): number required, returns 0..1
---@field accept_threshold number? accept directly when confidence >= this, 0..1, default 0.8
---@field max_draft_chars integer? hard cap on draft length, default 4000
---@field stats AiInferenceStats? accumulator, created by M.new_stats when omitted

---@class AiInferenceProfileEntry
---@field max_load number upper load bound for this row, 0..1
---@field draft_len integer draft length for this row, 1..16
---@field verify_batch integer verify batch for this row, 1..32

---Fresh stats accumulator with the canonical shape.
---@return AiInferenceStats
function M.new_stats()
    return {
        drafts = 0,
        draft_chars = 0,
        accepted_direct = 0,
        verify_calls = 0,
        verified_chars = 0,
    }
end

---@param stats AiInferenceStats
---@param field string
---@param delta integer
local function bump_stat(stats, field, delta)
    assert(type(stats) == 'table', 'bump_stat: stats must be a table')
    assert(type(field) == 'string', 'bump_stat: field must be a string')
    local current = stats[field]
    if type(current) ~= 'number' then
        current = 0
    end
    stats[field] = current + delta
end

---@param value any
---@param name string
---@return boolean ok
local function is_loopback_host(value, name)
    assert(type(name) == 'string', 'is_loopback_host: name must be a string')
    return type(value) == 'string' and value ~= '' and LOOPBACK_HOSTS[value] == true
end

---@param value any
---@param name string
---@return boolean ok
local function is_valid_port(value, name)
    assert(type(name) == 'string', 'is_valid_port: name must be a string')
    return type(value) == 'number' and value % 1 == 0 and value >= 1 and value <= 65535
end

---Probe for a listening TCP server (best-effort health check). This
---proves something listens on host:port, not that it is llama.cpp:
---confirm identity with the server's /health endpoint before trusting
---it. The callback always fires on the main loop.
---@param opts AiInferenceDetectOpts?
---@param cb fun(err: string?, endpoint: AiInferenceEndpoint?)
function M.detect(opts, cb)
    assert(type(cb) == 'function', 'detect: cb must be a function')
    assert(opts == nil or type(opts) == 'table', 'detect: opts must be a table')
    opts = opts or {}
    local host = opts.host or '127.0.0.1'
    local port = opts.port or LLAMACPP_PORT_DEFAULT
    local timeout_ms = opts.timeout_ms or DETECT_TIMEOUT_MS_DEFAULT
    local allow_remote = opts.allow_remote == true

    local function fail(message)
        vim.schedule(function()
            cb(message, nil)
        end)
    end

    if type(host) ~= 'string' or host == '' then
        fail('detect: host must be a nonempty string')
        return
    end
    if not allow_remote and not is_loopback_host(host, 'host') then
        fail('detect: refusing non-loopback host without allow_remote')
        return
    end
    if not is_valid_port(port, 'port') then
        fail('detect: port must be an integer in 1..65535')
        return
    end
    if type(timeout_ms) ~= 'number' or timeout_ms % 1 ~= 0 or timeout_ms < 1 then
        fail('detect: timeout_ms must be a positive integer')
        return
    end

    local uv = vim.uv
    if uv == nil then
        fail('detect: vim.uv unavailable')
        return
    end
    local tcp = uv.new_tcp()
    if tcp == nil then
        fail('detect: cannot allocate TCP handle')
        return
    end
    local timer = uv.new_timer()
    if timer == nil then
        tcp:close()
        fail('detect: cannot allocate timer')
        return
    end

    -- Same finish discipline as lua/ai/rose/http.lua: exactly-once,
    -- teardown first, user callback on the main loop.
    local finished = false
    local function finish(err, endpoint)
        if finished then
            return
        end
        finished = true
        timer:stop()
        timer:close()
        tcp:close()
        vim.schedule(function()
            cb(err, endpoint)
        end)
    end
    timer:start(timeout_ms, 0, function()
        finish('detect: timed out probing ' .. host .. ':' .. tostring(port), nil)
    end)
    tcp:connect(host, port, function(connect_err)
        if connect_err then
            finish('detect: no server at ' .. host .. ':' .. tostring(port), nil)
            return
        end
        finish(nil, { host = host, port = port })
    end)
end

---@param path any
---@return boolean ok
local function is_clean_path(path)
    return type(path) == 'string' and path ~= '' and path:find('\0', 1, true) == nil
end

---Validate a speculative-decoding setup for a llama.cpp server and
---return the resolved config. The config's server_argv is a suggested
---argv fragment only; start the server yourself.
---@param opts AiInferenceDraftConfigOpts
---@return AiInferenceDraftConfig? config
---@return string? err
function M.draft_config(opts)
    if type(opts) ~= 'table' then
        return nil, 'draft_config: opts must be a table'
    end
    if not is_clean_path(opts.draft_model_path) then
        return nil, 'draft_config: draft_model_path must be a nonempty path without NUL bytes'
    end
    local n_draft = opts.n_draft
    if n_draft == nil then
        n_draft = 5
    end
    if type(n_draft) ~= 'number' or n_draft % 1 ~= 0 or n_draft < 1 or n_draft > DRAFT_TOKENS_MAX then
        return nil, 'draft_config: n_draft must be an integer in 1..' .. DRAFT_TOKENS_MAX
    end
    local allow_remote = opts.allow_remote == true
    local host, port
    if opts.endpoint ~= nil then
        if type(opts.endpoint) ~= 'table' then
            return nil, 'draft_config: endpoint must be a table'
        end
        host = opts.endpoint.host
        port = opts.endpoint.port
    else
        host = opts.host or '127.0.0.1'
        port = opts.port or LLAMACPP_PORT_DEFAULT
    end
    if type(host) ~= 'string' or host == '' then
        return nil, 'draft_config: host must be a nonempty string'
    end
    if not allow_remote and not is_loopback_host(host, 'host') then
        return nil, 'draft_config: refusing non-loopback host without allow_remote'
    end
    if not is_valid_port(port, 'port') then
        return nil, 'draft_config: port must be an integer in 1..65535'
    end
    local url_host = host
    if url_host:find(':', 1, true) ~= nil then
        -- IPv6 literals need brackets inside a URL; server_argv keeps
        -- the bare host form that llama.cpp's --host expects.
        url_host = '[' .. url_host .. ']'
    end
    local server_url = 'http://' .. url_host .. ':' .. tostring(port)
    return {
        server_url = server_url,
        draft_model_path = opts.draft_model_path,
        n_draft = n_draft,
        server_argv = {
            '--host',
            host,
            '--port',
            tostring(port),
            '--draft-model',
            opts.draft_model_path,
            '--draft-max',
            tostring(n_draft),
        },
    },
        nil
end

---@param confidence number
---@return boolean ok
local function is_confidence(confidence)
    return type(confidence) == 'number' and confidence == confidence and confidence >= 0 and confidence <= 1
end

---Length in bytes of the UTF-8 sequence starting with byte.
---Stray bytes each count as one so the walk never fails on
---hostile input and never reads past the string end.
---@param byte integer a single byte value, 0..255
---@return integer seq_len 1..4
local function utf8_seq_len(byte)
    assert(type(byte) == 'number', 'utf8_seq_len: byte must be a number')
    if byte >= 0xC2 and byte <= 0xDF then
        return 2
    elseif byte >= 0xE0 and byte <= 0xEF then
        return 3
    elseif byte >= 0xF0 and byte <= 0xF4 then
        return 4
    end
    return 1
end

---Count Unicode characters (codepoints) in text.
---@param text string
---@return integer char_count
local function count_chars(text)
    assert(type(text) == 'string', 'count_chars: text must be a string')
    local count = 0
    local byte_pos = 1
    local text_len = #text
    while byte_pos <= text_len do
        byte_pos = byte_pos + utf8_seq_len(text:byte(byte_pos))
        count = count + 1
    end
    return count
end

---Truncate text to at most max_chars Unicode characters, never
---splitting a codepoint: byte-based sub() can emit invalid UTF-8
---and over-truncates multibyte text.
---@param text string
---@param max_chars integer positive cap on characters kept
---@return string truncated text, at most max_chars characters
---@return integer char_count characters in the returned text
local function truncate_to_chars(text, max_chars)
    assert(type(text) == 'string', 'truncate_to_chars: text must be a string')
    assert(
        type(max_chars) == 'number' and max_chars % 1 == 0 and max_chars >= 1,
        'truncate_to_chars: max_chars must be a positive integer'
    )
    local byte_pos = 1
    local kept = 0
    local text_len = #text
    while kept < max_chars and byte_pos <= text_len do
        byte_pos = byte_pos + utf8_seq_len(text:byte(byte_pos))
        kept = kept + 1
    end
    return text:sub(1, byte_pos - 1), kept
end

---Agent-level draft-verify: draft_fn drafts cheaply, verify_fn (the
---capable model) runs only when confidence_fn(draft) falls below
---accept_threshold. Both model functions are pcall-guarded; a raise
---becomes an error return, never a crash. Drafts longer than
---max_draft_chars characters are truncated on a character boundary
---(documented, not silent: the cap is an explicit option, and byte
---based truncation would split multibyte codepoints).
---@param draft_fn fun(prompt: string): string?, string?
---@param verify_fn fun(prompt: string, draft_text: string): string?, string?
---@param opts AiInferenceDraftVerifyOpts
---@return string? result
---@return string? err
---@return boolean used_verify
function M.draft_verify(draft_fn, verify_fn, opts)
    assert(type(draft_fn) == 'function', 'draft_verify: draft_fn must be a function')
    assert(type(verify_fn) == 'function', 'draft_verify: verify_fn must be a function')
    assert(type(opts) == 'table', 'draft_verify: opts must be a table')
    assert(type(opts.confidence_fn) == 'function', 'draft_verify: opts.confidence_fn must be a function')
    if type(opts.prompt) ~= 'string' or opts.prompt == '' then
        return nil, 'draft_verify: opts.prompt must be a nonempty string', false
    end
    local accept_threshold = opts.accept_threshold
    if accept_threshold == nil then
        accept_threshold = ACCEPT_THRESHOLD_DEFAULT
    end
    if not is_confidence(accept_threshold) then
        return nil, 'draft_verify: opts.accept_threshold must be a number in 0..1', false
    end
    local max_draft_chars = opts.max_draft_chars
    if max_draft_chars == nil then
        max_draft_chars = DRAFT_CHARS_MAX_DEFAULT
    end
    if type(max_draft_chars) ~= 'number' or max_draft_chars % 1 ~= 0 or max_draft_chars < 1 then
        return nil, 'draft_verify: opts.max_draft_chars must be a positive integer', false
    end
    local stats = opts.stats
    if stats == nil then
        stats = M.new_stats()
    elseif type(stats) ~= 'table' then
        return nil, 'draft_verify: opts.stats must be a table', false
    end

    local draft_ok, draft_text, draft_err = pcall(draft_fn, opts.prompt)
    if not draft_ok then
        return nil, 'draft_verify: draft_fn raised: ' .. tostring(draft_text), false
    end
    if draft_err ~= nil then
        return nil, 'draft_verify: draft failed: ' .. tostring(draft_err), false
    end
    if type(draft_text) ~= 'string' then
        return nil, 'draft_verify: draft_fn must return a string', false
    end
    -- Character-aware truncation: the walk is bounded by
    -- max_draft_chars characters, and the returned count makes the
    -- draft_chars stat honest for multibyte text.
    local truncated, char_count = truncate_to_chars(draft_text, max_draft_chars)
    draft_text = truncated
    bump_stat(stats, 'drafts', 1)
    bump_stat(stats, 'draft_chars', char_count)

    local conf_ok, confidence = pcall(opts.confidence_fn, draft_text)
    if not conf_ok then
        return nil, 'draft_verify: confidence_fn raised: ' .. tostring(confidence), false
    end
    if not is_confidence(confidence) then
        return nil, 'draft_verify: confidence_fn must return a number in 0..1', false
    end
    -- Boundary semantics: threshold 0 accepts everything (confidence
    -- is always >= 0); threshold 1 accepts only perfect confidence.
    if confidence >= accept_threshold then
        bump_stat(stats, 'accepted_direct', 1)
        return draft_text, nil, false
    end

    local verify_ok, verified_text, verify_err = pcall(verify_fn, opts.prompt, draft_text)
    bump_stat(stats, 'verify_calls', 1)
    if not verify_ok then
        return nil, 'draft_verify: verify_fn raised: ' .. tostring(verified_text), true
    end
    if verify_err ~= nil then
        return nil, 'draft_verify: verify failed: ' .. tostring(verify_err), true
    end
    if type(verified_text) ~= 'string' then
        return nil, 'draft_verify: verify_fn must return a string', true
    end
    bump_stat(stats, 'verified_chars', count_chars(verified_text))
    return verified_text, nil, true
end

---@param entry any
---@param index integer
---@return string? err
local function validate_profile_entry(entry, index)
    if type(entry) ~= 'table' then
        return 'schedule_for_load: profile entry ' .. index .. ' must be a table'
    end
    if
        type(entry.max_load) ~= 'number'
        or entry.max_load ~= entry.max_load
        or entry.max_load < 0
        or entry.max_load > 1
    then
        return 'schedule_for_load: profile entry ' .. index .. '.max_load must be a number in 0..1'
    end
    if
        type(entry.draft_len) ~= 'number'
        or entry.draft_len % 1 ~= 0
        or entry.draft_len < 1
        or entry.draft_len > DRAFT_TOKENS_MAX
    then
        return 'schedule_for_load: profile entry '
            .. index
            .. '.draft_len must be an integer in 1..'
            .. DRAFT_TOKENS_MAX
    end
    if
        type(entry.verify_batch) ~= 'number'
        or entry.verify_batch % 1 ~= 0
        or entry.verify_batch < 1
        or entry.verify_batch > VERIFY_BATCH_MAX
    then
        return 'schedule_for_load: profile entry '
            .. index
            .. '.verify_batch must be an integer in 1..'
            .. VERIFY_BATCH_MAX
    end
    return nil
end

---Pick draft length / verify batch from a caller-supplied profiled
---throughput table. The profile is an array of rows sorted by
---strictly increasing max_load; the first row whose max_load covers
---the current load wins, and load above every row takes the last
---row. Returns a copy, so callers cannot corrupt the profile.
---@param profile AiInferenceProfileEntry[]
---@param load number measured system load, 0..1 (caller-measured)
---@return AiInferenceProfileEntry? choice
---@return string? err
function M.schedule_for_load(profile, load)
    if type(profile) ~= 'table' then
        return nil, 'schedule_for_load: profile must be a nonempty array'
    end
    -- ipairs stops at the first hole and would silently drop later
    -- rows, scheduling from the wrong row without an error. Reject
    -- sparse profiles (and non-array keys) up front instead.
    local key_count = 0
    local key_max = 0
    for key in pairs(profile) do
        if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 then
            return nil, 'schedule_for_load: profile must be a dense array of rows'
        end
        key_count = key_count + 1
        if key > key_max then
            key_max = key
        end
    end
    if key_count == 0 then
        return nil, 'schedule_for_load: profile must be a nonempty array'
    end
    if key_count ~= key_max then
        return nil, 'schedule_for_load: profile must be a dense array of rows (no holes)'
    end
    if key_count > PROFILE_ENTRIES_MAX then
        return nil, 'schedule_for_load: profile must have at most ' .. PROFILE_ENTRIES_MAX .. ' entries'
    end
    if type(load) ~= 'number' or load ~= load or load < 0 or load > 1 then
        return nil, 'schedule_for_load: load must be a number in 0..1'
    end
    local previous_max = -1
    -- Validate the whole profile before selecting: a malformed row must
    -- fail even when an earlier row already covers the load.
    for index, entry in ipairs(profile) do
        local entry_err = validate_profile_entry(entry, index)
        if entry_err ~= nil then
            return nil, entry_err
        end
        if entry.max_load <= previous_max then
            return nil, 'schedule_for_load: profile must be sorted by strictly increasing max_load'
        end
        previous_max = entry.max_load
    end
    for _, entry in ipairs(profile) do
        if load <= entry.max_load then
            return { max_load = entry.max_load, draft_len = entry.draft_len, verify_batch = entry.verify_batch }, nil
        end
    end
    local last = profile[#profile]
    return { max_load = last.max_load, draft_len = last.draft_len, verify_batch = last.verify_batch }, nil
end

return M
