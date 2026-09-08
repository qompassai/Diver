-- /qompassai/Diver/docs/learn-lua/modules/learn_tables.lua
-- Qompass AI Diver :: Learn Lua — tables, the one data structure
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------------------------------------------

--- Tables — Lua's only data structure, taught from the Diver config.
--
-- Lua has *one* container type: the table. It plays the role of array, map,
-- struct, namespace, and module all at once. Almost every line of `diver` is
-- building, merging, or iterating tables. Master this module and the config
-- stops looking mysterious.
--
-- @module learn_tables
-- @author Qompass AI
-- @license Apache-2.0

local M = {}

-- ---------------------------------------------------------------------------
-- 1. A table as a list (array part)
-- ---------------------------------------------------------------------------

--- Make a list (1-based array) of plugin names.
--
-- When you write `{ a, b, c }` with no keys, Lua assigns integer keys starting
-- at **1**. This is the "sequence" or "array part" of a table. `diver`'s
-- `lua/utils/docs/init.lua` does exactly this with its `modules` list, then
-- loops it with `ipairs`.
--
-- @usage local list = learn_tables.make_list(); print(list[1]) --> "bounty"
---@return string[]
function M.make_list()
    return { 'bounty', 'clipboard', 'docs', 'mime' }
end

--- Walk a list in order with `ipairs`.
--
-- `ipairs(t)` yields `index, value` pairs from 1 upward and **stops at the
-- first `nil`**. Use it whenever order matters. This mirrors the require-loop
-- in `lua/utils/docs/init.lua` and `lua/types/core/init.lua`.
--
-- @usage learn_tables.each(list, function(i, v) print(i, v) end)
---@param list any[]
---@param fn fun(index: integer, value: any)
function M.each(list, fn)
    for index, value in ipairs(list) do
        fn(index, value)
    end
end

-- ---------------------------------------------------------------------------
-- 2. A table as a map / record (hash part)
-- ---------------------------------------------------------------------------

--- Build the options table you would hand to `vim.keymap.set`.
--
-- When you write keys explicitly (`{ noremap = true }`) the table is acting as
-- a map / record. This is the exact `opts` table built in
-- `lua/mappings/aimap.lua` before each mapping. Note: `desc` powers which-key
-- and `:map` listings.
--
-- @usage local o = learn_tables.keymap_opts(0, "Toggle Explorer")
---@param bufnr integer
---@param desc string
---@return { noremap: boolean, silent: boolean, buffer: integer, desc: string }
function M.keymap_opts(bufnr, desc)
    return {
        noremap = true,
        silent = true,
        buffer = bufnr,
        desc = desc,
    }
end

--- Walk a map with `pairs` (order NOT guaranteed).
--
-- `pairs(t)` iterates *every* key, string or number, in an **unspecified
-- order**. Use it for maps/records where order does not matter. `diver` uses
-- it in `schema.lua` (`for name, schema in pairs(opts.replace)`).
--
---@param map table<any, any>
---@param fn fun(key: any, value: any)
function M.each_pair(map, fn)
    for key, value in pairs(map) do
        fn(key, value)
    end
end

-- ---------------------------------------------------------------------------
-- 3. Nested tables and safe access
-- ---------------------------------------------------------------------------

--- Safely read a deeply-nested field without crashing on a missing parent.
--
-- Indexing `nil` (`a.b.c` when `a.b` is nil) raises an error. `diver` avoids
-- this with `vim.tbl_get` and with `and`-chains. Here we show the hand-rolled
-- version so you understand what those helpers do under the hood.
--
-- @usage
--   local v = learn_tables.dig(client, {"server_capabilities", "hoverProvider"})
---@param root table
---@param path string[]
---@return any
function M.dig(root, path)
    local node = root
    for _, key in ipairs(path) do
        if type(node) ~= 'table' then
            return nil
        end
        node = node[key]
    end
    return node
end

-- ---------------------------------------------------------------------------
-- 4. Merging tables — the `vim.tbl_extend` family
-- ---------------------------------------------------------------------------

--- Merge a base options table with per-call overrides.
--
-- This is THE pattern behind `vim.tbl_extend('force', opts, { desc = ... })`
-- seen all over `lua/mappings/`. Later keys win. `diver` also uses the
-- deep variant `vim.tbl_deep_extend('force', M.config, config)` in
-- `schema.lua`'s `setup`.
--
-- @usage
--   local o = learn_tables.merge({silent=true}, {desc="My map"})
---@param base table
---@param overrides table
---@return table
function M.merge(base, overrides)
    -- `vim.tbl_extend('force', ...)` is Neovim's builtin. We re-implement it so
    -- the mechanics are visible: copy base, then stamp overrides on top.
    local out = {}
    for k, v in pairs(base) do
        out[k] = v
    end
    for k, v in pairs(overrides) do
        out[k] = v
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 5. The `local M = {}` module table
-- ---------------------------------------------------------------------------

--- Explain why almost every diver file starts with `local M = {}`.
--
-- A Lua module is just a table you `return` at the bottom of the file. You
-- attach public functions as `function M.foo() end` and keep helpers as
-- `local function bar() end`. `require('config.core.lsp')` then hands the
-- caller back exactly that `M` table. This function returns a description of
-- the convention so it shows up in the generated docs.
--
---@return string
function M.module_convention()
    return 'A module is a `local M = {}` table, populated with M.fn = ..., then `return M`.'
end

-- ---------------------------------------------------------------------------
-- 6. Tables as configuration (the `opts` idiom)
-- ---------------------------------------------------------------------------

--- Normalise an optional options table, applying defaults.
--
-- Public functions in `diver` accept a single `opts` table and start with
-- `opts = opts or {}` so callers can omit it entirely (see
-- `M.config(opts)` in `lua/config/init.lua` and `simple_colon_parser` in
-- `parser.lua`). This makes APIs forgiving and future-proof.
--
-- @usage
--   learn_tables.with_defaults()                 --> {severity="WARN", source="diver"}
--   learn_tables.with_defaults({source="lint"})  --> {severity="WARN", source="lint"}
---@param opts? { severity?: string, source?: string }
---@return { severity: string, source: string }
function M.with_defaults(opts)
    opts = opts or {}
    return {
        severity = opts.severity or 'WARN',
        source = opts.source or 'diver',
    }
end

return M
