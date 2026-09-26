-- /qompassai/Diver/lua/ai/retrieval/two_stage.lua
-- Coarse-to-fine candidate ranker for the ai/ stack (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: when you have far more candidates than you can
-- afford to score carefully, first do a cheap pass over ALL of
-- them in blocks, keep only the best blocks as a candidate pool,
-- then spend the expensive scoring only inside that pool.
--
-- The shape borrows from DeepSeek-V4.1-Flash's Hierarchical Sparse
-- Indexer (arXiv:2609.19969): a first pass selects blocks by their
-- maximum score into a shared candidate pool, and later (deeper,
-- costlier) scoring is restricted to that pool. Here the "cheap
-- indexer" is a pure-Lua token-overlap scorer and the "expensive
-- indexer" is a caller-provided fine_fn -- for example an LLM
-- relevance call -- which therefore runs on a bounded subset.
--
-- Guarantees: fine_fn is only ever called with pool members;
-- results are deterministic (ties break by original order);
-- nothing here raises on external input.

local M = {}

local BLOCK_SIZE_DEFAULT = 8
local POOL_BLOCKS_DEFAULT = 4
local TOP_K_DEFAULT = 10

---@class AiTwoStageOpts
---@field block_size? integer candidates per coarse block
---@field pool_size? integer max blocks admitted to the candidate pool
---@field top_k? integer max final hits returned
---@field text_of? fun(item: any): string extract searchable text
---@field coarse_fn? fun(block_text: string, query: string): number block scorer
---@field fine_fn fun(items: any[], query: string): AiFineHit[] required expensive scorer

---@class AiFineHit
---@field item any must be identical to a pool member
---@field score number

---@class AiRankedHit
---@field item any
---@field score number
---@field rank integer 1-based final rank

---@param value any
---@param what string
---@return boolean ok
---@return string? err
local function check_pos_int(value, what)
    if type(value) ~= 'number' then
        return false, what .. ' must be a number'
    end
    if value ~= value or value == math.huge or value == -math.huge then
        return false, what .. ' must be finite'
    end
    if value % 1 ~= 0 then
        return false, what .. ' must be an integer'
    end
    if value < 1 then
        return false, what .. ' must be >= 1'
    end
    return true, nil
end

---@param item any
---@return string text
local function default_text_of(item)
    if type(item) == 'string' then
        return item
    end
    if type(item) == 'table' then
        local text = item.text
        if type(text) ~= 'string' then
            text = item.content
        end
        if type(text) ~= 'string' then
            text = item.title
        end
        if type(text) == 'string' then
            return text
        end
    end
    return ''
end

---@param text string
---@return table<string, integer> term -> frequency
local function term_freqs(text)
    local freqs = {}
    for term in text:lower():gmatch('%w+') do
        freqs[term] = (freqs[term] or 0) + 1
    end
    return freqs
end

---Cheap pure-Lua scorer: sum of query-term frequencies in the text.
---Deterministic and free of external calls, so it can run over the
---whole candidate set.
---@param block_text string
---@param query string
---@return number score
local function default_coarse_fn(block_text, query)
    local freqs = term_freqs(block_text)
    local score = 0
    for term in query:lower():gmatch('%w+') do
        score = score + (freqs[term] or 0)
    end
    return score
end

---@param opts any
---@return table? normalized
---@return string? err
local function normalize_opts(opts)
    if type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end
    if type(opts.fine_fn) ~= 'function' then
        return nil, 'opts.fine_fn is required'
    end
    local out = {
        block_size = opts.block_size,
        pool_size = opts.pool_size,
        top_k = opts.top_k,
        fine_fn = opts.fine_fn,
        coarse_fn = opts.coarse_fn,
        text_of = opts.text_of,
    }
    if out.block_size == nil then
        out.block_size = BLOCK_SIZE_DEFAULT
    end
    if out.pool_size == nil then
        out.pool_size = POOL_BLOCKS_DEFAULT
    end
    if out.top_k == nil then
        out.top_k = TOP_K_DEFAULT
    end
    if out.coarse_fn == nil then
        out.coarse_fn = default_coarse_fn
    end
    if out.text_of == nil then
        out.text_of = default_text_of
    end
    for _, pair in ipairs({
        { 'block_size', out.block_size },
        { 'pool_size', out.pool_size },
        { 'top_k', out.top_k },
    }) do
        local ok, err = check_pos_int(pair[2], 'opts.' .. pair[1])
        if not ok then
            return nil, err
        end
    end
    if type(out.coarse_fn) ~= 'function' then
        return nil, 'opts.coarse_fn must be a function'
    end
    if type(out.text_of) ~= 'function' then
        return nil, 'opts.text_of must be a function'
    end
    return out, nil
end

---@param items any[]
---@param text_of fun(item: any): string
---@param block_size integer
---@return table[]? blocks ({ index = integer, items = any[], text = string })
---@return string? err when text_of breaks its contract; never raises
local function partition_blocks(items, text_of, block_size)
    local blocks = {}
    local index = 1
    while index <= #items do
        local block_items = {}
        local parts = {}
        local last = math.min(index + block_size - 1, #items)
        for i = index, last do
            block_items[#block_items + 1] = items[i]
            -- text_of is caller code: a raise or a non-string return
            -- must become an error, never escape M.rank.
            local text_ok, text = pcall(text_of, items[i])
            if not text_ok then
                return nil, 'text_of raised: ' .. tostring(text)
            end
            if type(text) ~= 'string' then
                return nil, 'text_of must return a string'
            end
            parts[#parts + 1] = text
        end
        blocks[#blocks + 1] = {
            index = #blocks + 1,
            items = block_items,
            text = table.concat(parts, '\n'),
        }
        index = last + 1
    end
    return blocks
end

---@param hits AiFineHit[]
---@param pool any[]
---@return boolean ok
---@return string? err
local function check_hits(hits, pool)
    if type(hits) ~= 'table' then
        return false, 'fine_fn must return an array of {item, score}'
    end
    local in_pool = {}
    for _, item in ipairs(pool) do
        in_pool[item] = true
    end
    for pos, hit in ipairs(hits) do
        if type(hit) ~= 'table' then
            return false, 'fine_fn hit ' .. pos .. ' is not a table'
        end
        if type(hit.score) ~= 'number' or hit.score ~= hit.score then
            return false, 'fine_fn hit ' .. pos .. ' has a bad score'
        end
        if hit.item == nil or not in_pool[hit.item] then
            return false, 'fine_fn returned an item outside the candidate pool'
        end
    end
    return true, nil
end

---Rank candidates coarse-to-fine. Stage 1 scores every block with
---the cheap coarse_fn and keeps the best pool_size blocks; stage 2
---runs the caller's fine_fn only on that pool and returns the best
---top_k hits. Never raises on external input.
---@param candidates any[] array of items (strings or tables)
---@param query string non-empty query text
---@param opts AiTwoStageOpts
---@return AiRankedHit[]? hits, sorted by score desc, ties by input order
---@return string? err
function M.rank(candidates, query, opts)
    if type(candidates) ~= 'table' then
        return nil, 'candidates must be an array'
    end
    if type(query) ~= 'string' or query == '' then
        return nil, 'query must be a non-empty string'
    end
    local cfg, cfg_err = normalize_opts(opts)
    if cfg == nil then
        return nil, cfg_err
    end
    assert(cfg_err == nil, 'normalize_opts failed without an error')
    if #candidates == 0 then
        return {}, nil
    end

    -- Stage 1: cheap scoring over ALL candidates, one block at a time.
    local blocks, blocks_err = partition_blocks(candidates, cfg.text_of, cfg.block_size)
    if blocks == nil then
        return nil, blocks_err
    end
    assert(blocks_err == nil, 'partition_blocks failed without an error')
    local scored = {}
    for _, block in ipairs(blocks) do
        local ok, score = pcall(cfg.coarse_fn, block.text, query)
        if not ok or type(score) ~= 'number' or score ~= score then
            return nil, 'coarse_fn failed on block ' .. block.index
        end
        scored[#scored + 1] = { block = block, score = score }
    end
    table.sort(scored, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.block.index < b.block.index
    end)

    -- The candidate pool: items of the winning blocks, in original
    -- input order so fine_fn sees a stable sequence.
    local pool = {}
    local pool_count = math.min(cfg.pool_size, #scored)
    for rank = 1, pool_count do
        for _, item in ipairs(scored[rank].block.items) do
            pool[#pool + 1] = item
        end
    end
    local position_of = {}
    for pos, item in ipairs(candidates) do
        if position_of[item] == nil then
            position_of[item] = pos
        end
    end
    table.sort(pool, function(a, b)
        return (position_of[a] or 0) < (position_of[b] or 0)
    end)

    -- Stage 2: the expensive scorer runs ONLY on the pool.
    local fine_ok, hits = pcall(cfg.fine_fn, pool, query)
    if not fine_ok then
        return nil, 'fine_fn raised: ' .. tostring(hits)
    end
    local hits_ok, hits_err = check_hits(hits, pool)
    if not hits_ok then
        return nil, hits_err
    end
    table.sort(hits, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return (position_of[a.item] or 0) < (position_of[b.item] or 0)
    end)
    local out = {}
    local keep = math.min(cfg.top_k, #hits)
    for rank = 1, keep do
        out[rank] = { item = hits[rank].item, score = hits[rank].score, rank = rank }
    end
    return out, nil
end

return M
