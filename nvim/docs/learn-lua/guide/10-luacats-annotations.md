# 10 · LuaCATS Annotations

## Concept

Lua is dynamically typed — a variable can hold a number now and a string later,
and Lua will not complain. That freedom is also a hazard in a 64,000-line
config. The fix is **annotations**: special comments that *describe* the types
without changing the runtime behaviour. Two tools read them:

- **`lua-language-server`** reads them as **LuaCATS** (Lua Comment And Type
  System) to give you hovers, completion, and red squiggles in Neovim.
- **LDoc** reads the same comments to generate the HTML documentation you are
  reading.

Annotations always start with **three** dashes and an `@tag`:

```lua
---@param name string
```

(Two dashes `--` is a normal comment; three dashes `---` marks an annotation /
doc comment. The extra dash is the whole difference.)

### The annotations you will actually use

| Annotation | Means |
|------------|-------|
| `---@param name type [desc]` | this function parameter has this type |
| `---@return type [name] [desc]` | this function returns this type |
| `---@type type` | this variable/expression has this type |
| `---@class Name` | declare a record type with named fields |
| `---@field name type` | a field of the current `@class` |
| `---@alias Name typeA\|typeB` | a named union of types |
| `---@cast x type` | tell the checker "trust me, `x` is this type now" |
| `---@module 'name'` | this file *is* the named module |
| `---@meta` | this whole file is type-declarations only, never executed |
| `---@generic T` | a type variable, for functions that preserve a type |

### The type vocabulary

- Primitives: `nil`, `boolean`, `number`, `integer`, `string`, `function`,
  `table`, `any`.
- **Optional**: a trailing `?` means "or nil" — `string?` is "string or nil".
- **Unions**: `string|number` is "either".
- **Arrays**: `string[]` is "a list of strings".
- **Typed tables**: `table<string, integer>` is "keys are strings, values are
  integers"; or inline records `{ desc: string, buffer: integer }`.
- **Function types**: `fun(a: integer): boolean`.

### One comment, two jobs

This is the payoff. A function documented like this:

```lua
---@param value any
---@param fallback any
---@return any
function M.default_to(value, fallback)
    return value or fallback
end
```

…gives you autocomplete + a type warning if you misuse it in Neovim, **and**
becomes a formatted entry in these docs. You never write the documentation
twice.

## In Diver

The clearest place to read annotations is `lua/types/`. Those files are pure
declaration files marked with `---@meta` — they teach the language server about
shapes without running any code.

`lua/types/core/autocmds.lua` declares a class:

```lua
---@meta
---@class Autocmds
---@field go_autocmds?  fun()
---@field md_autocmds?  fun()
---@field nix_autocmds? fun(opts?: table)
```

Read it as: "there is a type called `Autocmds`; it may have a `go_autocmds`
field which is a function taking no args, etc." The `?` after each field name
means the field is optional.

`lua/types/core/lsp.lua` shows aliases and richer classes:

```lua
---@alias HlsMode
---| '"always"'
---| '"exported"'
---| '"diagnostics"'

---@class lsp.Position
---@field line      integer
---@field character integer
```

An `@alias` with `---|` lines is an enum: `HlsMode` is one of those three string
literals.

Annotations also appear **inline** in regular code. In `init.lua`:

```lua
local o = vim.o ---@type vim.o
```

and in `lua/plugins/init.lua`:

```lua
vim.pack.add({ ---@type vim.pack.Spec[]
```

The `---@cast` form (used in `lua/plugins/cloud.lua`) narrows a type mid-function:

```lua
---@cast opts vim.pack.Spec
```

This tells the checker "from here on, treat `opts` as a `vim.pack.Spec`," which
silences a false warning without any runtime cost.

### How `diver` is configured to enforce them

- `.luarc.json` sets `runtime.version = "LuaJIT"`, the `runtime.path`, and the
  known globals (`vim`, `safe_require`, `jit`). This is what the language server
  reads.
- `.luacheckrc` configures the separate `luacheck` linter, declaring `vim` as a
  global so it does not flag it as undefined.
- `.stylua.toml` configures the `stylua` formatter (4-space indent, single
  quotes, 120 columns) so the whole config stays consistent.

## How this documentation was built

The comments in the reference modules (`learn_lua`, `learn_tables`,
`learn_vim_api`) deliberately carry **both** styles at once:

```lua
--- Pick the first non-nil argument.
-- @tparam any value the preferred value     <- LDoc reads this
-- @treturn any value or fallback
---@param value any                          <- lua-language-server reads this
---@return any
function M.default_to(value, fallback) ... end
```

LDoc's `@tparam`/`@treturn` and LuaCATS's `@param`/`@return` describe the same
thing. In your own `diver` files you can usually get away with the single
`---@param` / `---@return` form, which both tools understand. The `config.ld`
file in this folder is what tells LDoc how to find and render all of it.

## Reference

Open the **"View source"** link on any function in the three reference modules.
Every one is annotated in this dual style — they are the worked examples for
this entire chapter.

## Try it yourself

In Neovim (with `lua-language-server` running), open any `learn_*.lua` file and:

1. Hover a function name — the annotation renders as a signature tooltip.
2. Call `M.to_zero_based("oops")` and watch the language server flag the string
   where a `number` was annotated.

Next: the changes that make `diver` a *plugin-minimal* config — **Chapter 11,
Neovim 0.13 Native**.
