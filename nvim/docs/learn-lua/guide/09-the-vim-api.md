# 09 · The Vim API

## Concept

Everything so far has been the Lua *language*. Now we meet the `vim` global —
the table Neovim injects into every Lua chunk, giving you the whole editor as a
programmable object. You do not `require('vim')`; it is simply always there.
(That is why `.luarc.json` lists `vim` as a known global.)

Here are the corners of `vim` that `diver` actually uses, grouped so you can
navigate them.

### Options — `vim.o`, `vim.bo`, `vim.wo`, `vim.opt`

| Accessor | Scope | Example |
|----------|-------|---------|
| `vim.o`  | global scalar | `vim.o.termguicolors = true` |
| `vim.bo` | buffer-local | `vim.bo.shiftwidth = 4` |
| `vim.wo` | window-local | `vim.wo.number = true` |
| `vim.opt`| list/flag-aware | `vim.opt.runtimepath:prepend(p)` |

Use `vim.opt` when an option is a comma-list or flag-set and you want to
`:append`, `:remove`, or `:prepend` rather than overwrite the whole thing.

### Variables and environment — `vim.g`, `vim.env`, `vim.fn`

- `vim.g.mapleader = ' '` — global Vim variables (`g:` in Vimscript).
- `vim.env.HOME` — environment variables.
- `vim.fn.expand('~/.config')` — call **any** classic Vimscript function from
  Lua. `vim.fn.has`, `vim.fn.stdpath`, `vim.fn.system` are all here.

### Commands — `vim.cmd`

`vim.cmd('filetype plugin on')` runs an Ex command as if typed at `:`.

### The structured API — `vim.api.*`

These are the fast, modern, **0-based** functions (note: 0-based, unlike Lua
tables which are 1-based — this is the #1 source of off-by-one bugs):

- `vim.api.nvim_buf_get_lines(buf, start, end_, strict)` — read lines.
- `vim.api.nvim_buf_set_lines(...)` — write lines.
- `vim.api.nvim_create_autocmd(event, spec)` — react to events.
- `vim.api.nvim_create_user_command(name, fn, attrs)` — define `:Commands`.

### Keymaps — `vim.keymap.set`

`vim.keymap.set(mode, lhs, rhs, opts)` — `rhs` can be a string command or a Lua
function. The one keymap call you will ever need.

### Utilities — `vim.tbl_extend`, `vim.inspect`, `vim.notify`, `vim.split`

- `vim.tbl_extend('force', a, b)` / `vim.tbl_deep_extend` — merge tables.
- `vim.inspect(t)` — pretty-print a table (your debugging best friend).
- `vim.notify(msg, level)` — show a message; `level` from `vim.log.levels`.
- `vim.split(s, sep, opts)` / `vim.gsplit(...)` — split strings.

## In Diver

`init.lua` is a 300-line tour of the options API. Sample:

```lua
bo.shiftwidth = 4              -- buffer option
g.mapleader = ' '              -- global variable
o.termguicolors = true         -- global option
opt.runtimepath:prepend(env.VIMRUNTIME)   -- list option, prepend
wo.number = true               -- window option
wo.relativenumber = true
```

The **0-based gotcha**, live, in `lua/config/core/parser.lua`:

```lua
lnum = tonumber(lnum) - 1                 -- compiler said line N (1-based) ...
col  = tonumber(col or 1) - 1             -- ... API wants N-1 (0-based)
table.insert(diagnostics, { lnum = lnum, col = col, ... })
```

And in `lua/utils/docs/docs.lua`'s `M.foldtext`:

```lua
return bufgl(0, v.lnum - 1, v.lnum, false)[1]
```

`v.lnum` is the 1-based current line; `v.lnum - 1, v.lnum` reads exactly that
one line through the 0-based, end-exclusive API. The trailing `[1]` grabs the
first (only) element of the returned list.

**`vim.fn` + truthiness** — `init.lua`:

```lua
local is_windows = fn.has('win32') == 1 or fn.has('win64') == 1
```

**Defining a command with a range** — `lua/utils/docs/docs.lua`:

```lua
usercmd('Align', function(opts)
    for lnum = opts.line1, opts.line2 do ... end
end, { range = true })
```

## Reference

The **`learn_vim_api`** module is your clickable cheat-sheet, with one annotated
wrapper per API area:

- `options_cheatsheet()` — when to use `o` / `bo` / `wo` / `opt`.
- `map(mode, lhs, rhs, opts)` — `vim.keymap.set`.
- `on(event, callback, extra)` — `nvim_create_autocmd`.
- `get_lines(buf, first, last)` — the 0-based, end-exclusive read.
- `command(name, callback, attrs)` — `nvim_create_user_command`.
- `enable_completion` / `pack_specs` — the Neovim 0.13 native bits (Chapter 11).

## Try it yourself

```vim
:lua print(vim.inspect(vim.api.nvim_buf_get_lines(0, 0, 3, false)))
:lua print(vim.fn.stdpath('config'))
:lua vim.notify('hello from lua', vim.log.levels.INFO)
:lua print(vim.o.shiftwidth, vim.bo.shiftwidth)
```

Next we make these comments do double duty as a type-checker — **Chapter 10,
LuaCATS Annotations**.
