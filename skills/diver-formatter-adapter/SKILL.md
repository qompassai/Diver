---
name: diver-formatter-adapter
description: "Teach a new external formatter to Matt's diver Neovim config — writing the native adapter in lua/formatters/, verifying its real CLI flags against upstream docs, choosing the stdin-vs-tempfile I/O mode, registering it in the formatter registry and the filetype fallback chain, and running the validation gates. Reach for it whenever a language or tool needs format-on-save support in diver: a brand-new adapter, new flags on an existing tool, or a save-time stage that must go through the centralized pipeline instead of a raw BufWritePre autocmd."
license: Apache-2.0
compatibility: Diver live tree (~/.config/nvim) or repo checkout; the formatter binary installed for smoke testing; luac, luacheck, and stylua available (all on primo).
metadata:
  domain: formatters
  area: lua/formatters
  registry: lua/formatters/init.lua
allowed-tools: Read Edit Bash
---

# Diver Formatter Adapter

## ELI5

Diver doesn't shell out to formatters ad-hoc. Every formatter lives behind a
small **adapter**: a Lua file that says exactly which command to run, which
flags to pass, how to feed it the buffer (stdin or a tempfile), and what a
successful run looks like. A central **registry** (`lua/formatters/init.lua`)
holds all 138 adapters, validates them, and runs them on save through one
pipeline. Adding a formatter means writing one adapter file and registering
it — never a one-off autocmd.

## Procedure

1. Read the repo's `AGENTS.md` and the tiger-style-lua skill first. Keep the
   change surgical: one adapter file plus registration lines.
2. **Verify the tool's CLI flags from upstream docs or `--help`. Never invent
   arguments.** Record the upstream URL — it goes in the file header.
3. Decide the I/O mode:
   - `mode = 'stdin'` (default): buffer text piped to the tool's stdin.
   - `mode = 'tempfile'`: the tool needs a real filename on disk.
   - `output = 'file'` **requires** `mode = 'tempfile'` — `M.register`
     asserts this and rejects the spec otherwise.
4. Write `lua/formatters/<name>.lua` following the `black.lua` pattern:
   - Header block with `---@source <upstream URL>` and an ELI5 docstring
     explaining **each flag** (what it does, why it's set).
   - Module-local `build_args(context)` / `working_directory(context)`
     helpers **above** the returned table.
   - Return `{ ---@type FormatterSpec ... }` with every field explicit:
     `cmd` (string or candidate list), `args` (a function when flags depend
     on the filename), `mode`, `output`, `cwd`, `root_markers`, `env`,
     `exit_codes` (explicit list — there is no `ignore_exitcode`; the legacy
     field is rejected with an error), and `automatic = true` only when the
     tool is safe to run on every save.
5. Register the adapter name → module in `M.module_sources` in
   `lua/formatters/init.lua` (~L76).
6. Add the formatter to the filetype's fallback chain in
   `M.formatters_by_ft` in the same file (~L215).
7. Optionally add a trusted install recipe in `lua/formatters/catalog.lua`.
8. Run the gates (below). Fix until all green.

## Save-time stages (no raw BufWritePre)

If a language needs something to happen at save time (a transform, a
per-language stage, an LSP hook), **never create a direct `BufWritePre`
autocmd** — the ownership guard in `lua/formatters/init.lua` (~L1266–1310)
fails loudly at startup with instructions when it finds one. Instead:

1. Call `formatters.register_stage({ name, priority, filetypes?, patterns?,
   desc, run })` (`register_stage` ~L1319).
2. Pick a priority in the documented bands: 100–199 transforms, 400–499
   per-language stages, 900 LSP format, 1000 native pipeline.
3. `run(bufnr, ctx)` must return `false` for expected failures it already
   reported; raised errors are caught and never break the save.
4. If a non-formatting hook is genuinely legitimate, add it to
   `M.ownership_runtime_allowlist` (~L1196) **with a one-line reason** — the
   hook itself stays out of the formatter file.
5. `vim.b.format_disabled` is the hard kill switch; every stage respects it.

## Gates

- `luac -p` on the new file; luacheck 0/0; stylua clean.
- `:FormatValidate` reports the registry valid (`M.validate` ~L1055 checks
   spec shape, mode/output coupling, and registration).
- Startup smoke: the formatter appears listed/available, and the ownership
   audit passes with no "register via register_stage" violation.

## Stop rules

- Do not reformat neighboring adapters or "clean up" the registry file.
- Do not set `automatic = true` for a tool that rewrites code
  semantically (only whitespace/layout-safe tools).
- Do not invent CLI flags. If upstream docs are ambiguous, flag it and ask.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** not needed. One adapter file plus registration
  lines — single session, surgical.
