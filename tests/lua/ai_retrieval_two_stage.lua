-- /qompassai/Diver/tests/lua/ai_retrieval_two_stage.lua
-- Self-test for ai.retrieval.two_stage (coarse-to-fine ranker).
--
-- Plain words: this script checks that cheap block scoring picks
-- a candidate pool, the expensive scorer only ever sees that
-- pool, results are deterministic, and bad input fails loudly.
-- It runs headless via `nvim -l`; it is not loaded at startup.
local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

local here = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(here, ':h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local two = require('ai.retrieval.two_stage')

-- Simple token-overlap fine scorer used as the "expensive" stage.
-- Reads text the same way the module's default text_of does.
local function item_text(item)
    if type(item) == 'string' then
        return item
    end
    if type(item) == 'table' then
        return item.text or item.content or item.title or ''
    end
    return ''
end

local function overlap_fine(items, query)
    local qterms = {}
    for term in query:lower():gmatch('%w+') do
        qterms[term] = true
    end
    local hits = {}
    for _, item in ipairs(items) do
        local text = item_text(item)
        local score = 0
        for term in text:lower():gmatch('%w+') do
            if qterms[term] then
                score = score + 1
            end
        end
        hits[#hits + 1] = { item = item, score = score }
    end
    return hits
end

-- Wrap a fine_fn so any item outside the original candidate set
-- aborts the test immediately.
local function guarded(candidates, fine)
    local allowed = {}
    for _, candidate in ipairs(candidates) do
        allowed[candidate] = true
    end
    return function(items, query)
        for _, item in ipairs(items) do
            assert(allowed[item], 'fine_fn saw an item outside the pool')
        end
        return fine(items, query)
    end
end

-- Normal ranking with the default coarse scorer.
local candidates = {}
for i = 1, 20 do
    candidates[i] = 'doc ' .. i .. ' about gardening'
end
candidates[3] = 'neovim plugin guide'
candidates[7] = 'neovim config tips'
candidates[15] = 'neovim lua api'
local out, err = two.rank(candidates, 'neovim plugin', {
    fine_fn = guarded(candidates, overlap_fine),
})
check(out ~= nil, 'rank ok: ' .. tostring(err))
check(#out == 10, 'default top_k is 10')
check(out[1].rank == 1 and out[10].rank == 10, 'rank fields are 1-based')
for i = 2, #out do
    check(out[i - 1].score >= out[i].score, 'hits sorted by score desc')
end
local in_top = {}
for _, hit in ipairs(out) do
    in_top[hit.item] = true
end
check(in_top['neovim plugin guide'], 'best match lands in top_k')

-- Determinism: same inputs give the same outputs.
local again = two.rank(candidates, 'neovim plugin', { fine_fn = overlap_fine })
check(#again == #out, 'deterministic length')
local same = true
for i = 1, #out do
    if again[i].item ~= out[i].item or again[i].score ~= out[i].score then
        same = false
    end
end
check(same, 'deterministic order and scores')

-- Empty input is an empty result, not an error.
local empty = two.rank({}, 'q', { fine_fn = overlap_fine })
check(empty ~= nil and #empty == 0, 'empty candidates give empty hits')

-- Pool bigger than the candidate set: fine_fn sees everything.
local small = { 'alpha', 'beta', 'gamma' }
local seen_count = 0
local small_out = two.rank(small, 'alpha', {
    block_size = 100,
    pool_size = 100,
    top_k = 5,
    fine_fn = function(items, query)
        seen_count = #items
        return overlap_fine(items, query)
    end,
})
check(seen_count == 3, 'oversized pool: fine_fn sees all candidates')
check(small_out ~= nil and #small_out == 3, 'top_k beyond pool returns the whole pool')

-- Duplicate candidates are separate entries, not an error.
local dups = { 'x one', 'x one', 'y two' }
local dup_out = two.rank(dups, 'x', { fine_fn = overlap_fine })
check(dup_out ~= nil and #dup_out == 3, 'duplicate candidates rank fine')

-- Strict pool test: a crafted coarse scorer picks exactly one
-- block; fine_fn must receive precisely those two items.
local items10 = { 'WIN one', 'WIN two', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' }
local received = nil
local craft_out, craft_err = two.rank(items10, 'WIN', {
    block_size = 2,
    pool_size = 1,
    top_k = 2,
    coarse_fn = function(block_text, _query)
        if block_text:find('WIN', 1, true) then
            return 100
        end
        return 0
    end,
    fine_fn = function(items, query)
        received = items
        return overlap_fine(items, query)
    end,
})
check(craft_out ~= nil, 'crafted rank ok: ' .. tostring(craft_err))
check(received ~= nil and #received == 2, 'fine_fn got exactly the winning block')
check(received[1] == 'WIN one' and received[2] == 'WIN two', 'fine_fn pool members arrive in original order')

-- fine_fn must not smuggle in items from outside the pool.
local bad_hit, bad_hit_err = two.rank({ 'a', 'b' }, 'a', {
    fine_fn = function()
        return { { item = 'INTRUDER', score = 99 } }
    end,
})
check(bad_hit == nil and bad_hit_err:find('outside the candidate pool') ~= nil, 'outside-pool fine hit is rejected')

-- fine_fn contract violations become errors, not crashes.
local bad_score = two.rank({ 'a' }, 'a', {
    fine_fn = function()
        return { { item = 'a', score = 'high' } }
    end,
})
check(bad_score == nil, 'non-numeric fine score rejected')
local raised, raised_err = two.rank({ 'a' }, 'a', {
    fine_fn = function()
        error('kaboom')
    end,
})
check(raised == nil and raised_err:find('raised') ~= nil, 'fine_fn raise becomes an error')
local nil_fine = two.rank({ 'a' }, 'a', {
    fine_fn = function()
        return nil
    end,
})
check(nil_fine == nil, 'nil fine result rejected')

-- Misuse: every bad input returns nil + error, never raises.
local mc = two.rank('nope', 'q', { fine_fn = overlap_fine })
check(mc == nil, 'rejects non-table candidates')
local mq, mq_err = two.rank({ 'a' }, '', { fine_fn = overlap_fine })
check(mq == nil and type(mq_err) == 'string', 'rejects empty query')
local mo, mo_err = two.rank({ 'a' }, 'q', nil)
check(mo == nil and mo_err:find('opts must be a table') ~= nil, 'rejects nil opts')
local mf, mf_err = two.rank({ 'a' }, 'q', {})
check(mf == nil and mf_err:find('fine_fn is required') ~= nil, 'fine_fn is required')
local mb = two.rank({ 'a' }, 'q', { block_size = 0, fine_fn = overlap_fine })
check(mb == nil, 'rejects block_size 0')
local mt = two.rank({ 'a' }, 'q', { top_k = 0, fine_fn = overlap_fine })
check(mt == nil, 'rejects top_k 0')
local mff = two.rank({ 'a' }, 'q', { fine_fn = 'x' })
check(mff == nil, 'rejects non-function fine_fn')
local mcf = two.rank({ 'a' }, 'q', { fine_fn = overlap_fine, coarse_fn = 'x' })
check(mcf == nil, 'rejects non-function coarse_fn')

-- Table candidates with a custom text extractor.
local docs = {
    { title = 'Neovim guide', body = 'editor docs' },
    { title = 'Cooking', body = 'neovim soup' },
}
local doc_out = two.rank(docs, 'neovim', {
    text_of = function(item)
        return item.title .. ' ' .. item.body
    end,
    fine_fn = function(items, _query)
        local hits = {}
        for _, item in ipairs(items) do
            local score = 0
            if item.title:lower():find('neovim', 1, true) then
                score = score + 10
            end
            hits[#hits + 1] = { item = item, score = score }
        end
        return hits
    end,
})
check(doc_out ~= nil and doc_out[1].item.title == 'Neovim guide', 'custom text_of honored')

-- Default text_of reads the MCP result shape (title/url/content).
local mcp_items = { { title = 't', url = 'u', content = 'neovim server' } }
local mcp_out = two.rank(mcp_items, 'neovim', { fine_fn = overlap_fine })
check(mcp_out ~= nil and #mcp_out == 1 and mcp_out[1].score == 1, 'default text_of reads content')

-- top_k caps the output on a large set.
local many = {}
for i = 1, 50 do
    many[i] = 'item ' .. i
end
local many_out = two.rank(many, 'item', { top_k = 5, fine_fn = overlap_fine })
check(many_out ~= nil and #many_out == 5, 'top_k limits output')

-- Score ties break by original input order.
local ties = { 'b same', 'a same', 'c same' }
local tie_out = two.rank(ties, 'same', {
    block_size = 10,
    pool_size = 10,
    top_k = 3,
    fine_fn = overlap_fine,
})
check(tie_out ~= nil and tie_out[1].item == 'b same' and tie_out[2].item == 'a same', 'ties keep original order')

print(('PASS: %d checks'):format(passed))
