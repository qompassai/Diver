---
name: tiger-style-zig
description: >
  Write or review Zig code in Matt's Tiger Style: safety-first Zig standard with explicit contracts, error-union handling, bounded work, and disciplined allocator ownership. Use when writing, regenerating, refactoring, reviewing, or debugging Zig - especially systems code, cross-platform libraries, and comptime-heavy designs. Toolchain pairing: zls for LSP (diagnostics, completions, code actions), zig fmt for formatting, lldb-dap for DAP debugging. Covers contract-first design, explicit allocators, exhaustive error sets, bounded buffers, and half-adversarial test splits. Trigger keywords: allocators, error unions, comptime, undefined behavior, packed structs. See references/TIGER_STYLE_ZIG.md for the full guide.
license: Apache-2.0
compatibility: >
  Requires the Zig toolchain with zls for LSP, zig fmt for formatting, and lldb-dap for DAP debugging. Built for Neovim with Matt's diver config (lsp/z_ls, formatters/zig_fmt, lua/dap/zig); usable by any coding agent that can read the guide and invoke the toolchain.
metadata:
    language: zig
    lsp: zls
    formatter: zig fmt
    dap: lldb-dap
    scip_indexer: not-configured
allowed-tools: Read Edit Bash
---

# Tiger Style Zig

## Purpose

Apply Matt's Tiger Style standard to Zig code. Priority order, always:
**Safety > Performance > Developer Experience.** The full guide lives in
[references/TIGER_STYLE_ZIG.md](references/TIGER_STYLE_ZIG.md); this file is
the operational core. When the two disagree, the full guide wins.

## Workflow

1. Pin the toolchain (Zig 0.16.0, target triple, libc, optimization mode).
   Copy signatures from *that* version's standard library; never transplant
   older `std.fs` or child-process snippets across releases.
2. Lay the module out top-to-bottom: imports, domain constants, public
   types/error sets, validation, private leaf work, public orchestration,
   tests. Export only the intended API.
3. Validate external input with error unions; assert internal invariants with
   `std.debug.assert` (one invariant per assert); prove static properties
   with `comptime` checks.
4. Bound everything with named `*_max` constants: loops, allocations, retries,
   queues, nesting depth, captured output.
5. Validate before calling it done: `zig fmt --check`, `zig test` in Debug,
   then `zig test -O ReleaseSafe` and `zig test -O ReleaseFast` so rejection
   survives disabled safety checks.

## Operating Rules

- **Contracts first.** Every function answers: permitted inputs, rejected
  inputs, max work, what state changes, who owns each resource, failure
  behavior — including whether failure leaves state unchanged or partial.
- **Errors are values.** Return documented error unions (e.g.
  `ValidationError!u64`); `try` to propagate, `catch` only for a specific
  recovery policy. No generic `anyerror` on public surfaces. `defer` is
  unconditional scope cleanup; `errdefer` is error-path cleanup until
  ownership transfers — never both freeing the same allocation.
- **`unreachable` is a correctness claim**, never a fallback. Never route
  malformed input, OOM, timeouts, or user configuration to
  `catch unreachable`; it may become unchecked UB in unsafe builds.
- **Ownership is explicit.** `defer` immediately after acquisition; `errdefer`
  while constructing an owned result, then transfer ownership on success.
  Document which allocator must free each returned allocation. Slices borrow,
  they do not own — never return a stack slice. One owner per mutable object.
- **Allocators are parameters, not globals.** Prefer caller-provided buffers
  or fixed capacities when the maximum is known; otherwise accept an
  allocator, cap sizes, and test allocation failure. Never mix allocators
  across free/resize; use `std.testing.allocator` in tests. An arena is not
  a memory bound.
- **Bound everything.** No unbounded recursion (explicit stacks/depth budgets),
  no unbounded retry, no unbounded growth. Retries need idempotency, a shared
  deadline, and bounded backoff.
- **Numbers:** widths by domain; `usize` for addressable lengths, never as a
  wire format. `@addWithOverflow`/`@mulWithOverflow` when explicit reporting
  is needed; `+%`/`+|` only when that behavior *is* the specification.
  Validate narrowing and float-to-int domains; encode endianness explicitly.
- **Absence vs failure:** `?T` is absence, `E!T` is failure. Unwrap with
  `if`/`orelse` at boundaries; `.?` only after an established invariant.
  `undefined` is not a default — every read follows a write.
- **Control flow:** exhaustive `switch` over tagged unions for domain states;
  no broad `else` that hides a new state. Policy decisions outside hot loops.
- **Names:** `TitleCase` types, `camelCase` functions, `snake_case`
  values/fields, units last (`timeout_ms`, `payload_size_bytes`,
  `item_count_max`). No `n`, `sz`, `tmp2`.
- **Formatting:** `zig fmt` owns formatting — four-space layout, ~100 columns,
  ~70-line functions, one statement per line. `zig fmt --check` in CI; never
  manually fight its stable output.
- **Concurrency:** pass the I/O dependency explicitly (0.16's interface-based
  I/O); bound group size, cancel and await owned work before freeing its
  data, and treat cancellation as a real error path. A concurrency-safe
  allocator does not make the objects it allocates thread-safe.
- **Security:** FFI, pointer casts, int-to-pointer, dynamic libraries, build
  scripts, and child processes are privileged boundaries. Localize casts with
  alignment/provenance/length/lifetime justification. Child processes use argv
  form — never hide a shell in a helper that claims a safe argv list.
- **Determinism:** sort keys before serializing; never serialize raw struct
  memory or hash-map iteration order; inject clocks and random sources in
  tests.
- **Comments explain why**, not what — especially why an unchecked operation
  is valid at that point. `//!` for modules, `///` for public declarations.

## Output Contract

Zig you produce for Matt must: compile cleanly under the pinned toolchain,
pass `zig fmt --check`, document allocator ownership and error sets on
exported functions, return error unions on fallible paths, assert invariants,
bound all loops/allocations/retries, stay near 70 lines per function and 100
columns per line, and pass the review checklist.

## Review Checklist

- [ ] External input validated via error unions in every build mode; internal
      invariants asserted; no `catch unreachable` on external failure.
- [ ] All loops/allocations/retries/queues bounded by named constants.
- [ ] `?T` vs `E!T` semantics deliberate; no `.?` without an established
      invariant; no `undefined` reads.
- [ ] Every allocation has one owner; `defer`/`errdefer` placed correctly;
      the freeing allocator is documented.
- [ ] Public error sets are meaningful; no `anyerror` leakage.
- [ ] Integer widths and overflow policy documented; narrowing validated.
- [ ] No hidden global allocator; no mixed allocators; no unjustified FFI
      casts; child processes use argv form.
- [ ] Cancellation handled; no use-after-free of owned work; shared thread
      state and synchronization explicit.
- [ ] Output deterministic where persisted or tested; no hash-map order
      reliance.
- [ ] Functions ≤ ~70 lines, lines ≤ 100 cols, `zig fmt` clean, comments
      explain why.
