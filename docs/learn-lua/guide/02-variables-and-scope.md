# 02 · Variables and Scope

## Concept

You create a variable by assigning to a name:

```lua
x = 10        -- GLOBAL variable (avoid this!)
local y = 10  -- LOCAL variable (always prefer this)
```

The keyword **`local`** is the most important word in day-to-day Lua. Without
it, every variable is **global** — visible to every file in the whole Neovim
session, easy to clobber by accident, and slower to access. With `local`, the
variable is confined to its **block** (the file, function, or `do ... end` it
lives in).

> Rule of thumb: in `diver`, *everything* is `local` unless there is a specific
> reason for it to be global. The only sanctioned globals are `vim`,
> `safe_require`, and `jit` — and you can see that whitelist in `.luarc.json`
> and `.luacheckrc`.

### Scope is lexical (where it is written)

A `local` is visible from the line it is declared to the end of its enclosing
block:

```lua
local function outer()
    local secret = 42      -- visible inside `outer`
    return function()
        return secret      -- the inner function can still see it (a closure!)
    end
end
print(secret)              -- ERROR: `secret` is nil here — out of scope
```

### Aliasing: the top-of-file `local x = vim.y` pattern

Open `init.lua` and look at the first 30 lines:

```lua
local bo  = vim.bo
local cmd = vim.cmd
local env = vim.env
local fn  = vim.fn
local g   = vim.g
local o   = vim.o
local opt = vim.opt
```

This is **aliasing**. Each line copies a reference to a `vim.*` table into a
short `local`. Three reasons `diver` does this everywhere:

1. **Speed** — looking up a `local` is faster than repeatedly indexing the
   global `vim` table.
2. **Brevity** — `o.number = true` reads better than `vim.o.number = true`
   across 300 lines.
3. **Intent** — the block of aliases at the top tells you, at a glance, which
   parts of the API this file touches.

## In Diver

`lua/utils/docs/docs.lua` opens with a long alias block:

```lua
local autocmd = vim.api.nvim_create_autocmd
local bo      = vim.bo
local concat  = table.concat
local decode  = vim.json.decode
local ERROR   = vim.log.levels.ERROR
local notify  = vim.notify
```

Notice it aliases **standard library** functions too (`table.concat`), not just
`vim.*`. The `ERROR`/`INFO` aliases pull constants out of `vim.log.levels` so
later calls read like `notify(msg, ERROR)`.

### The `local M = {}` idiom

Nearly every file begins with:

```lua
local M = {}
-- ... attach functions to M ...
return M
```

`M` is just a local table named "M" by convention (think "Module"). You hang the
file's public functions on it (`function M.on_attach() end`) and `return M` at
the bottom. Anything you keep as `local function helper()` instead stays
**private** to the file. This is how Lua does encapsulation — there is no
`public`/`private` keyword, just whether a name is reachable from the returned
table. Chapter 07 covers how `require` picks this `M` up.

## Reference

- `learn_lua.make_counter(start)` in the **`learn_lua`** module is the clearest
  scope demo: the inner function keeps using the `local n` after the outer
  function has returned. That captured-variable behaviour is a **closure**, and
  it is only possible because of lexical scope.
- `learn_tables.module_convention()` in **`learn_tables`** returns a one-line
  summary of the `local M = {}` pattern.

## Try it yourself

```vim
:lua local a = 5; print(a)     " works: a is local to this one :lua call
:lua print(a)                  " prints nil: the previous `a` is gone
```

You now know how to name values and control who can see them. Next we tackle the
single most important type in Lua — **Chapter 03, Tables**.
