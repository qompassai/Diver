# Diver Claude Guidelines

Before editing, read `AGENTS.md` and the relevant `SKILLS.md` section explicitly.
Do not assume another instruction file was auto-loaded. Surface conflicts instead of
silently weakening the user's Lua strictness or changing formatter conventions.

## Working habits

- **Think first:** inspect relevant code, state assumptions and ask about material ambiguity.
  Suggest simpler alternatives where appropriate.
- **Keep it simple:** minimum requested code; no speculative features or frameworks.
- **Edit surgically:** preserve APIs, keymaps, formatting and unrelated work. Remove only
  dead code created by the patch.
- **Verify goals:** map steps to checks, reproduce bugs and review the tested final diff.
  Missing tools, skipped files and empty cached diagnostics are not passes.

For Lua work, read `lsp/lua_ls.lua` and `lsp/stylua_ls.lua`, enforce strict nil/union/shape
checks, and preserve repository formatting. For substantive Astra6/Fable5.1 work, produce
the bounded handoff and reusable instructions required by `AGENTS.md`, without parity claims.
