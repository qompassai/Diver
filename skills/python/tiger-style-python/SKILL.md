---
name: tiger-style-python
description: >
  Write or review Python code in Matt's Tiger Style: safety-first Python standard with explicit contracts, assertions, bounded work, and disciplined ownership. Use when writing, regenerating, refactoring, reviewing, or debugging Python - especially scripts, CLIs, and services. Toolchain pairing: ruff for LSP (lint diagnostics, code actions), black and ruff-format for formatting, debugpy for DAP debugging. Covers contract-first design, typed signatures, exception discipline, bounded I/O and retries, and half-adversarial test splits. Trigger keywords: type hints, exception chaining, asyncio, import cycle, packaging, GIL. See references/TIGER_STYLE_PYTHON.md for the full guide.
license: Apache-2.0
compatibility: >
  Requires Python 3 with ruff (LSP), black or ruff-format, and debugpy for full LSP, formatting, and DAP support. Built for Neovim with Matt's diver config (lsp/ruff_ls, formatters/black, lua/dap/python); usable by any coding agent that can read the guide and invoke the toolchain.
metadata:
    language: python
    lsp: ruff
    formatter: black
    dap: debugpy
    scip_indexer: not-configured
allowed-tools: Read Edit Bash
---

# Tiger Style Python

## Purpose

Apply Matt's Tiger Style standard to Python code. Priority order, always:
**Safety > Performance > Developer Experience.** The full guide lives in
[references/TIGER_STYLE_PYTHON.md](references/TIGER_STYLE_PYTHON.md); this
file is the operational core. When the two disagree, the full guide wins.

## Workflow

1. Declare the interpreter (CPython 3.12+ target) and platform up front.
   Never assume the GIL, reference counting, or a particular ABI — put
   runtime-specific behavior (3.14 free-threading, OS adapters) behind an
   explicit boundary. Type hints are dev checks, not runtime validation.
2. Lay the module out top-to-bottom: docstring/purpose, public types and
   constants, private validation helpers, leaf logic, orchestration,
   explicit `main()` with `if __name__ == "__main__":`. Keep
   `__init__.py` light; imports must not start threads or touch services.
3. Validate external input by raising a precise domain exception (e.g.
   `ValidationError`); assert only programmer invariants — remember
   `python -O` strips `assert`, so external rejection must survive it.
4. Bound everything with named `UPPER_SNAKE_CASE` constants: input bytes,
   item counts, nesting depth, retries, queues, captured output.
5. Review against the checklist below before calling the code done.

## Operating Rules

- **Contracts first.** Every function answers: permitted inputs, rejected
  inputs, max work, what state changes, who owns each resource, failure
  behavior. State whether failure leaves state unchanged or partial.
- **Errors:** use domain exception classes (or one explicit result type)
  consistently per boundary; catch only failures the layer can interpret.
  Add context with `raise DomainError(...) from exc`. Never `except
  BaseException: pass` — interrupts and cancellation must propagate.
  No authorization or mutation inside `assert`.
- **Bound everything.** No unbounded `list(iterator)`, task creation, or
  retry. Retries need an idempotent operation, a shared deadline, bounded
  backoff, and an injected jitter source.
- **Control flow:** early returns for invalid cases, ordinary loops for
  stateful work. Comprehensions only for simple transforms of already
  bounded collections; no nested comprehensions with hidden effects.
- **Absence discipline:** `value is None`, never `value or default` when
  `False`/`0` is valid. Use a sentinel to distinguish omitted from
  explicit `None`; never use mutable default arguments.
- **Names:** `snake_case` functions/variables, `PascalCase` classes,
  `UPPER_SNAKE_CASE` constants, units in names (`payload_size_bytes`,
  `deadline_monotonic_s`). Leading underscore for nonpublic; never invent
  dunder methods.
- **Type hints:** annotate public functions; prefer `Protocol` over broad
  `object`. Hints describe real values — no `Any`/`cast` to silence
  diagnostics, and never an unchecked cast after an annotation. Decide
  deliberately whether `bool` counts as `int` (prefer exact `type(x) is
  int` at strict boundaries).
- **Formatting:** 4-space indent, 100 columns, one configured formatter —
  Ruff's (`[tool.ruff] target-version = "py312"`, `line-length = 100`).
  Stable import ordering, no competing formatters in sequence. Pin
  formatter and type-checker versions.
- **Functions:** ordinary functions stay near or below 70 lines. Use
  keyword-only arguments for policy flags instead of positional booleans.
  Separate decoding, validation, computation, and I/O; return a stable
  shape for similar errors.
- **Resources:** one clear owner per file, lock, transaction, subprocess.
  Use context managers (`ExitStack`/`AsyncExitStack` for variable counts);
  register cleanup as acquisition succeeds. Never rely on `__del__`;
  never return truthy from `__exit__` by accident.
- **Security:** never `pickle.loads` untrusted bytes, `eval`/`exec`
  external text, or import from untrusted paths. Parameterized SQL, argv
  arrays with `shell=False`, validated URL schemes. A venv is not a
  sandbox.
- **Processes:** every `subprocess` call gets explicit argv, cwd, env,
  deadline, and output bounds; a timeout has a cleanup owner that stops,
  drains, and reaps. Distinguish exit status, signal, timeout, and launch
  failure.
- **Concurrency:** `asyncio.TaskGroup` for related tasks; bound admission
  before creating tasks. Re-check state after every `await`; clean up in
  `finally` and re-raise `CancelledError`. Use processes for killable
  untrusted computation.
- **Determinism:** sort canonical keys before serializing; never let set
  iteration order define a wire format. Inject clocks and randomness; use
  `secrets` for tokens, monotonic clocks for deadlines.
- **Comments explain why**, not what. Docstrings carry the public
  contract: units, accepted types, raised exceptions, side effects,
  cancellation behavior.

## Output Contract

Python you produce for Matt must: run under `python` and `python -O`
identically, carry type hints on public functions, raise precise domain
exceptions on expected failures, assert only internal invariants, bound
all input/loops/retries/queues with named constants, close every resource
via a context manager, stay within 100 columns and ~70 lines per
function, and pass the review checklist.

## Review Checklist

- [ ] External input validated by explicit raise; invariants asserted (and
      valid under `-O`).
- [ ] All input sizes, loops, retries, queues, output captures bounded by
      named constants.
- [ ] `None` vs `False`/`0` semantics deliberate; no mutable default args.
- [ ] Names explicit with units; type hints real, no `Any`/`cast` escapes.
- [ ] Every resource has one owner; cleanup runs on failure paths.
- [ ] No `pickle`/`eval` of untrusted data; subprocess uses argv form with
      timeout and cleanup owner.
- [ ] Async code re-checks state after `await`; cancellation propagates.
- [ ] Output deterministic where persisted or tested; no set-order reliance.
- [ ] Functions ≤ ~70 lines, lines ≤ 100 cols, one formatter (Ruff).
