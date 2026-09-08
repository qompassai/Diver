# 06 · Strings and Patterns

## Concept

Strings are immutable text. You can quote them three ways:

```lua
local a = 'single quotes'
local b = "double quotes"          -- identical to single
local c = [[ long string
that spans multiple lines ]]       -- "long bracket" form, no escaping needed
```

`diver`'s `.stylua.toml` sets `quote_style = "AutoPreferSingle"`, which is why
the config overwhelmingly uses `'single'` quotes. The `[[ ... ]]` form is used
for license headers and multi-line templates (see `schema.lua`'s
`copyright_notice`).

### Joining strings: `..`

The concatenation operator is two dots:

```lua
local path = fn.stdpath('config') .. '/spell/en.utf-8.add'
```

`..` glues strings (and numbers, which auto-convert) together. You see this
constantly in path building throughout `init.lua`.

### Formatting: `string.format` and the `:format` method

```lua
string.format('[Diver] Loaded %s', name)   -- function call form
('[Diver] Loaded %s'):format(name)          -- method call form — same result
```

The `%s` is a placeholder ("put a string here"); `%d` is for integers. Both
forms appear in `diver`. The `('...'):format(...)` shape works because in Lua
you can call a string-library method directly *on* a string literal.

### Length and the `#` operator

`#s` gives the byte length of a string (and, separately, the array length of a
table — Chapter 03).

### Lua patterns — NOT regular expressions

This is a crucial gotcha. Lua has its own lightweight pattern language for
matching text. **It is not PCRE / regex.** The differences that bite people:

| You want | Regex | Lua pattern |
|----------|-------|-------------|
| "any character" | `.` | `.` (same) |
| "a digit" | `\d` | `%d` |
| "a space" | `\s` | `%s` |
| "a word char" | `\w` | `%w` |
| "zero or more" | `*` | `*` (same) |
| "the literal `%`" | `%` or `\%` | `%%` |
| "escape a magic char" | `\` | `%` |

The magic characters you must escape with `%` are: `( ) . % + - * ? [ ] ^ $`.

The two pattern functions you will meet most:

- `s:match(pattern)` — return the first match (and any captures in `()`), or
  `nil`.
- `s:gsub(pattern, replacement)` — return a copy with all matches replaced, plus
  the count.

```lua
local path, line = ("init.lua:42"):match("^(.-):(%d+)")
-- path = "init.lua", line = "42"   (still a string — convert with tonumber)
```

## In Diver

**Path concatenation** — `init.lua`:

```lua
g.python3_host_prog = '/usr/bin/python3'
o.undodir = fn.stdpath('data') .. '/undo'
```

**`:format` for messages** — `lua/config/init.lua`:

```lua
notify(fmt('[Diver] Failed to load %s: %s', name, mod), levels.ERROR)
```

(where `local fmt = string.format` at the top — Chapter 02 aliasing.)

**A Lua pattern parsing compiler output** — `lua/config/core/parser.lua`:

```lua
local pattern = opts.pattern or '^(.-):(%d+):(%d+):%s*(.+)$'
local path, lnum, col, msg = line:match(pattern)
```

Read that pattern with your new knowledge:
`^(.-)` capture everything up to the first colon (the file),
`:(%d+)` a colon then digits (the line number),
`:(%d+)` another colon and digits (the column),
`:%s*(.+)$` a colon, optional spaces, then the rest (the message) to end of
line. Four captures, four variables — multiple returns from `match`.

**`gsub` cleaning JSON-with-comments into real JSON** —
`lua/utils/docs/docs.lua`, the `:Json2Lua` command:

```lua
json_str = json_str:gsub('//[^\n]*', '')      -- strip // line comments
json_str = json_str:gsub('/%*.-%*/', '')       -- strip /* block comments */
json_str = json_str:gsub(',(%s*[}%]])', '%1')  -- drop trailing commas
```

Notice `/%*` and `%*/` — the `*` is escaped with `%` because `*` is magic. And
`%1` in the replacement means "whatever capture #1 matched."

## Reference

The string idioms are demonstrated throughout the reference modules — e.g.
`learn_lua.safe_require` and `learn_lua.call_if_function` both build messages
with `:format`, and `learn_vim_api.pack_specs` concatenates the GitHub URL with
`..`.

## Try it yourself

```vim
:lua print(('a' .. 'b' .. 'c'))
:lua print(('user=%s id=%d'):format('matt', 42))
:lua print(('init.lua:42:7'):match('^(.-):(%d+):(%d+)'))
:lua print(("x.y.z"):gsub("%.", "/"))
```

Next: how files find and load each other — **Chapter 07, Modules and
`require`**.
