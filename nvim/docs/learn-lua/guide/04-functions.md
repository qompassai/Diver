# 04 · Functions

## Concept

A function is a value, just like a number or a string. You can store it in a
variable, put it in a table, pass it as an argument, and return it from another
function. This is what people mean when they say Lua has "first-class
functions," and it is why `diver` can hand callbacks to autocommands and
keymaps.

### Three ways to write the same function

```lua
-- 1. Assign an anonymous function to a local
local function add(a, b) return a + b end

-- 2. The same thing, spelled out
local add = function(a, b) return a + b end

-- 3. Attach to a module table (the diver default for public functions)
function M.add(a, b) return a + b end
```

Form 3 is sugar for `M.add = function(a, b) ... end`. You will see it at the top
of every public function in the config.

### Calling with a table — no parentheses needed

When a function takes a single table argument, Lua lets you drop the
parentheses:

```lua
vim.pack.add({ { src = "..." } })   -- explicit
vim.pack.add{ { src = "..." } }     -- same thing, table-call sugar
```

`diver` uses both styles. Do not be thrown by the missing `()` — `f{...}` is
just `f({...})`.

### Multiple return values

A Lua function can return more than one value at once:

```lua
local function minmax(t)
    return math.min(unpack(t)), math.max(unpack(t))
end
local lo, hi = minmax({3, 1, 9})   -- lo = 1, hi = 9
```

Callers take as many as they want; the rest are discarded. The common
`ok, result = pcall(...)` pattern (Chapter 08) relies on this.

### Functions as arguments (callbacks)

This is the pattern that makes the whole config tick. You pass a function *to*
another function so it can be called later, when some event happens:

```lua
vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function(args)        -- this runs every time you save
        print("saved " .. args.file)
    end,
})
```

### Closures: functions that remember

When you define a function *inside* another, the inner one can still see the
outer one's locals — even after the outer function has returned. That captured
state is a **closure**.

## In Diver

**Public functions on `M`** — `lua/config/core/lsp.lua`:

```lua
function M.on_attach(client, bufnr)
    ...
end
```

**A callback passed to an autocommand** — `lua/utils/docs/docs.lua`:

```lua
autocmd('BufWritePost', {
    pattern = { '*.md', '*.markdown' },
    callback = function(args)
        local infile = args.file
        -- ... build a pandoc command, run it asynchronously ...
    end,
})
```

**A closure used as a keymap target** — `lua/mappings/cicdmap.lua`:

```lua
local function toggle_netrw()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        ...
    end
    vim.cmd('Lexplore')
end
map('n', '<leader>e', toggle_netrw, { desc = 'Toggle Explorer' })
```

`toggle_netrw` is defined inside `setup_cicdmap`, closes over the surrounding
scope, and is then handed to `vim.keymap.set` as the action to run on
`<leader>e`.

**Multiple returns** — `lua/config/core/schema.lua`:

```lua
local function get_index(index, tbl, key)
    local i = index[key]
    if not i then return nil end
    return tbl[i], i        -- returns TWO values: the schema and its index
end
```

## Reference

In the **`learn_lua`** module:

- `bounds(list)` returns **three** values (count, first, last) to demonstrate
  multiple returns.
- `make_counter(start)` returns a **closure** — call it repeatedly and watch the
  captured `n` increase.
- `call_if_function(maybe_fn, arg)` shows the "is this actually callable?" guard
  (`type(x) == 'function'`) that `diver`'s `call_if_present` uses before
  invoking a module method.

In the **`learn_vim_api`** module, `map`, `on`, and `command` are thin wrappers
that each accept a **callback function** the way the real APIs do.

## Try it yourself

```vim
:lua local f = function(x) return x*2 end; print(f(21))
:lua local n,a,b = (function() return 3, 'x', 'y' end)(); print(n,a,b)
```

Next: the keywords that decide *which* function runs — **Chapter 05, Control
Flow**.
