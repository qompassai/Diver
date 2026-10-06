---
name: tiger-style-lua
description: Working rules and validation gates for agents editing Diver's Neovim Lua.
---

# Tiger Style Lua — Diver

Diver is a native-first Neovim Lua config. Prefer native Neovim APIs over plugins.
Authority: the repo's `AGENTS.md` and `SKILLS.md` win over this file. Read them first.

## Style

- 4-space indent, single quotes, 120 columns, `call_parentheses = "Always"`.
  The real config is `.stylua.toml` (the root `stylua.toml` is empty).
  Do not migrate files to the LSP's tabs/double-quote defaults.
- Annotate with `---@type`, `---@param`, `---@return`; mark nullable returns `?`.
- Module-local helpers sit above the returned table (`local M = {}` ... `return M`).
- Explicit contracts in comments: what a function expects, returns, and bounds.
- No hidden behavior: no side effects at require time unless the module's header
  says it self-wires (see `init.lua` comments).
- Bounded work: name limits with units; no recursion; own and clean up timers,
  processes, and buffers exactly once.
- Changed functions stay at or under 70 physical lines.

## Strict nil/type contract

`lsp/lua_ls.lua` is the strict profile: `weakNilCheck=false`, `weakUnionCheck=false`,
`checkTableShape=true`, `castNumberToInteger=false`, type-check at Error.
Narrow `io.open`, `loadfile`, `vim.uv` stat results and optional `pcall(require, ...)`
before use. No blanket `any`, blind casts, or diagnostic suppression to pass.

## Validation gates (every Lua change)

```sh
stylua --check --config-path .stylua.toml --syntax LuaJIT "$FILE"
luacheck "$FILE"                      # zero warnings
luac -p "$FILE"
nvim --headless -c 'lua require("<module>")' -c 'qa!'   # zero errors
git diff --check
```

Plus completed LuaLS diagnostics with zero findings for the file (see `SKILLS.md`,
"Strict LuaLS diagnostics" — promote type-check file status to `Any` for headless runs).
Report each gate's exact command and result. A skipped or unavailable gate is not a pass.

## Workflow

- Live-first: changes land in the live tree (`~/.config/nvim`, backed up first) and are
  mirrored into this repo only after Matt validates them.
- Agents never commit or push. Matt authorizes each push by naming exact files.
- Never reconstruct lost WIP files; leave others' dirty files untouched.
- Durable discoveries go to `.ai/memory/inbox/`, never curated memory.
