---
name: neovim-config
description: Map of how Diver's Neovim config is organized and loaded, for agents arriving cold.
---

# Diver layout

Depth: `README.md`. Rules: `AGENTS.md`, `SKILLS.md`. Memory: `.ai/memory/INDEX.md`.

## Load order (`init.lua`)

1. `utils.options.setup_early()`, then `vim.loader.enable()`.
2. `config.init.config({...})` → `utils`, `config.keymaps`, `config.lazy`,
   then `config.core`, `config.lang`, `config.nav`, `config.ui` (each skippable via opts).
3. `config.ui.render`, `security`, `dev`, `utils.setup()`, `dap`, `formatters`.
4. `config.mappings`, `plugin` (self-wires), `comms`, `research` (self-wires), `types`.
5. `config.data` — optional, wired only if present.
6. `linters` + `config.core.lint` — deferred to the first `BufReadPre`.
7. `utils.options.setup_late()`, then `ai.setup()` last.

`init.lua` decides order only; each `lua/` subdirectory owns its wiring.

## `lua/config/` layers

- `core/` — lsp, lint, tree-sitter (`tree.lua`), diagnostic output parser (`parser.lua`),
  filetype, quickfix, which-key, schema.
- `lang/` — per-language setup (`lua.lua`, `rust.lua`, ...) plus `TIGER_STYLE_*.md`.
- `nav/` — fzf, ripgrep, native file browser (`nt.lua`), searxng.
- `ui/` — colors, themes, statusline, render, floats, icons.
- `mappings/` — keymap groups (`lspmap`, `langmap`, `aimap`, ...).
- `data/` — database adapters (psql, sqlite, duckdb, redis, ...).

There is no `lua/config/lsp/`; LSP wiring is `lua/config/core/lsp.lua`.

## Elsewhere

- `lsp/*_ls.lua` — one native `vim.lsp.config` file per server.
  `lsp/lua_ls.lua` is the strict LuaLS profile.
- `lua/dap/` — `init.lua`, per-language adapters, `adapters/`, `registry/`, `ui/`.
- `lua/formatters/`, `lua/linters/` — native format/lint adapters
  (`docs/native-lint-api.md`).
- `lua/ai/`, `lua/dev/`, `lua/security/`, `lua/utils/`, `lua/plugin/` — feature stacks.
- `skills/` — repo agent skills (`diver-*` adapters, per-language).

## Tests

- `tests/busted/{unit,integration,helpers}` — busted specs (`*_spec.lua`).
- `tests/lua/` — standalone Lua tests; `tests/startup.lua` — headless startup
  (`nvim --headless -i NONE -u tests/startup.lua`).
- Lint/format config: `.luacheckrc`, `selene.toml` (+ `busted.yml`, `vim.yml`),
  `.stylua.toml`.
