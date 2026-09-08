# 05 · Control Flow

## Concept

Control flow is how you make code take decisions and repeat work. Lua keeps this
small — there are only a handful of keywords, and you have seen most of them
already.

### `if` / `elseif` / `else` / `end`

```lua
if cond1 then
    -- ...
elseif cond2 then
    -- ...
else
    -- ...
end
```

Every block ends with `end`. There are no curly braces and no colons. Remember
Chapter 01: the conditions are judged by **truthiness**, so `if x then` means
"if `x` is anything other than `false` or `nil`."

### The numeric `for`

```lua
for i = 1, 10 do        -- i goes 1,2,...,10 (inclusive on both ends)
    print(i)
end

for i = 10, 1, -1 do    -- count DOWN with a step of -1
    print(i)
end
```

Note Lua's `for` is **inclusive** of the final value — `1, 10` runs ten times.

### The generic `for` (with `ipairs` / `pairs`)

```lua
for index, value in ipairs(list) do ... end
for key,   value in pairs(map)   do ... end
```

You met these in Chapter 03. They are the workhorse loops of the config.

### `while` and `repeat`

```lua
while condition do ... end
repeat ... until condition     -- runs the body at least once
```

These are rarer in `diver` but appear in parsing loops.

### There is no ternary `?:` — use `and`/`or`

Lua has no `cond ? a : b`. The idiom is:

```lua
local result = cond and when_true or when_false
```

This works **as long as `when_true` is never `false`/`nil`** — otherwise it
would wrongly fall through to `when_false`. When the true branch might be falsy,
fall back to a full `if`.

### Early `return` and the `not` guard

A clean Lua style returns early to avoid deep nesting:

```lua
local function handle(mod)
    if not mod then return end   -- bail out immediately
    -- ... the happy path, un-indented ...
end
```

## In Diver

**`if`/`elseif`/`else` choosing a comment style** — `lua/utils/docs/docs.lua`,
inside `M.make_header`:

```lua
if comment == '<!--' then
    ...
elseif comment == '/*' then
    ...
else
    ...
end
```

**A guard with early return** — `lua/config/init.lua`, `call_if_present`:

```lua
local function call_if_present(mod, method, opts, verbose, label)
    if not mod then return end
    local fn = mod[method]
    if type(fn) ~= 'function' then return end
    ...
end
```

Two `if ... return end` guards filter out the bad cases first, so the real work
runs at the bottom with no nesting.

**The ternary idiom** — `init.lua`:

```lua
o.shell = fn.executable('pwsh') == 1 and 'pwsh' or 'powershell'
```

If `pwsh` is on the `$PATH`, use it; otherwise fall back to `powershell`. This
is safe because both branches are non-empty strings.

**A `for` loop over a range** — `lua/utils/docs/docs.lua`, the `:Align` command:

```lua
for lnum = start_line, end_line do
    local line = bufgl(0, lnum - 1, lnum, false)[1]
    ...
end
```

A classic numeric `for` walking a line range, with the `- 1` to convert to the
0-based buffer API (Chapter 09).

## Reference

In the **`learn_lua`** module:

- `ternary(cond, a, b)` is the `cond and a or b` idiom, with the caveat
  documented.
- `default_to(value, fallback)` is the pure `or` default — `value or fallback`.

In **`learn_tables`**, `each` and `each_pair` are the two generic-`for` loop
shapes.

## Try it yourself

```vim
:lua for i = 3, 1, -1 do print(i) end
:lua local x = nil; print(x and "set" or "unset")
:lua local function g(v) if not v then return "none" end return v end print(g(), g(5))
```

You can now branch and loop. Next we handle the most-manipulated value type in a
config — **Chapter 06, Strings and Patterns**.
