---
name: tiger-style-cpp
description: >
  Write or review C++ code in Matt's Tiger Style: safety-first C++ standard with explicit contracts, assertions, bounded work, and disciplined RAII ownership. Use when writing, regenerating, refactoring, reviewing, or debugging C++ - especially C++23 with std::expected, services, and performance-sensitive libraries. Toolchain pairing: clangd for LSP (diagnostics, completions, code actions), clang-format for formatting, lldb-dap for DAP debugging. Covers contract-first design, error handling via std::expected, no exceptions across boundaries, bounded containers, and half-adversarial test splits. Trigger keywords: RAII, move semantics, std::expected, exception safety, templates, data race, C++23. See references/TIGER_STYLE_CPP.md for the full guide.
license: Apache-2.0
compatibility: >
  Requires a C++ toolchain (C++23-capable) with clangd and clang-format for full LSP and formatting support, plus lldb-dap for DAP debugging. Built for Neovim with Matt's diver config (lsp/clangd_ls, formatters/clang_format, lua/dap/lldb-dap); usable by any coding agent that can read the guide and invoke the toolchain.
metadata:
    language: cpp
    lsp: clangd
    formatter: clang-format
    dap: lldb-dap
    scip_indexer: not-configured
allowed-tools: Read Edit Bash
---

# Tiger Style C++

## Purpose

Apply Matt's Tiger Style standard to C++. Priority order, always:
**Safety > Performance > Developer Experience.** The full guide lives in
[references/TIGER_STYLE_CPP.md](references/TIGER_STYLE_CPP.md); this file is
the operational core. When the two disagree, the full guide wins.

## Workflow

1. Declare the profile up front: language standard (C++23 reference;
   C++20 needs an explicit expected-result alternative), compiler, standard
   library, exception policy, and target platform.
2. Lay the module out top-to-bottom: purpose comment, narrow public header
   with domain types and contracts first, private implementation helpers,
   Rule-of-Zero value types where possible.
3. Validate external input with `std::expected<T, E>`; assert internal
   invariants with `static_assert` (compile-time) and `assert()` (runtime —
   remember `NDEBUG` removes it).
4. Bound everything with named `constexpr` constants: item counts, byte
   sizes, nesting depth, retries, queues, captured output.
5. Review against the checklist below before calling the code done.

## Operating Rules

- **Contracts first.** Every public operation answers: permitted inputs,
  rejected inputs, max work, what state changes, who owns each resource,
  failure behavior (unchanged / valid-but-changed / partial — documented).
- **Errors:** one exception policy plus one typed expected-error policy per
  subsystem. `std::expected<T, E>` carries routine domain failure — check
  state before touching value or error. Never let an exception cross a C
  ABI boundary; translate it there.
- **Assertions are for programmer errors**, never for external input. No
  side effects inside assertions. A `std::span` is a borrow, not a bounds
  check — prove indices before access.
- **Bound everything.** No unexplained `while (true)`, no unbounded retry,
  no unbounded growth. Retries require an idempotent op and a shared
  deadline; name the budgets (`item_count_max`, `input_bytes_max`).
- **Ownership:** RAII and the Rule of Zero. `unique_ptr` for exclusive heap
  ownership; `shared_ptr` only for genuine shared ownership, cycles broken
  deliberately. Destructors are nonthrowing. Fallible completion (flush,
  commit) gets an explicit checked finish *before* cleanup.
- **Views borrow, never own.** `std::string_view` / `std::span` do not extend
  lifetime; keep them in the smallest useful scope; never return references
  to temporaries or locals. Capturing `this` in a lambda keeps nothing alive.
- **Numbers:** signed overflow is UB; unsigned wrapping is not a capacity
  policy. Check before conversion and arithmetic (`value > total_max - total`
  before `+=`). No C-style casts, no silent negative-to-`size_t` conversion.
- **Absence:** `std::optional` for absence, `std::expected` for failure —
  never a null pointer or magic integer carrying several meanings. Moved-from
  objects are valid but unspecified; don't assume "empty".
- **Names:** `snake_case` for functions/variables, `PascalCase` for domain
  types, units last: `payload_size_bytes`, `timeout` as `std::chrono`
  durations. No `n`, `tmp2`, reserved identifiers, or ownership-hiding prefixes.
- **Formatting:** pinned clang-format — `BasedOnStyle: LLVM`,
  `IndentWidth: 4`, `ColumnLimit: 100`, `UseTab: Never`. Includes organized,
  headers self-contained; run semantic rewrites separately from formatting.
- **Functions:** ordinary functions stay near or below 70 lines. Narrow
  interfaces, explicit result types, domain option structs over boolean flag
  lists.
- **Concurrency:** prefer `std::jthread` with an explicit stop-token
  protocol — stopping is cooperative, not forced. Data races are UB;
  `volatile` does not synchronize. Coroutine frames need a clear owner.
- **Security:** treat reinterpretation, raw pointers, C casts, format
  strings, and dynamic loading as trust boundaries. Build with warnings
  plus ASan/UBSan (`-Wall -Wextra -Wpedantic -fsanitize=address,undefined`).
- **Determinism:** never serialize raw object representation (padding,
  vptrs, endianness); unordered-container iteration must not define
  canonical output; inject clocks/randomness in tests.
- **Comments explain why** (lifetimes, why a cast is valid, exception
  guarantees, complexity bounds), not what. A `noexcept` must be justified
  across every called operation.

## Output Contract

C++ you produce for Matt must: compile cleanly under the declared profile,
carry documented contracts on public operations, assert its invariants,
return `std::expected` on expected failures, bound all loops/retries/queues,
give every resource one RAII owner with failure-path teardown, stay within
100 columns and ~70 lines per function, and pass the review checklist.

## Review Checklist

- [ ] External input validated before use; internal invariants asserted; release (`NDEBUG`) behavior tested separately.
- [ ] All loops/retries/queues/allocations bounded by named `constexpr` constants.
- [ ] Ownership explicit on success and every failure path; no `new`/`delete`, no dangling views or captures.
- [ ] `std::expected` checked before value/error access; exception guarantees documented; no throw across C ABI.
- [ ] Arithmetic checked before conversion/overflow; units explicit in names and types.
- [ ] No shell construction from untrusted input; argv form used; no `std::system` on external inputs.
- [ ] Functions ≤ ~70 lines, lines ≤ 100 cols, clang-format clean, comments explain intent.
