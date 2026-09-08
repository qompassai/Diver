# Diver Agent Guidelines

Read this file before editing and the relevant procedure in `SKILLS.md`.
Preserve the user's configuration and scoped instructions. This policy does not authorize
tool installation, network access or changes outside the requested task.

## Think before coding

- Inspect the relevant code, branch, dirty files and tool versions. State material
  assumptions and tradeoffs. Ask when ambiguity changes behavior; do not choose silently.
- Define observable acceptance criteria and non-goals. Give a brief step-to-check plan
  for multi-step tasks. Reproduce bugs first; verify refactors before and after.
- Suggest simpler solutions when warranted. Keep trivial tasks lightweight.

## Simplicity and surgical changes

- Implement only the requested behavior with minimum code. No speculative features,
  dependencies, single-use abstractions, configurability or impossible-case handling.
- Preserve public APIs, user keymaps, configuration, formatter choices and unrelated work.
  Every changed line must serve the task. Do not reformat adjacent definitions.
- Remove only dead code your patch creates; flag pre-existing debt without deleting it.

## Tiger Style and performance

- Prioritize correctness/safety, performance, then convenience. Prefer native Neovim APIs,
  simple control flow and small scopes. Introduce no recursion.
- Bound work, buffers, input, subprocess output and retries with named limits and units.
  Long-lived services require bounded batches, cancellation and backpressure.
- Assert meaningful internal contracts; validate untrusted input explicitly. Handle real
  unavailable tools, I/O errors and nullable results instead of inventing success.
- Own timers, processes, handles and buffers explicitly. Clean up exactly once and recheck
  validity/freshness after asynchronous callbacks. Do not block editor callbacks on slow I/O.
- Target changed functions at most 70 physical lines, with exceptions explained rather
  than disguised by minification. Preserve `.stylua.toml` and existing file conventions.
- Avoid unnecessary copies, dependencies and scans. Bound managed-runtime growth rather
  than claiming allocation-free Lua. Benchmark before claiming performance gains.
- Use targeted reads/checks and disjoint file ownership. After two failed attempts at one
  hypothesis, investigate or escalate with evidence rather than repeat blindly.

## Strict Lua contract

- Treat `lsp/lua_ls.lua` as the strict diagnostic/type profile and `lsp/stylua_ls.lua`
  as the LuaJIT formatter profile. Read both for Lua work; do not replace them with guesses.
- Preserve `weakNilCheck=false`, `weakUnionCheck=false`, `checkTableShape=true`,
  `castNumberToInteger=false`, `inferParamType=true`, type-check Error and
  `undefined-field` Error. Batch type checks must cover `Any`, not merely `Opened`.
- Narrow nullable `io.open`, `loadfile`, uv allocation/stat results, optional modules and
  configuration before access. Validate decoded external shapes, not just non-nil values.
- No blanket `any`, blind casts, diagnostic suppression or fabricated fallbacks to pass.
  Expected missing dependencies return unavailable/errors; invariant failures stay visible.
- Keep repository formatting. The user chose not to migrate all files to the LSP's
  tabs/single-quote defaults. Do not conflate style defaults with semantic strictness.
- Preserve native linter completion statuses, cancellation, changedtick/freshness and
  `verified` semantics. Empty cached diagnostics do not establish completed verification.

## Verify and hand off

Run focused checks then affected regression/static checks. Record exact commands, versions,
file coverage, failures and skipped/unavailable tools. Distinguish parser/formatter checks
from completed LuaLS diagnostics and runtime tests. Review the final diff and rerun affected
gates after edits. Do not claim the entire configuration is clean from a scoped run.

For substantive work with explicitly selected Astra6/Fable5.1, also provide `HANDOFF.md`
and reusable `AGENTS.md`/`SKILL.md` text: exact files/APIs, contracts, limits, ordered
steps, failure cases, tests and stop rules. Do not infer model identity, promise model parity
or commit extra handoff artifacts unless requested.

This policy adapts the user's
[Karpathy-inspired guidelines](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md)
and [Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md).
