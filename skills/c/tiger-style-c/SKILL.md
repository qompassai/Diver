---
name: tiger-style-c
description: >
  Write or review C code in Matt's Tiger Style: safety-first C standard with explicit contracts, assertions, bounded work, and disciplined manual memory ownership. Applies whenever C code is written, regenerated, refactored, reviewed, or debugged - from systems libraries and POSIX/Linux adapters to embedded targets. Toolchain pairing: clangd for LSP (diagnostics, completions, code actions), clang-format for formatting, lldb-dap for DAP debugging. Covers contract-first design, error-code discipline, no hidden allocation, bounded loops and buffers, and half-adversarial test splits. Hardens against buffer overflows, use-after-free, and integer overflow. See references/TIGER_STYLE_C.md for the full guide.
license: Apache-2.0
compatibility: >
  Requires a C toolchain with clangd and clang-format for full LSP and formatting support, plus lldb-dap for DAP debugging. Built for Neovim with Matt's diver config (lsp/clangd_ls, formatters/clang_format, lua/dap/lldb-dap); usable by any coding agent that can read the guide and invoke the toolchain.
metadata:
    language: c
    lsp: clangd
    formatter: clang-format
    dap: lldb-dap
    scip_indexer: not-configured
allowed-tools: Read Edit Bash
---

# Tiger Style C

## Purpose

Apply Matt's Tiger Style standard to C code. Priority order, always:
**Safety > Performance > Developer Experience.** The full guide lives in
[references/TIGER_STYLE_C.md](references/TIGER_STYLE_C.md); this file is
the operational core. When the two disagree, the full guide wins.

## Workflow

1. Declare the contract up front: C standard (C17; gate C23 features on a
   feature check, not a compiler flag), compiler versions, data model, target
   arch, libc, and required POSIX/Linux APIs. Isolate platform adapters from
   portable domain code.
2. Lay the module out: small public header for types/contracts, one
   implementation file for `static` private helpers. Include guards,
   self-contained headers, explicit standard includes, one clear public
   API prefix. No surprising mutable global state from headers.
3. Validate external input with a documented status enum plus output
   parameters; assert internal invariants with `assert()`/`_Static_assert`
   (one invariant per assert). Never validate only inside `assert` —
   `NDEBUG` strips it, and external checks must survive release builds.
4. Bound everything with named `*_MAX` constants: loops, retries, queues,
   sizes, nesting depth, cumulative bytes. Check size multiplication
   (`count <= SIZE_MAX / size`) before allocating.
5. Compile with strict warnings (`-Wall -Wextra -Wpedantic -Wconversion
   -Wshadow`), run under ASan/UBSan, test again with `-DNDEBUG`, then
   review against the checklist below.

## Operating Rules

- **Contracts first.** Every function answers: permitted inputs, rejected
  inputs, max work, what state changes, who owns each resource, failure
  behavior, whether `(NULL, 0)` is valid, and whether outputs stay unchanged
  on failure.
- **Assertions are for invariants**, never for external input. `_Static_assert`
  for compile-time representation constraints; `assert()` for runtime
  invariants. Never acquire resources, validate, or mutate state only inside
  them.
- **Errors are status enums, not prose.** Prefer leaving outputs unchanged
  until success. Capture `errno` right after the failing call, before cleanup
  can clobber it; distinguish library status from OS `errno`. Handle partial
  reads/writes, EOF, interruption — and never blindly retry `close` after
  `EINTR` on Linux (the descriptor may already be released and reused).
- **Bound everything.** No unexplained `while (1)`, no unbounded retry, no
  unbounded growth, no VLAs for external sizes. Retries require an idempotent
  operation, a shared deadline, and bounded backoff.
- **Control flow:** straightforward branches, bounded loops, exhaustive
  handling of accepted states. A `goto` cleanup label is *acceptable*
  (local labels, monotonic ownership) when it beats duplicated cleanup.
  No recursion over attacker-controlled depth; no macros that hide control
  flow or evaluate arguments twice.
- **Absence discipline:** a null pointer, an empty valid span, a missing
  optional value, and an invalid argument are four different things. State
  the `(NULL, 0)` policy per API. Never call a memory function with null
  unless its contract permits it; `memset` is not type-aware
  zero-initialization.
- **Names are `snake_case` functions/fields, `UPPER_SNAKE_CASE` macros**,
  units last: `input_count`, `output_capacity_bytes`. One public prefix;
  never use reserved identifiers (leading `_`+uppercase, `__`). Prefer
  explicit structs/enums over opaque typedef ownership tricks.
- **Formatting:** 4-space indent, max 100 columns, one statement per line,
  braces for multi-step control flow. Pinned clang-format:
  `BasedOnStyle: LLVM`, `IndentWidth: 4`, `ColumnLimit: 100`,
  `UseTab: Never`. Never reformat vendored code.
- **Functions:** ordinary functions stay near or below 70 lines. Signatures
  carry explicit buffers, capacities, statuses, and ownership. No positional
  flag piles; document aliasing/overlap policy per API.
- **Ownership:** one owner per mutable buffer, fd, and handle. One cleanup
  path per acquisition sequence, released in reverse order; record ownership
  immediately after acquisition. Never return a pointer into automatic
  storage or retain a borrowed pointer past its owner's release. Freeing one
  owner pointer does not invalidate aliases — clear the owner and document it.
  Teardown must document how it detects already-released state.
- **Security:** fixed format strings for untrusted text; bounds-check every
  copy (`strncpy` is not a safe `strcpy`); cast non-EOF bytes to
  `unsigned char` for ctype functions. Treat pointer arithmetic, casts, FFI,
  format strings, dynamic loading, and shell/process boundaries as review
  points. Use argv form; never `system()`/`popen()` for externally
  influenced commands. Treat sanitizer findings as real defects until
  disproved.
- **Determinism:** no uninitialized bytes or struct padding to hashes, logs,
  or the wire; explicit byte encodings and stable ordering; fix locale and
  encoding assumptions for parsing; `rand()` is not a security primitive.
- **Comments explain why** and state contracts: pointer validity, size
  units, overlap, thread safety, error outcomes, output mutation, ownership
  transfer, and whether an interface is ISO C, POSIX, or Linux-specific.
- **Concurrency:** documented pthread/C11-atomic protocol; `volatile` is
  not synchronization; data races are UB. Signal handlers must be
  async-signal-safe; define shutdown, wakeup, cancellation, join, and
  buffer lifetime before workers start.
- **Numbers:** `size_t` for object sizes, fixed-width types for protocol
  fields, correct format macros. Signed overflow is UB; unsigned wrap is
  defined but rarely the right size policy. Decode endianness explicitly —
  never cast packet bytes to structs. Never serialize raw struct bytes as a
  portable wire format.

## Output Contract

C you produce for Matt must: compile cleanly under strict warnings for the
declared standard, document contracts in public headers, return status enums
on expected failures with outputs unchanged, assert its invariants, bound all
loops/retries/sizes, pass clean under ASan/UBSan **and** with `-DNDEBUG`,
stay within 100 columns and ~70 lines per function, and pass the review
checklist.

## Review Checklist

- [ ] External input validated with status returns in every build; invariants asserted, never validation-inside-`assert`.
- [ ] All loops/retries/sizes/depths bounded by named constants; size arithmetic checked before allocation.
- [ ] Every allocation result checked; `realloc` via a temporary; `(NULL, 0)` policy stated per API.
- [ ] Null/empty/missing/invalid distinguished; no null passed to memory functions unless the contract permits.
- [ ] Every resource has one owner; one cleanup path covers all failure paths; no pointer into automatic storage escapes.
- [ ] No `system()`/`popen()` or shell interpolation for external input; fixed format strings; argv form used.
- [ ] No uninitialized bytes or padding reach hashes/logs/wire; encoding and locale assumptions explicit.
- [ ] Integer edges, partial I/O, interrupted syscalls, and allocation failure tested; sanitizers clean; tests pass under `-DNDEBUG`.
- [ ] Functions ≤ ~70 lines, lines ≤ 100 cols, clang-format clean, comments explain why and state contracts.
