---
name: diver-linter-adapter
description: "Wire a new native linter into Matt's diver Neovim config — no nvim-lint. Covers picking the tool's machine-parseable output mode from upstream docs, defensive line parsing with explicit bounds, stamping every diagnostic with its source so virtual text can attribute it, the self-contained-config decision (bundled fallback so users never hand-write config), registration with the orphan check, and the LintValidate gates. Reach for it whenever a language or tool needs diagnostics in diver: a new linter adapter, a parser-strategy change, or a bundled default config for a tool that demands one."
license: Apache-2.0
compatibility: Diver live tree (~/.config/nvim) or repo checkout; the linter binary installed, with a machine-parseable output mode (e.g. --format=json, gcc-style); luac, luacheck, stylua available (all on primo).
metadata:
  domain: linters
  area: lua/linters
  registry: lua/linters/init.lua
allowed-tools: Read Edit Bash
---

# Diver Linter Adapter

## ELI5

Diver runs linters natively — no nvim-lint plugin. Each linter gets an
**adapter**: a Lua file that runs the tool, parses its machine-readable
output into diagnostics, and stamps every diagnostic with the tool's name so
the UI can say *which* tool complained. A central registry
(`lua/linters/init.lua`) validates every adapter: unknown fields, orphaned
files, and bad filetype mappings all fail loudly. Adding a linter means
writing one defensive adapter and registering it.

## Convention choice (read this first)

The registry has two generations: the old nvim-lint `vim.lint.Config` shape
(e.g. `shellcheck.lua`) and the modern `Linter` shape (e.g. `cspell.lua`,
278 lines — the exemplar). **New adapters use the `Linter` shape.** Do not
copy the old shape.

## Procedure

1. Read the repo's `AGENTS.md` and the tiger-style-lua skill first. Keep the
   change surgical.
2. **Verify the tool's machine-parseable output mode from upstream docs**
   (`--format=json`, gcc-style, etc.). Prefer it over regex-scraping prose.
   Never invent flags.
3. Write `lua/linters/<name>.lua` following the `cspell.lua` pattern:
   - Header block with `---@source <upstream URL>` and an ELI5 docstring.
   - Module-local constants for bounds: `OUTPUT_BYTES_MAX`,
     `DIAGNOSTICS_MAX`, line-length and message-length caps. Bound all
     subprocess output — unbounded reads are a Tiger Style violation.
   - Per-line parse helpers with `assert`s on the contract you verified in
     step 2. Fail closed on malformed lines: skip the line, never the run.
4. Choose **exactly one** output strategy: `parser` (Lua function) or
   `errorformat` (string). `M.validate` raises a validation error if neither
   is set.
5. Fill the spec: `cmd`, `stdin` / `append_fname`, `args`, `stream`,
   `timeout`, `exit_codes` (explicit — which exit codes mean "ran fine").
6. **Stamp every diagnostic** with `source = '<name>'`, and `code` when the
   tool provides a rule/word identifier. This is what feeds the global
   attribution switch (`source = true` in `vim.diagnostic.config`,
   `lua/config/core/lsp.lua` — set once globally, never per-linter).
7. Self-contained-config decision: if the tool expects a project config file,
   bundle a repo default (precedent: `selene.lua` + `selene-default.toml`)
   with precedence **env override > project config > bundled fallback**.
   The user must never have to create a config file by hand.
8. Register in `M.module_sources` in `lua/linters/init.lua` (~L52). The
   orphan check in `M.validate` (~L1641) fails the run if a file is on disk
   but unregistered — or list it in `M.unregistered_adapters` (~L236) with a
   reason it stays out.
9. Add the filetype mapping in `M.linters_by_ft` (~L284).
10. Add an install/update recipe in `lua/linters/update.lua` when the tool is
    package-manager installable.
11. Run the gates. Fix until all green.

## Gates

- `:LintValidate` clean: no unknown fields (it even suggests "did you mean"
  via Levenshtein on `known_definition_fields` ~L1551), no orphans, every
  by-ft reference resolves.
- `luac -p` on the new file; luacheck 0/0; stylua clean.
- Startup smoke: the linter appears for its filetypes; a known-bad fixture
  produces attributed diagnostics (`source` set).

## Stop rules

- Do not run the LSP variant of a tool alongside the native adapter — every
  diagnostic would double. The native linter *replaces* the LSP one.
- Do not regex-scrape human prose output when a machine mode exists.
- Do not invent exit-code meanings; verify which codes the tool uses.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** optional. Single session suffices for
  straightforward adapters; delegate the parser-iteration loop when the
  tool's output format fights back.
