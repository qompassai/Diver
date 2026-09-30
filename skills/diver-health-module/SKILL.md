---
name: diver-health-module
description: "Author a :checkhealth health module for a diver Neovim config subsystem — probing its external executables, introspecting its registry nil-safely, and reporting ok/warn/error through vim.health with the concrete consequence on every warning. Reach for it when a new or changed lua/ subsystem needs runtime dependency reporting, when :checkhealth output for a domain is missing or misleading, or when a subsystem gains externals that can silently break it."
license: Apache-2.0
compatibility: Diver live tree (~/.config/nvim) or repo checkout; headless nvim to run :checkhealth; luac, luacheck, stylua (all on primo).
metadata:
  domain: diagnostics
  area: lua/<domain>/health.lua
  interface: vim.health
allowed-tools: Read Edit Bash
---

# Diver Health Module

## ELI5

Every major diver subsystem ships a tiny `health.lua` that answers one
question: *"is everything this subsystem needs actually here?"* Neovim's
`:checkhealth <domain>` finds `lua/<domain>/health.lua` automatically and
renders its report. A good module probes each external binary, peeks at the
subsystem's own registry without crashing on missing pieces, and says not
just "X is missing" but "X is missing, so `:SomeCommand` will fail."

## Which flavor

Two flavors exist in the repo. **Default to the display flavor** below. The
report-table flavor (`lua/ai/harness/health.lua`: `M.check(ctx)` returns a
data table for programmatic use, with busted specs in
`tests/busted/unit/health_spec.lua`) is for subsystems consumed by other
code — note it, don't mix it into a display module.

## Procedure

1. Read the repo's `AGENTS.md` and the tiger-style-lua skill first. Study the
   exemplar `lua/ai/acp/health.lua` (read in full) — 8 siblings follow it:
   `lua/ai/agx/health.lua`, `lua/ai/harness/health.lua`,
   `lua/dev/scip/health.lua`, `lua/dev/bootdev/health.lua`,
   `lua/games/health.lua`, `lua/games/blender/health.lua`,
   `lua/games/love2d/health.lua`, `lua/games/robocode/health.lua`.
2. Create `lua/<domain>/health.lua` with the standard header block (path
   comment, license, copyright) and a `-- Run with :checkhealth <domain>`
   comment at the top.
3. `local M = {}` and exactly `function M.check()`. Inside:
   - One `vim.health.start('<section>')` per section; report with
     `vim.health.ok` / `warn` / `error`. Never `print`.
   - Probe each external with `vim.fn.executable('<bin>') == 1`.
   - Every `warn`/`error` states the **concrete consequence**: which command
     or feature breaks, not just "not found".
4. Introspect the domain's own registry/store **nil-safely**: empty registry,
   nil spec, missing executable, and unverified invocation are separate warn
   classes — a missing registry must not crash the check.
5. Debugging trick: `:checkhealth` swallows Lua tracebacks. When iterating,
   run the real `check()` under `xpcall` with `debug.traceback` in a
   headless nvim to see the actual error.
6. Run the gates. Fix until all green.

## Gates

- `luac -p`, luacheck 0/0, stylua clean on the new file.
- Headless `:checkhealth <domain>` renders every section with no Lua errors.
- Each warn/error line names what breaks if ignored.
- Optional but encouraged: a busted spec asserting `M.check` exists and is
  callable (see the diver-busted-spec skill).

## Stop rules

- Do not probe the network. Health checks must be fast, local, and
  deterministic.
- Do not duplicate another domain's module — one health module per domain.
- Do not report a warning without saying what the user loses.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** not needed. One small module against an
  exemplar — single session.
