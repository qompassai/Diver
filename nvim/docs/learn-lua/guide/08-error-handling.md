# 08 · Error Handling

## Concept

Lua's error model has just three verbs. Learn these and you can read every
defensive line in `diver`.

### `error(msg)` — raise an error

```lua
error('schema not found: ' .. name)
```

This stops the current function and propagates an error up the call stack until
something catches it (or it reaches the top and Neovim shows a traceback).

### `assert(value, msg)` — raise *unless* truthy

```lua
assert(ok == 0, 'Write failed: ' .. vim.v.errmsg)
```

`assert(v, msg)` returns `v` unchanged if it is truthy; if `v` is `false`/`nil`
it calls `error(msg)`. It is the compact way to say "this had better be true, or
blow up with this message." `diver`'s `schema.lua` uses `assert` a lot for
internal invariants.

### `pcall(f, ...)` — run `f` in a protected sandbox

This is the catch. `pcall` ("protected call") runs the function and **converts a
thrown error into an ordinary return value** instead of crashing:

```lua
local ok, result = pcall(risky_function, arg1, arg2)
if ok then
    -- result is risky_function's return value
else
    -- result is the ERROR MESSAGE string
end
```

It always returns at least two values: a boolean success flag, then either the
result or the error message. This is the multiple-return contract from
Chapter 04 in action.

> Mental model: `pcall` is `try`/`catch` collapsed into one expression. `ok`
> distinguishes the two branches.

## In Diver

**The foundational pattern — `safe_require`** in `lua/config/init.lua`:

```lua
local function safe_require(name, verbose)
    local ok, mod = pcall(require, name)
    if not ok then
        if verbose then
            notify(fmt('[Diver] Failed to load %s: %s', name, mod), levels.ERROR)
        end
        return nil
    end
    return mod
end
```

When `pcall(require, name)` fails, `mod` holds the **error string** (not a
module), so it can be dropped straight into the notification. The function
returns `nil`, and the caller simply skips that subsystem.

**Guarding a call — `call_if_present`** in the same file:

```lua
local ok, err = pcall(fn, opts)
if not ok and verbose then
    notify(fmt('[Diver] %s.%s failed: %s', label or 'module', method, err), levels.ERROR)
end
```

A plugin's `setup` can throw, and the editor shrugs it off.

**`assert` for an invariant** — `lua/config/core/schema.lua`:

```lua
assert(
    not (has_select and has_ignore),
    'schemastore.json.schemas(): the \'select\' and \'ignore\' settings are mutually exclusive'
)
```

This documents *and* enforces a rule: you may pass `select` or `ignore`, never
both. Notice `\'` — an escaped single quote inside a single-quoted string.

**`error` for a missing entry** — `schema.lua`:

```lua
if orig_schema == nil or index == nil then
    error('schemastore.json.schemas(): replace: schema not found: ' .. name)
end
```

**`pcall` probing a feature** — `lua/utils/docs/docs.lua`, `M.foldexpr`:

```lua
b[buf].ts_folds = pcall(tree.get_parser, buf)
```

Here the *boolean* result of `pcall` is stored directly: "did a tree-sitter
parser exist for this buffer?" If `get_parser` throws, `ts_folds` becomes
`false` and folding falls back gracefully.

## When to use which

| Situation | Use |
|-----------|-----|
| "This must be true or the code is broken." | `assert` |
| "Report a specific problem and stop this function." | `error` |
| "Try this; I want to handle failure myself, not crash." | `pcall` |
| "Try this and I also want a clean traceback on error." | `xpcall` |

## Reference

In the **`learn_lua`** module:

- `safe_require(name)` — the annotated `pcall(require, ...)` helper, returning
  `module, nil` or `nil, errmsg`.
- `call_if_function(maybe_fn, arg)` — checks the value is callable, then wraps
  the call in `pcall` and reports failures via `vim.notify`.

## Try it yourself

```vim
:lua print(pcall(function() error('boom') end))     " --> false  boom
:lua print(pcall(function() return 42 end))          " --> true   42
:lua print(pcall(require, 'does.not.exist'))         " --> false  <error msg>
:lua local ok = pcall(error, 'x'); print(ok)         " --> false
```

You now understand the safety net that lets `diver` survive missing plugins and
half-broken modules. Next we leave pure Lua and meet the editor — **Chapter 09,
The Vim API**.
