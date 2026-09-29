---
name: tiger-style-typescript
description: >
  Write or review TypeScript code in Matt's Tiger Style: safety-first TypeScript standard with explicit contracts, assertions, bounded work, and disciplined ownership. Applies whenever TypeScript is written, regenerated, refactored, reviewed, or debugged under the strict profile (TS 5.9+ and ES2022), for Node services and Deno projects alike. Toolchain pairing: ts_ls (tsgo_ls, deno_ls for Deno) for LSP, prettier and biome for formatting, the Node DAP adapter for debugging. Covers contract-first design, strict null handling, exhaustive switches, bounded async work, and half-adversarial test splits. Catches any-casts, unhandled promises, and non-exhaustive narrowing. See references/TIGER_STYLE_TYPESCRIPT.md for the full guide.
license: Apache-2.0
compatibility: >
  Requires Node.js (or Deno) with typescript-language-server (ts_ls, tsgo_ls, or deno_ls), prettier or biome, and a Node DAP adapter for full LSP, formatting, and debugging. Built for Neovim with Matt's diver config (lsp/ts_ls, formatters/prettier, lua/dap/node); usable by any coding agent that can read the guide and invoke the toolchain.
metadata:
    language: typescript
    lsp: ts_ls
    formatter: prettier
    dap: node
    scip_indexer: not-configured
allowed-tools: Read Edit Bash
---

# Tiger Style TypeScript

## Purpose

Apply Matt's Tiger Style standard to TypeScript code. Priority order, always:
**Safety > Performance > Developer Experience.** The full guide lives in
[references/TIGER_STYLE_TYPESCRIPT.md](references/TIGER_STYLE_TYPESCRIPT.md);
this file is the operational core. When the two disagree, the full guide wins.

## Workflow

1. Pin the toolchain: TypeScript version (5.9+), strict profile
   (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`,
   `noImplicitOverride`, `noFallthroughCasesInSwitch`, `noEmitOnError`),
   module format (ESM vs CommonJS), target, runtime (Node vs browser).
2. Lay the module out top-to-bottom: types/interfaces, constants, runtime
   validators, pure functions, effectful adapters. Never start timers,
   sockets, or downloads on import.
3. Validate external input at the boundary with a discriminated
   `Result<T, E>` (or the subsystem's declared contract); assert internal
   invariants with real runtime guards. Types are erased — no type can
   stand in for validation.
4. Bound everything with named `*_MAX` constants: loops, retries, queues,
   caches, promise admission, output sizes.
5. Review against the checklist below before calling the code done.

## Operating Rules

- **Contracts first.** Every function answers: permitted inputs, rejected
  inputs, max work, what state changes, who owns each resource, failure
  behavior. Public functions carry explicit return types.
- **Static/runtime gap.** `as`, `satisfies`, interfaces, branding, and
  `readonly` guide trusted code only. A branded type needs a validated
  constructor; `satisfies` does not validate JSON. Audit both sides.
- **Assertions test the condition.** User-defined assertion signatures must
  actually narrow `unknown`. Never use `!` or casts to bypass external
  validation; `console.assert` does not terminate execution.
- **Bound everything.** No unbounded `Promise.all`, no unbounded retry,
  no unbounded cache. Retries need idempotency, a shared deadline, bounded
  backoff, and injected jitter.
- **Control flow:** discriminated unions with exhaustive `switch` (a `never`
  check only counts after the runtime boundary validated the
  discriminator). No nested ternaries for effectful logic. No recursion over
  attacker-controlled depth.
- **Absence discipline:** `undefined`, `null`, `false`, `0`, `""` are
  different. Use `??` only when null and undefined both mean missing —
  never `||` for defaults when `false`/`0` is valid.
- **Numbers:** `number` is floating-point. Use `Number.isSafeInteger`,
  reject NaN/infinity and out-of-range values; `bigint` needs explicit
  serialization (JSON can't serialize it).
- **Names are `camelCase` with units in the name:** `timeoutMs`,
  `payloadSizeBytes`, `retryCount`. Types/classes are `PascalCase`.
  No `I` prefixes on interfaces, no single-letter generics with domain roles.
- **Formatting:** 2-space indent, max 100 columns, one statement per line.
  One pinned formatter and lint profile (e.g. prettier + eslint).
- **Functions:** ordinary functions stay near or below 70 lines. Prefer
  discriminated option objects over positional booleans.
- **State and mutation:** compute proposed state, validate, commit at one
  obvious point. `const` prevents rebinding, not object mutation. Async
  callbacks carry a generation/request identity and reject stale results.
- **Resources:** one owner per timer, listener, file handle, socket,
  subprocess, worker. `try/finally` with explicit `dispose`/`close`; clear
  timers, remove listeners, abort owned I/O. `FinalizationRegistry` is not
  cleanup.
- **Async:** pass `AbortSignal` where supported; `Promise.race` with a
  timeout is not cancellation. Keep a bounded task registry, abort owned
  work on teardown, await settlement.
- **Security:** never `eval`/`new Function` on untrusted data; no
  `innerHTML` for text. The type checker is not a sandbox. Never
  interpolate untrusted values into shell strings — use
  `spawn`/`execFile` with argv and `shell: false`.
- **Filesystem:** path normalization is not authorization; `startsWith(root)`
  is not containment. Write temp file in destination dir, check errors,
  then rename; restrictive permissions for sensitive files.
- **Determinism:** explicit serialization order; inject clock/random in
  tests; async completion order never determines persisted results.
- **Comments explain why**, not what. TSDoc on public APIs: limits, units,
  mutation, errors, cancellation. Explain every deliberate `any`, `!`, or
  cast at its narrow boundary.
- **Dependencies:** committed lockfile, frozen/immutable CI installs;
  review install scripts, native addons, and build plugins.

## Output Contract

TypeScript you produce for Matt must: compile under the strict profile with
`tsc --noEmit`, carry explicit types on exported functions, assert its
invariants with real runtime guards, return `Result<T, E>` (or the declared
contract) on expected failures, bound all loops/retries/queues/promise
admission, stay within 100 columns and ~70 lines per function, and pass the
review checklist.

## Review Checklist

- [ ] External input validated before trusted use; internal invariants guarded.
- [ ] No `as`/`!`/branding used to bypass validation; static/runtime gap audited.
- [ ] All loops/retries/caches/queues/promise sets bounded by named constants.
- [ ] `undefined`/`null`/`false`/`0` semantics deliberate; no `||` default clobbers.
- [ ] Numeric domains validated (`isSafeInteger`, NaN/infinity rejected); units in names.
- [ ] Every resource has one owner; teardown exists on all paths incl. cancellation.
- [ ] Async work abortable; stale results rejected; timeouts own cleanup.
- [ ] No shell string interpolation; argv form with `shell: false`.
- [ ] Output deterministic where persisted or tested; no enumeration-order reliance.
- [ ] Functions ≤ ~70 lines, lines ≤ 100 cols, comments explain intent and any `any`.
