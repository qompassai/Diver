---
name: diver-dap-adapter
description: "Wire a new native DAP debug adapter into Matt's diver Neovim config — vetting the candidate package against its own upstream source under the adapter-verdicts protocol, implementing the DebugModule contract in lua/dap/, registering it in the MODULES catalog, documenting the install, and promoting it through the readiness registry from discovered to validated. Reach for it when a language or runtime needs debug support in diver, when the dap TODO backlog gains a new entry, or when an existing adapter's verdict needs re-checking against upstream."
license: Apache-2.0
compatibility: Diver live tree (~/.config/nvim) or repo checkout; the DAP adapter's upstream install verified; luac, luacheck, stylua, LuaLS, busted (all on primo).
metadata:
  domain: debugging
  area: lua/dap
  registry: lua/dap/init.lua
allowed-tools: Read Edit Bash
---

# Diver DAP Adapter

## ELI5

Diver debugs natively through the Debug Adapter Protocol. Each language or
runtime gets a **module** in `lua/dap/` that knows how to start its debug
adapter, which filetypes it serves, and which commands and keymaps it owns.
A central `MODULES` catalog registers every module, and a readiness
registry probes each adapter from `known` up to `validated`. Wiring a new
adapter means proving the tool really speaks DAP, writing one module,
registering it, and watching the registry promote it.

## Vetting protocol (do this first)

Read `lua/dap/ADAPTER_VERDICTS.md`. The rule: fetch whatever listing you
like (e.g. the Arch Wiki DAP table) but verify the package against **its own
upstream source** — it must really speak DAP. Record a verdict:

- **CONFIRM** with rationale, or
- **DENY** with rationale and route to an existing module instead
  (LSP-only servers, native debuggers with no DAP mode, and miscategorised
  tooling get DENY — a gdb/lldb module usually already covers them).

Diver's preference order (from `lua/dap/TODO.md`, which also holds the live
backlog of ~15 queued modules): standalone DAP server first, then native
debugger DAP mode, then runtime-provided adapter, then LSP-brokered, with
editor-extension assets last. **No generic source-level DAP is invented.**

## Procedure

1. Read the repo's `AGENTS.md`, the relevant `SKILLS.md` section, and the
   tiger-style-lua skill. Study 1–2 of the 28 live modules
   (`lua/dap/node.lua`, `bash.lua`, `mojo.lua` show the range).
2. Write `lua/dap/<name>.lua` implementing the `DebugModule` contract from
   `lua/dap/init.lua`: `adapter`/`adapters`, `configurations`, `commands`,
   `filetypes`, `mappings`, `setup`/`teardown`. Tiger-style Lua, 80 columns,
   LuaCATS annotations, an ELI5 docstring, bounded subprocess probes and
   timeouts.
3. Register a `DebugModuleSpec` in `MODULES` in `lua/dap/init.lua`:
   filetypes plus optional `condition`/`root` project gating (see the
   android/sqlite/unreal entries for the pattern).
4. Document the install in `lua/dap/README.md`'s per-adapter section with
   `---@source` upstream links; update the `lua/dap/TODO.md` status matrix.
5. Optionally add a declarative descriptor (`lua/dap/adapters/moonwalk.lua`
   is the exemplar: executable, filetypes, version probe, env allowlist,
   secrets-scrubbed logging) so the readiness registry
   (`dap.registry`: known → discovered → compatible → negotiated →
   validated; bounded probes in `dap/registry/discovery.lua`, 3 s timeout,
   ≤8 candidates) can track it.
6. Run the gates. Fix until all green.

## Importing .vscode/launch.json

When a project ships `.vscode/launch.json`, don't rewrite its configs by
hand — import them via `lua/dap/ext/vscode.lua`: `M.getconfigs(path)`
parses, `M.load_launchjs(path, type_to_filetypes)` loads;
`promptString`/`pickString` inputs resolve via coroutine + `vim.ui.input`.
Verify every produced config's adapter is discoverable by the registry.

## Gates

- `luac -p`, luacheck 0/0, stylua clean, LuaLS clean on new files.
- Busted DAP suites pass.
- Registry discovery promotes the adapter to `discovered`; a headless DAP
  session actually debugs a fixture → `validated`.

## Stop rules

- Do not wire an adapter you haven't verdict-vetted. DENY means DENY.
- Do not invent DAP where the tool only speaks LSP — say so and stop.
- Non-overlap: `moonwalk-debug` covers *debugging with* Moonwalk;
  `diver-lsp-config` covers LSP server configs. This skill is *wiring
  adapters into diver's DAP layer* only.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** recommended. Vetting → module → registration →
  registry promotion spans docs, code, and gates. Delegate the whole pass;
  it returns the verdict record plus the gate results.
