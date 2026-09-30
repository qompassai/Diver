---
name: diver-busted-spec
description: "Write headless busted unit specs for a diver Neovim Lua module with the mandated half-validation / half-adversarial split — spec headers that state coverage and the run command, the shared _G.vim stub helper (never a file-local vim global), the .busted task set including order-dependence shuffling, and clean separation from the prove-based testmore suite. Reach for it when a new lua/ module needs test coverage, when existing specs are missing their adversarial half, or when a spec file's vim stubbing needs fixing to the shared helper."
license: Apache-2.0
compatibility: "Diver live tree (~/.config/nvim) or repo checkout; busted 2.x on Lua 5.4 — locate the binary first (not on PATH everywhere; in this VM: ~/workspace/tools/luarocks-tree/bin/busted)."
metadata:
  domain: testing
  area: tests/busted
  runner: busted
allowed-tools: Read Edit Bash
---

# Diver Busted Spec

## ELI5

Diver tests pure-Lua modules with **busted**, headless — no Neovim needed.
Each spec file covers one module and splits its tests evenly: half
**validation** (the contract holds on good input) and half **adversarial**
(the module survives bad input, hostile state, and nils). Since there's no
real `vim` outside Neovim, specs use a shared stub — and the stub must be
installed one specific way or it's invisible to the module under test.

## Procedure

1. Read the repo's `AGENTS.md`, the relevant `SKILLS.md` section, and the
   tiger-style-lua skill. Keep the change surgical: one spec file.
2. Read `.busted` at the repo root (in full): `ROOT`, `pattern`,
   `helper = 'tests.busted.helpers'`, `lpath` (`./lua/?.lua`), and the task
   set — `unit`, `integration`, `ci`, `tap`, `order_check`.
3. Read `tests/busted/helpers/init.lua` (in full). Vim stubbing comes
   **only** from this shared helper, wired via `.busted`'s `helper` key.
   **Never** write a plain `vim = ...` global in a spec file — it is
   invisible to a module loaded with `dofile` (it runs against the real
   `_G`). The stub must go through `_G.vim`. This gotcha is documented in
   the helper's own header; believe it.
4. Create `tests/busted/unit/<name>_spec.lua` with a header comment stating
   coverage, the validation/adversarial counts, and the run command
   (convention, e.g. "8 validation + 8 adversarial = 16 tests. Run from repo
   root: busted --run=unit tests/busted/unit/<name>_spec.lua").
5. `require` the module through the `.busted` `lpath`. The module must load
   with **only** the `_G.vim` stub — if it needs more of Neovim, it's not a
   unit-testable module; say so instead of growing the stub.
6. Write `describe`/`it` blocks: **exactly 50% validation** (contract holds
   on representative good input) / **50% adversarial** (nil fields, wrong
   types, empty tables, hostile strings, boundary values). No network, no
   wall-clock dependence, no randomness — fully deterministic.
7. Run the gates. Fix until all green.

## Gates

- `busted --run=unit <spec>` exits 0; every test passes.
- The header's validation/adversarial tally matches reality (count them).
- `busted --run=order_check <spec>` (shuffle ×3) passes — hunts order
  dependence.
- No pending/skipped tests left silent; each skip has a reason.
- `git diff --check` clean.

## Boundaries (do not cross)

- `tests/testmore/` runs via `prove` (lua-TestMore) — **never share
  assertion globals** between the busted and testmore suites.
- `tests/lua/` holds non-busted specs (e.g. `tests/lua/mcp_server/*`) —
  a different harness. Don't mix conventions.
- Known repo gap (flag, don't fix unasked): `.busted` comments and the
  CHANGELOG reference `scripts/test-lua` (Busted-then-prove runner), but no
  such file exists under `scripts/` today.

## Stop rules

- Do not grow the shared vim stub to make a module load — shrink the
  module's Neovim surface or test it headless in nvim instead.
- Do not mock what you can feed directly; prefer real inputs at the boundary.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** recommended. One spec file, half validation /
  half adversarial, gates green — a bounded deliverable. Delegate the
  write → run → fix loop; it returns the spec plus the busted output.
