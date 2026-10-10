# 07 · Modules and `require`

## Concept

A **module** in Lua is nothing fancier than a file that returns a value —
almost always a table. Another file pulls it in with `require`:

```lua
-- file: lua/config/core/lsp.lua
local M = {}
function M.on_attach(client, bufnr) ... end
return M
```

```lua
-- somewhere else
local lsp = require('config.core.lsp')
lsp.on_attach(client, bufnr)
```

Three rules cover 95% of what you need:

1. **Dots are directory separators.** `require('config.core.lsp')` loads
   `lua/config/core/lsp.lua` (relative to a directory on the `runtimepath`).
   `require('utils.docs')` loads `lua/utils/docs/init.lua` — a folder with an
   `init.lua` acts as the module for that folder name.
2. **`require` returns whatever the file returns** — usually the `M` table. So
   `local lsp = require(...)` gives you that exact table.
3. **`require` caches.** The first `require('x')` runs the file; every later
   `require('x')` in the same session returns the *same* cached table without
   re-running it. This is why requiring a module twice is cheap and safe.

### The `init.lua` aggregator pattern

A folder's `init.lua` typically just requires its siblings, acting as a single
entry point — one `require` per file in the folder, and `require('the.folder')`
pulls in the whole directory in the right order. `diver` uses this pattern at
every level.

The core subsystem is the deliberate exception: `lua/config/init.lua` loads
the `config.core.*` leaves directly, in the old aggregator's order, wrapped in
one `pcall` so the first failing leaf stops the rest and is reported instead
of thrown:

```lua
-- lua/config/init.lua
local function load_core()
    require('config.core.async')
    require('config.core.filetype')
    -- Deferred: config.core.lint loads on BufReadPre via init.lua.
    require('config.core.lsp')
    require('config.core.parser')
    require('config.core.qf')
    require('config.core.refactor')
    require('config.core.tree')
    require('config.core.whichkey')
end
```

Same net effect as an aggregator `init.lua`, one less hop — and the leaves
stay ordinary modules you can `require('config.core.lsp')` one by one.

## In Diver

Start at the top and trace the chain — this is the spine of the whole config:

1. **`init.lua`** (the repo root) ends with:

   ```lua
   require('config.init').config({ core = true, cicd = true, ... })
   require('linters')
   require('mappings')
   require('plugins')
   require('types')
   ```

2. **`lua/config/init.lua`** defines `M.config(opts)`, which conditionally
   requires each subsystem based on the `opts` flags:

   ```lua
   if opts.core ~= false then
       local ok, err = pcall(load_core)
       -- ...on failure, notify when verbose; never throw...
   end
   ```

   Note `~= false`: the subsystem loads unless you *explicitly* pass `false`.
   Omitting the flag (so it is `nil`) still loads it, because `nil ~= false` is
   true. That is a deliberate, learner-trap-aware design choice.

3. **`load_core()` in `lua/config/init.lua`** requires the core leaves
   directly: `async`, `filetype`, `lsp`, `parser`, `qf`, `refactor`,
   `tree`, `whichkey`. (`lint` is the exception — it is deferred and
   loads on `BufReadPre` from the root `init.lua`.)

4. Each leaf file (e.g. `lua/config/core/lsp.lua`) is a `local M = {} ...
   return M` module.

The `lua/utils/docs/init.lua` file shows the **loop** variant of the aggregator:

```lua
local modules = { 'bounty', 'clipboard', 'docs', 'mime' }
for _, module in ipairs(modules) do
    require('utils.docs.' .. module)
end
```

Same idea as listing the requires by hand, but data-driven.

## Why `safe_require` exists

`diver` rarely calls bare `require` for optional subsystems. It uses the
`safe_require` helper from `lua/config/init.lua`:

```lua
local function safe_require(name, verbose)
    local ok, mod = pcall(require, name)
    if not ok then
        if verbose then notify(...) end
        return nil
    end
    return mod
end
```

If a module is missing or throws while loading, the editor still starts — you
just lose that one feature. This is the difference between a config that
degrades gracefully and one that drops you at a stack trace on every launch. We
unpack `pcall` fully in the next chapter.

## Reference

`learn_lua.safe_require(name)` in the **`learn_lua`** module is a faithful,
annotated copy of the real helper — it returns `module, nil` on success or
`nil, errmsg` on failure, so you can see the multiple-return contract.

`learn_tables.module_convention()` returns the one-line description of the
`local M = {}` → `return M` shape.

## Try it yourself

```vim
:lua local u = require('config.init'); print(type(u), type(u.config))
:lua print(package.loaded['config.init'] ~= nil)   " true: it is cached
```

`package.loaded` is the cache table `require` consults. Seeing your module in
there proves rule #3.

Next: what happens when loading goes wrong — **Chapter 08, Error Handling**.
