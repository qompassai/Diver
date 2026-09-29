---
name: tiger-style-go
description: >
  Write or review Go code in Matt's Tiger Style: safety-first Go standard with explicit contracts, assertions, bounded work, and disciplined ownership. Use when writing, regenerating, refactoring, reviewing, or debugging Go - especially CLIs, services, and tooling. Toolchain pairing: gopls for LSP (diagnostics, completions, code actions), gofmt and goimports for formatting, delve (dlv) for DAP debugging. Covers contract-first design, errors-as-values with %w wrapping, bounded goroutines and retries, and half-adversarial test splits. Trigger keywords: goroutine leak, data race, error wrapping, nil map, context cancellation, cgo. See references/TIGER_STYLE_GO.md for the full guide.
license: Apache-2.0
compatibility: >
  Requires the Go toolchain with gopls, gofmt/goimports, and delve (dlv) for full LSP, formatting, and DAP support. Built for Neovim with Matt's diver config (lsp/gop_ls, formatters/gofmt, lua/dap/go); usable by any coding agent that can read the guide and invoke the toolchain.
metadata:
    language: go
    lsp: gopls
    formatter: gofmt
    dap: delve
    scip_indexer: not-configured
allowed-tools: Read Edit Bash
---

# Tiger Style Go

## Purpose

Apply Matt's Tiger Style standard to Go code. Priority order, always:
**Safety > Performance > Developer Experience.** The full guide lives in
[references/TIGER_STYLE_GO.md](references/TIGER_STYLE_GO.md); this file is
the operational core. When the two disagree, the full guide wins.

## Workflow

1. Record the module's Go/toolchain version, GOOS/GOARCH, and cgo policy;
   never assume 64-bit `int`, scheduling order, or tested cross-compiles.
2. Lay the package out top-to-bottom: header/purpose, constants, types,
   constructors/validators, operations, tests. Use `cmd/<program>` for
   executables, `internal/` for implementation boundaries; avoid `init()`
   side effects.
3. Validate external input with explicit error returns; reserve `panic`
   for broken programmer contracts and irrecoverable internal state.
4. Bound everything with named `Max` constants: input bytes, items, nesting
   depth, workers, queue entries, retries, output capture.
5. Review against the checklist below before calling the code done.

## Operating Rules

- **Contracts first.** Every function answers: permitted inputs, rejected
  inputs, max work, what state changes, who owns each resource, failure
  behavior. Public operations follow input → validation → bounded
  computation → validated change → commit → cleanup.
- **Errors are values.** Return `(value, error)` consistently; wrap with
  `%w` for `errors.Is`/`errors.As`; never compare message strings. Handle
  `Close` errors where writes can fail. A typed nil in an `error`
  interface is not nil. Never `panic` on malformed external data.
- **Bound everything.** No goroutine per unbounded input item — use bounded
  workers with admission. No unbounded retry; retries need idempotence, a
  shared deadline, bounded backoff. No unbounded `io.ReadAll`.
- **Concurrency:** contexts signal cancellation, they don't kill goroutines
  — every worker needs a shutdown path and an owner that waits. Sender
  closes owned channels exactly once. One goroutine owns shared state, or
  guard it with a mutex/atomic protocol. Define who may mutate a pointer
  after it crosses a channel.
- **Resources:** `defer` cleanup after checking acquisition succeeded;
  never `defer` in a large loop (per-item function instead). `os.Exit`
  skips deferred cleanup — return to the entry point. Never copy a used
  mutex.
- **Zero values and absence:** document zero-value behavior. Nil slice,
  empty slice, nil map, missing key are distinct; use comma-ok lookups.
  Use `*bool` when omitted vs `false` differ.
- **Names are `MixedCaps`, units last:** `requestCount`,
  `payloadSizeBytes`; durations as `time.Duration` internally. No
  underscores in ordinary identifiers; exported names start uppercase;
  standard initialisms (`HTTPClient`, `userID`); short receiver names.
- **Formatting:** `gofmt` is authoritative, including its tabs. Never force
  spaces or a hard 100-column wrap onto gofmt output; keep lines readable
  through function design.
- **Functions:** ordinary functions stay near or below 70 lines. Pass
  `context.Context` first for cancellable operations; never store request
  contexts in long-lived structs. Narrowest useful interface at the
  consumer boundary; options struct for complex construction.
- **State and mutation:** validate, do bounded leaf work, commit at one
  obvious point; stale async results must not mutate a newer generation.
  Slices alias their backing arrays — document ownership on send/return.
  Config is immutable after construction.
- **Determinism:** sort map keys before canonical output; never rely on
  goroutine completion order or `int` width.
- **Security:** treat `unsafe`, cgo, reflection, plugins, and build
  directives as trust boundaries. Bound HTTP headers/bodies, set timeouts,
  verify TLS. The race detector is not proof of race-freedom.
- **Comments explain why**, not what. Doc comments on exported symbols
  stating cancellation, concurrency, ownership, zero-value guarantees.

## Output Contract

Go you produce for Matt must: build under the recorded toolchain, return
`(zero, err)` on expected failures with wrapped sentinel errors, verify
internal invariants with explicit checks, bound all input/workers/queues/
retries, pass `go vet` and `go test -race`, stay gofmt-clean with
functions near ~70 lines, and pass the review checklist.

## Review Checklist

- [ ] External input validated before use; invariants checked, `panic`
      only for programmer-contract violations.
- [ ] All bytes/items/workers/queues/retries bounded by named constants.
- [ ] Errors wrapped with `%w`; no message-string comparison; `Close`
      errors handled; no typed-nil `error`.
- [ ] Every goroutine has a shutdown path and a waiting owner; channel
      ownership and close responsibility explicit.
- [ ] Contexts passed as first param, never stored in long-lived structs.
- [ ] Zero-value/nil-slice/nil-map/comma-ok semantics deliberate.
- [ ] Slice aliasing and ownership documented at boundaries.
- [ ] Deterministic output: sorted keys, no scheduling-order reliance.
- [ ] Secrets out of errors/logs; privileged ops (unsafe/cgo/exec)
      narrowly scoped.
- [ ] Functions ≤ ~70 lines, gofmt-clean, comments explain intent.
