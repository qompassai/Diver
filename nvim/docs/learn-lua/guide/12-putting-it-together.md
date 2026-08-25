# 12 · Putting It Together

You now have every piece. This final chapter does two things: it reads
`diver`'s `init.lua` end-to-end so the whole boot sequence clicks into place,
and then it walks you through making your **first safe edit**.

## Reading `init.lua` top to bottom

Open `init.lua` at the repo root and follow along. With Chapters 01–11 behind
you, every line should now be legible.

**Lines 1–17 — the header.** A `--[[ ... ]]` block comment holding the Apache
license. Block comments use `--[[ ... ]]`; you met long brackets in Chapter 06.

**Lines 19–28 — aliasing (Chapter 02).** A wall of `local x = vim.y`:

```lua
local bo  = vim.bo
local cmd = vim.cmd
local fn  = vim.fn
local g   = vim.g
local o   = vim.o
local opt = vim.opt
```

Some carry inline LuaCATS types: `local o = vim.o ---@type vim.o` (Chapter 10).

**Lines 23, 37–44 — platform detection (Chapters 01 & 05).**

```lua
local is_windows = fn.has('win32') == 1 or fn.has('win64') == 1
```

The `== 1` is mandatory because `0` is truthy. Then an `if is_windows then …
else … end` decides how to find the user id.

**Lines 46–72 — buffer options (Chapter 09).** `bo.shiftwidth = 4`, etc.

**Lines 87–167 — globals and environment (Chapters 06 & 09).** Huge `g.*`
and `env.*` block, full of `..` path concatenation and `or` defaults:

```lua
g.xdg_config_home = env.XDG_CONFIG_HOME
    or (is_windows and fn.expand('~/AppData/Local') or fn.expand('~/.config'))
```

Read that as: use `$XDG_CONFIG_HOME` if set, otherwise the platform default —
the ternary idiom (Chapter 05) nested inside an `or` default.

**Line 183 — `l.enable()`.** Turns on `vim.loader`, the bytecode cache, for
faster startup.

**Lines 184–197 — the require chain (Chapter 07).** The heart of the boot:

```lua
require('config.init').config({
    core = true, cicd = true, cloud = true, debug = false,
    edu = true, lang = true, nav = true, ui = true,
})
require('linters')
require('mappings')
require('plugins')
require('types')
```

A single table (Chapter 03) drives which subsystems load. `config.init`'s
`M.config` then `safe_require`s each one (Chapter 08) so a failure degrades
gracefully.

**Lines 198–309 — global + window options (Chapter 09).** The long `o.*`,
`opt.*`, and `wo.*` tail, including the Neovim 0.13 natives from Chapter 11:

```lua
o.autowriteall = true
wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
o.winborder = 'rounded'
```

That is the entire startup, and you can now explain all of it.

## Your first safe edit

Let us add a tiny, reversible feature: a `:DiverHello` command that greets you.
This exercises modules, functions, the Vim API, and annotations all at once.

1. **Create a new module file** `lua/utils/hello.lua`:

   ```lua
   -- lua/utils/hello.lua
   local M = {}

   --- Greet the current user in the message area.
   ---@param name? string  the name to greet; defaults to $USER
   ---@return string greeting  the text that was shown
   function M.greet(name)
       name = name or vim.env.USER or 'diver'          -- `or` default (Ch. 02/05)
       local msg = ('Hello, %s!'):format(name)          -- :format (Ch. 06)
       vim.notify(msg, vim.log.levels.INFO)             -- Vim API (Ch. 09)
       return msg
   end

   vim.api.nvim_create_user_command('DiverHello', function(opts)
       M.greet(opts.args ~= '' and opts.args or nil)    -- ternary idiom (Ch. 05)
   end, { nargs = '?' })                                -- table attrs (Ch. 03)

   return M                                             -- module return (Ch. 07)
   ```

2. **Load it.** Add one line near the other requires in `init.lua` (or in an
   appropriate aggregator):

   ```lua
   require('utils.hello')
   ```

3. **Try it** after restarting Neovim:

   ```vim
   :DiverHello
   :DiverHello Matt
   :lua print(require('utils.hello').greet('world'))
   ```

4. **Undo it** by deleting the file and the require line. Because the feature is
   isolated in its own module and wrapped in normal APIs, removing it cannot
   break anything else — exactly the property `diver`'s structure is designed
   to give you.

If you did that and understood every line, you have met the goal of this course:
you can read `diver`, and you can change it safely.

## Where to go next

- **Read more leaf modules.** Now tackle `lua/config/core/qf.lua` (quickfix),
  `lua/config/core/tree.lua` (treesitter), and `lua/config/core/lint.lua`. They
  reuse every pattern you have learned.
- **Lean on the annotations.** With `lua-language-server` running, hover and
  go-to-definition turn the whole config into an explorable, typed surface.
- **Regenerate these docs** whenever you add annotated modules — see the
  `README.md` in this folder for the one-line `ldoc` command.

Welcome to writing Lua.
