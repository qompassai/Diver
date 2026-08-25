# 03 · Tables

## Concept

Lua has **one** data structure: the **table**. There is no separate array, list,
dictionary, set, struct, or object type. The table does all of those jobs. Learn
the table and you have learned Lua's entire data model.

A table is a collection of **key → value** pairs:

```lua
local t = {
    [1] = "first",       -- key 1, value "first"
    name = "diver",      -- key "name", value "diver"
    enabled = true,      -- key "enabled", value true
}
```

You read and write entries with either `t[key]` or, for string keys that look
like identifiers, the shorthand `t.key`:

```lua
t[1]        --> "first"
t.name      --> "diver"   (same as t["name"])
t.version = 13            -- add a new entry
```

### The two halves of every table

By convention a table has two parts:

- **The array part** (a "sequence"): integer keys starting at **1**. You write
  it with no keys: `{ "a", "b", "c" }` is `{ [1]="a", [2]="b", [3]="c" }`.
- **The hash part** (a "map" / "record"): string or other keys. You write it
  with named keys: `{ noremap = true, silent = true }`.

A single table can have both at once. The length operator `#t` gives the length
of the **array part** only.

> **1-based, always.** Lua sequences start at index **1**, not 0. `t[1]` is the
> first element. (The `vim.api.*` functions are a separate, 0-based world — see
> Chapter 09. Do not confuse the two.)

### Walking a table: `ipairs` vs `pairs`

```lua
for i, v in ipairs(list) do ... end   -- ordered, array part only, stops at nil
for k, v in pairs(map)  do ... end    -- every key, ANY order
```

Use `ipairs` when **order matters** and the table is a list. Use `pairs` when
you just need every entry of a map and order is irrelevant.

## In Diver

**Table as a list** — `lua/utils/docs/init.lua`:

```lua
local modules = { 'bounty', 'clipboard', 'docs', 'mime' }
for _, module in ipairs(modules) do
    require('utils.docs.' .. module)
end
```

The `_` is a throwaway name for the index we do not use. This loops the list *in
order* and requires each sub-module.

**Table as options/record** — `lua/mappings/aimap.lua`:

```lua
local opts = {
    noremap = true,
    silent  = true,
    buffer  = bufnr,
}
```

This is a record describing how a keymap should behave.

**Table as a nested config** — `init.lua` ends by calling:

```lua
require('config.init').config({
    core = true, cicd = true, cloud = true,
    debug = false, edu = true, lang = true, nav = true, ui = true,
})
```

A single table is passed as the whole configuration. Inside
`lua/config/init.lua`, that table arrives as the `opts` parameter and is read
field by field (`if opts.core ~= false then ...`).

**Table merging** — `lua/mappings/aimap.lua` again:

```lua
vim.tbl_extend('force', opts, { desc = '[r]ose [c]hat' })
```

`vim.tbl_extend('force', a, b)` returns a *new* table that is `a` with `b`'s
keys stamped on top ("force" = later keys win). `diver` also uses the deep
version `vim.tbl_deep_extend('force', M.config, config)` in `schema.lua`.

## Reference

The **`learn_tables`** module mirrors every pattern above with annotated,
runnable functions:

- `make_list()` and `each(list, fn)` — the list / `ipairs` pattern.
- `keymap_opts(bufnr, desc)` and `each_pair(map, fn)` — the record / `pairs`
  pattern.
- `dig(root, path)` — safe nested access without crashing on a missing parent.
- `merge(base, overrides)` — a hand-rolled `vim.tbl_extend` so you can see the
  mechanics.
- `with_defaults(opts)` — the `opts = opts or {}` defaulting idiom.

## Try it yourself

```vim
:lua local t = {10,20,30}; print(#t, t[1], t[3])
:lua for k,v in pairs({a=1,b=2}) do print(k,v) end
:lua print(vim.inspect(vim.tbl_extend('force', {a=1}, {a=2,b=3})))
```

`vim.inspect(t)` pretty-prints any table — it is your best friend for exploring
the config interactively.

Next: the values you store *inside* tables most often — **Chapter 04,
Functions**.
