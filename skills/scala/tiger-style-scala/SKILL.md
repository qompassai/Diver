---
name: tiger-style-scala
description: >
  Write or review Scala code in Matt's Tiger Style: safety-first Scala standard with explicit contracts, assertions, bounded work, and disciplined ownership. Use when writing, regenerating, refactoring, reviewing, or debugging Scala - especially services, data pipelines, and functional-core/imperative-shell designs. Toolchain pairing: Metals for LSP (diagnostics, completions, code actions) and its DAP debug adapter, scalafmt for formatting. Covers contract-first design, effect discipline, total functions, bounded collections and concurrency, and half-adversarial test splits. Trigger keywords: given/using, effect discipline, pattern exhaustivity, Futures, total functions. See references/TIGER_STYLE_SCALA.md for the full guide.
license: Apache-2.0
compatibility: >
  Requires a Scala toolchain (sbt or scala-cli) with Metals for LSP and DAP debugging, plus scalafmt for formatting. Built for Neovim with Matt's diver config (lsp/metals_ls, formatters/scalafmt, lua/dap/scala); usable by any coding agent that can read the guide and invoke the toolchain.
metadata:
    language: scala
    lsp: metals
    formatter: scalafmt
    dap: metals
    scip_indexer: not-configured
allowed-tools: Read Edit Bash
---

# Tiger Style Scala

## Purpose

Apply Matt's Tiger Style standard to Scala 3 code. Priority order, always:
**Safety > Performance > Developer Experience.** The full guide lives in
[references/TIGER_STYLE_SCALA.md](references/TIGER_STYLE_SCALA.md); this file
is the operational core. When the two disagree, the full guide wins.

## Workflow

1. Declare the platform up front (Scala 3.x, JDK, build tool, effect
   library). Keep runtime-specific behavior behind a small explicit
   boundary; never assume one silently. No experimental compiler features
   without an explicit policy and migration tests.
2. Lay the module out top-to-bottom: package, opaque types / enums / ADTs,
   validation, pure operations, wiring. Group a small domain's types,
   validation, and pure operations together.
3. Parse external input into validated domain values with `Either`/`Option`;
   assert internal invariants with `assert`, programmer preconditions with
   `require`. Never put validation or side effects only inside them —
   the compiler can elide them.
4. Bound everything with named constants (`ItemCountMax = 1024`): input
   bytes, collection sizes, nesting depth, queues, executors, retries,
   captured output.
5. Review against the checklist below before calling the code done.

## Operating Rules

- **Contracts first.** Every public operation answers: permitted inputs,
  rejected inputs, max work, what state changes, who owns each resource,
  failure behavior — and whether failure leaves state unchanged, partially
  updated, or requiring recovery.
- **Errors are values.** `Either[DomainError, A]` for expected rejection,
  `Option[A]` for absence, `Try` at boundaries where exception-producing
  code must become a value. Never `.get` as the ordinary path. Model
  errors as enums/ADTs — callers never parse exception text. Catch
  `NonFatal` only when recovery is meaningful; never catch all `Throwable`
  and return a success-shaped default.
- **Bound everything.** No unbounded loops, retries, queues, or growth.
  Retries need an idempotent operation, a shared deadline, bounded
  backoff, and named constants.
- **Control flow:** exhaustive matches on enums and sealed hierarchies — a
  new case is a review event, and a catch-all may conceal it. Prefer
  direct named steps to dense operator chains. `@tailrec` where tail
  recursion is required; still bound total work. Collection pipelines
  must have known input/output budgets.
- **Option/null discipline:** `Option` for optional domain values, never
  sentinel strings or null. Convert nullable Java values at one boundary
  with a deliberate policy (`Some(null)` and `Option(null)` differ).
  Distinguish missing configuration from a present `false` or zero.
- **Names are `lowerCamelCase` values/methods, `UpperCamelCase` types,**
  units last: `timeoutMs`, `payloadSizeBytes`, `retryCount`. Opaque types
  named by meaning (`PayloadBytes`). No `n`, `sz`, `tmp2`, `stuff`, and
  no symbolic operators whose failure behavior isn't obvious.
- **Formatting:** Scalafmt with an exact pinned version and Scala 3
  dialect, 2-space indent, max 100 columns. Never damage formatter output
  to satisfy a metric.
- **Functions:** explicit result types on public methods, named parameters
  for policy, ordinary functions near or below 70 lines. Separate parsing,
  validation, computation, and effects. Keep givens/contextual parameters
  local and unsurprising.
- **State and mutation:** pure transitions separate from effects; immutable
  value plus one controlled commit point, or explicitly synchronized
  mutable state. `val` is a stable binding, not deep immutability. Async
  refreshes carry generation checks and reject stale results.
- **Resources and concurrency:** one clear owner per resource; `Using`
  for synchronous `AutoCloseable` — never leak a lazy value or running
  `Future` past it. `Future` is eager and `Await` timeouts don't cancel;
  executor ownership names who stops admission, cancels work, and awaits
  termination. One coherent effect model per subsystem.
- **Security:** argv form (`ProcessBuilder` with separate args), never
  shell-string interpolation. Reflection, macros, Java serialization, and
  dynamic class loading are privileged. Parameterize SQL; type safety
  doesn't sanitize embedded languages.
- **Determinism:** sort keys where stable order is required; inject clocks,
  random sources, and schedulers at test boundaries; collect parallel
  work by explicit sequence when output is ordered.
- **Comments explain why**, not what. Scaladoc on public types/methods
  documents algebraic error cases, resource scope, execution-context
  ownership, and cancellation semantics.

## Output Contract

Scala you produce for Matt must: compile cleanly, carry Scaladoc on public
API, assert its invariants, return `Either`/`Option` on expected failures,
bound all work with named constants, stay within 100 columns and ~70 lines
per function, and pass the review checklist.

## Review Checklist

- [ ] External input validated before privileged use; internal invariants asserted.
- [ ] All loops/retries/queues/executors bounded by named constants.
- [ ] `Option` vs `null` vs `false` semantics deliberate; Java nulls converted at one boundary.
- [ ] No `.get` on `Option`/`Either`/`Try` as the ordinary path; errors modeled as ADTs.
- [ ] Matches on sealed ADTs exhaustive; no concealing catch-all.
- [ ] Names carry units last; no cryptic temporaries or opaque operators.
- [ ] Every resource has one owner; teardown exists on failure paths; no lazy leak past `Using`.
- [ ] Cancellation stops or joins owned work; `Await` timeout not mistaken for cleanup.
- [ ] Async refreshes reject stale generations; executor shutdown owned.
- [ ] No shell string interpolation of untrusted input; argv form used.
- [ ] Output deterministic where persisted or tested; keys sorted, clocks injected.
- [ ] Functions ≤ ~70 lines, lines ≤ 100 cols, comments explain intent.
