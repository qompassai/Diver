# Learn Lua with Diver

A self-contained, hands-on Lua course generated from the **Diver** Neovim
configuration. It teaches Lua by pointing at the real code in this repository,
and it is built with **LDoc** (LuaDoc) from comments written in **LuaCATS**
annotation style — so the same comments that document the lessons also
type-check inside Neovim via `lua-language-server`.

## What is in here

```
docs/learn-lua/
├── README.md            <- you are here
├── config.ld            <- the LDoc build config (also a readable Lua lesson)
├── Makefile             <- `make` to build, `make serve`, `make clean`
├── guide/               <- the 13 Markdown course chapters (00–12)
│   ├── 00-introduction.md
│   ├── 01-values-and-types.md
│   ├── ...
│   └── 12-putting-it-together.md
├── modules/             <- runnable, dual-annotated reference Lua
│   ├── learn_lua.lua        (core language: types, truthiness, pcall, closures)
│   ├── learn_tables.lua     (tables: list, map, merge, the `opts` idiom)
│   └── learn_vim_api.lua    (vim.o / keymap / autocmd / lsp / vim.pack)
└── build/               <- generated HTML (created by `make`; git-ignorable)
```

The three modules in `modules/` are **real Lua**: you can `require` them inside
Neovim and call every function. They mirror the exact idioms used throughout
`diver`, with each function citing the source file where the pattern appears.

## Building the docs

### Prerequisites (one-time)

This uses **LDoc** and a Markdown renderer. No Neovim plugins are required — the
whole toolchain is plain LuaRocks packages.

```sh
# Lua 5.1 + LuaRocks (Debian/Ubuntu example; use your distro's packages)
sudo apt-get install -y lua5.1 liblua5.1-0-dev luarocks
# Arch:  sudo pacman -S lua51 luarocks

# The doc generator and a Markdown backend
luarocks install ldoc
luarocks install markdown      # or: luarocks install discount  (faster)
```

### Generate the HTML

```sh
cd docs/learn-lua
make            # == ldoc -c config.ld .
```

Output lands in `docs/learn-lua/build/`. Open `build/index.html` in any browser.

### Other targets

```sh
make serve      # build, then serve at http://localhost:8000
make clean      # remove build/
```

If you prefer to call LDoc directly:

```sh
ldoc -c config.ld .
```

## How the "one comment, two tools" trick works

Each reference function is documented once, in LuaCATS style, and LDoc renders
those same annotations:

```lua
--- Pick the first argument that is not nil/false, else a fallback.
--
-- `a or b` evaluates to `a` when `a` is truthy, otherwise to `b`.
--
-- @usage learn_lua.default_to(vim.env.EDITOR, "nvim")
---@generic T
---@param value T?       -- read by lua-language-server AND rendered by LDoc
---@param fallback T
---@return T
function M.default_to(value, fallback)
    return value or fallback
end
```

- **In Neovim**, `lua-language-server` reads the `---@param` / `---@return`
  lines and gives you hovers, completion, and type warnings. This is configured
  by the repo's `.luarc.json`.
- **In these docs**, LDoc reads the prose summary, the `@usage` example, and the
  same LuaCATS type lines to build the Parameters / Returns / Usage sections you
  see in the HTML.

`config.ld` registers the LuaCATS-only tags (`@generic`, `@cast`, `@meta`,
`@version`, `@class`, `@field`, `@alias`) as recognised tags so the build is
warning-free. See the comments in `config.ld` for the details.

## Targeting Neovim 0.13

The course is written for **Neovim 0.13** on **LuaJIT (Lua 5.1)**. It emphasises
the native, plugin-minimal model that `diver` is built around:

- `vim.pack` — the built-in plugin manager (`lua/plugins/`).
- `lsp/<name>.lua` config files + `vim.lsp.enable()` (the repo's `lsp/` folder).
- `vim.lsp.completion.enable` and `vim.lsp.inline_completion.enable` — native
  completion with no `nvim-cmp` required (`lua/config/core/lsp.lua`).
- Native options like `'autocomplete'`, `'autowriteall'`, `'winborder'`, and
  treesitter folding (`init.lua`).

Chapter 11 covers all of these in depth, and Chapter 12 reads `init.lua`
end-to-end before walking you through your first safe edit.

## Keeping the docs in sync

When you add a new annotated module you want included, list its path in the
`file = { ... }` table in `config.ld`, then run `make`. To add a new prose
chapter, drop a Markdown file in `guide/` and add it to the `topics = { ... }`
table.

## License

Apache-2.0, © Qompass AI 
