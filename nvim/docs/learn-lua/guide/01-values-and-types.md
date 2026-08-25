# 01 · Values and Types

## Concept

Lua has exactly **eight types**. That is the whole list, and you already half-know it:

| Type | Example | Notes |
|------|---------|-------|
| `nil` | `nil` | "nothing here." The default value of any unset variable. |
| `boolean` | `true`, `false` | Only two values. |
| `number` | `42`, `3.14`, `-1` | **One** numeric type. On LuaJIT it is a 64-bit float. There is no separate int type. |
| `string` | `'hi'`, `"hi"` | Immutable text. Single or double quotes are identical. |
| `function` | `function() end` | Functions are values you can pass around. |
| `table` | `{ 1, 2, x = 3 }` | The only container. Chapter 03 is entirely about these. |
| `userdata` | (from C) | Raw C data. You will rarely create these directly. |
| `thread` | (coroutines) | For cooperative multitasking. Advanced; skip for now. |

You ask Lua which type you are holding with the built-in `type(v)`, which
returns one of those names as a **string**.

```lua
type(true)   --> "boolean"
type(3.14)   --> "number"
type("hi")   --> "string"
type(nil)    --> "nil"
type({})     --> "table"
type(print)  --> "function"
```

### The one rule that unlocks the config: truthiness

When Lua evaluates a condition (`if`, `and`, `or`, `while`), it asks only one
question: *is this value falsy?* And the answer is falsy for **exactly two
values**:

- `false`
- `nil`

**Everything else is truthy.** This trips up newcomers from other languages:

```lua
if 0 then print("yes") end    -- prints "yes" — 0 is TRUE in Lua
if "" then print("yes") end   -- prints "yes" — empty string is TRUE
if {} then print("yes") end   -- prints "yes" — empty table is TRUE
```

Only `if false` and `if nil` (and therefore any *missing* table field) are
false.

## In Diver

Open `lua/config/core/lsp.lua`. The very first thing `M.on_attach` does is:

```lua
if client.server_capabilities.completionProvider then
```

`completionProvider` is either a truthy **table** (the server supports
completion) or **`nil`** (it does not). There is no explicit `== true` — the
truthiness rule does the work. You will see this hundreds of times across the
config, e.g. `if env.SSH_TTY then` in `init.lua`.

Now look at `init.lua` line ~23:

```lua
local is_windows = fn.has('win32') == 1 or fn.has('win64') == 1
```

`fn.has(...)` returns the **number** `1` or `0` (Vimscript convention). Because
`0` is *truthy* in Lua, you cannot write `if fn.has('win32') then` — it would be
true on every platform. That is why the config carefully compares `== 1`. This
is a real bug-magnet, and now you can spot it.

## Reference

See the runnable, annotated examples in the **`learn_lua`** module:

- `learn_lua.kind_of(value)` — wraps `type()`.
- `learn_lua.is_truthy(value)` — shows the `not not value` idiom for collapsing
  any value to a real boolean.
- `learn_lua.to_zero_based(n)` — the number lesson that explains the 1-based vs
  0-based gotcha you will meet in Chapter 09.

## Try it yourself

Inside Neovim, open the command line and run:

```vim
:lua print(type(vim.g.mapleader))
:lua print(type(vim.o.number))
:lua if 0 then print("0 is truthy") end
```

You have now met every Lua type and the single most important evaluation rule
in the language. Next: how to *name* these values — **Chapter 02, Variables and
Scope**.
