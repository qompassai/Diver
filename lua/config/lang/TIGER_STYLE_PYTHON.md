<!-- TIGER_STYLE_PYTHON.md — Independent language adaptation; no active scripts. -->
# Tiger Style for Python

> **Safety first. Performance second. Developer experience third.**

**Guide version:** 1.0  
**Primary target:** CPython 3.12+; Python 3.14 behavior called out explicitly  
**Line-width review target:** 100 columns, subject to the language formatter  
**Ordinary function review threshold:** 70 physical source lines  
**Platform emphasis:** Arch Linux; portable core with explicit OS adapters

This guide follows the structure of your Lua guide while adapting contracts,
errors, numbers, ownership, concurrency, tooling, and examples to Python.
It remains usable as plain Markdown; the rich-documentation sections are
optional and contain no required remote assets or executable scripts.

## Table of Contents

1. [The Tiger Style Contract](#1-the-tiger-style-contract)
2. [Language and Runtime Assumptions](#2-language-and-runtime-assumptions)
3. [File and Module Layout](#3-file-and-module-layout)
4. [Assertions, Preconditions, and Postconditions](#4-assertions-preconditions-and-postconditions)
5. [Bound Everything](#5-bound-everything)
6. [Control Flow](#6-control-flow)
7. [Error Handling](#7-error-handling)
8. [Absence, False, and Defaults](#8-absence-false-and-defaults)
9. [Numbers, Counts, and Units](#9-numbers-counts-and-units)
10. [Collections and Data Shapes](#10-collections-and-data-shapes)
11. [State and Mutation](#11-state-and-mutation)
12. [Function Design](#12-function-design)
13. [Scope](#13-scope)
14. [Resource Lifetime](#14-resource-lifetime)
15. [Memory and Allocation](#15-memory-and-allocation)
16. [Performance](#16-performance)
17. [Determinism](#17-determinism)
18. [Security](#18-security)
19. [Filesystem Safety](#19-filesystem-safety)
20. [Processes and Shells](#20-processes-and-shells)
21. [Concurrency and Async Work](#21-concurrency-and-async-work)
22. [Naming](#22-naming)
23. [Formatting](#23-formatting)
24. [Comments and Documentation](#24-comments-and-documentation)
25. [Dependencies](#25-dependencies)
26. [Language-Specific Engineering](#26-language-specific-engineering)
27. [Arch Linux Development](#27-arch-linux-development)
28. [Testing](#28-testing)
29. [Review Checklist](#29-review-checklist)
30. [Anti-Patterns](#30-anti-patterns)
31. [Reference Module](#31-reference-module)
32. [Images](#32-images)
33. [HTML](#33-html)
34. [CSS](#34-css)
35. [SVG Diagrams](#35-svg-diagrams)
36. [Video](#36-video)
37. [JavaScript in Documentation](#37-javascript-in-documentation)
38. [Mathematics and Resource Models](#38-mathematics-and-resource-models)
39. [Renderer Compatibility](#39-renderer-compatibility)
40. [Suggested Repository Layout](#40-suggested-repository-layout)
41. [Sources](#41-sources)

---

## 1. The Tiger Style Contract

This is an independent language adaptation of the engineering philosophy in
TigerBeetle's Tiger Style and the supplied **Tiger Style for Lua, version 1.0**.
It is not an official TigerBeetle standard. The hierarchy is a project policy:

1. Preserve correctness, invariants, resource bounds, and authority boundaries.
2. Make resource use predictable and optimize measured costs.
3. Make the implementation easy to read, review, test, and maintain.

The implementation should reveal permitted inputs, failure outcomes, maximum
work, mutable state, resource owners, and success postconditions. A compiler
check is useful evidence, not a replacement for a runtime trust boundary.

**MUST** marks a safety requirement of this guide. **SHOULD** marks a default
that may be changed with a documented reason. Language facts and project policy
are deliberately separate. The 70-line function threshold and 100-column target
are review aids; never damage idiomatic formatter output to satisfy a metric.

At each public operation, record: **input → validation → bounded computation →
validated change → commit → cleanup**. State precisely whether failure leaves
state unchanged, partially updated, or requiring recovery.

---

## 2. Language and Runtime Assumptions

Declare the interpreter implementation, minimum minor version, supported upper
versions, and operating systems. The reference targets Python 3.12+; do not assume
CPython reference counting, the GIL, or a particular extension ABI applies to
PyPy or every build. Python 3.14 includes optional free-threaded configurations;
shared-state correctness must come from synchronization, not a GIL assumption.
Type hints are development checks, not runtime validation. [P1]

---

## 3. File and Module Layout

Use a small package under `src/`, public types/constants near the top, private
validation helpers, then orchestration. Keep `__init__.py` light. Imports should
not start threads, contact services, install packages, or rewrite configuration.
Use an explicit `main()` and `if __name__ == "__main__":` for entry points.
Avoid wildcard imports and files named after standard-library modules.

---

## 4. Assertions, Preconditions, and Postconditions

Use `assert` for a programmer invariant that is not required for safe rejection.
Python can remove assertion statements with optimization, including `python -O`.
Do not perform mutation or authorization inside an assertion. Explicitly raise a
suitable exception for malformed external values; verify that behavior under
optimized execution. [P2]

Prefer small, independently testable validators with precise postconditions over
an annotation followed by an unchecked cast.

---

## 5. Bound Everything

A count bound alone is not a complete resource budget. Bound item count,
individual item size, nesting depth, cumulative bytes, concurrent work, waiting
work, elapsed time, and retry amplification separately.

| Resource | Example policy | Exhaustion behavior |
| --- | --- | --- |
| Input bytes | 1 MiB before decoding | Reject before allocation grows further. |
| Collection items | 1,024 | Return a capacity error. |
| Nesting depth | 32 | Reject the structure. |
| Active jobs | 8 | Admit to a bounded queue or reject. |
| Queue entries | 64 | Apply backpressure; do not silently drop work. |
| Attempts | 3 total, within one deadline | Return the final classified failure. |
| Captured output | 256 KiB per stream | Stop capture and terminate or drain by policy. |

These values are examples, not universal defaults. Derive actual limits from
workload and deployment budgets. Streaming, lazy evaluation, and asynchronous
APIs do not automatically bound total consumption. Reject compressed data based
on both compressed and expanded sizes. A long-lived service can have an open-ended
lifetime while each iteration and its owned work remain bounded.

Retries MUST require an idempotent operation or an idempotency mechanism.
Use a shared deadline, bounded backoff, and an injected random source for jitter;
never multiply independent retry policies invisibly across layers.

---

## 6. Control Flow

Use early returns for invalid cases and ordinary loops for stateful work.
Comprehensions suit simple transformations of already bounded collections;
avoid nested comprehensions with hidden effects. Bound recursive input or use an
explicit stack. Avoid truthiness-based shortcuts when zero, empty strings, or
`False` are meaningful domain values.

---

## 7. Error Handling

Use domain exception classes or an explicit result type consistently at a
boundary. Catch only failures the layer can interpret. Add context with
`raise DomainError(...) from exc`; avoid leaking secret values in messages.
Do not catch `BaseException` casually: process exit, interrupts, and cancellation
must not become a successful default. A broad `except Exception` at an outer
service boundary still needs logging, cleanup, and a defined failure response.

---

## 8. Absence, False, and Defaults

Use `None` for one documented absence meaning. Test `value is None`, rather
than `value or default`, when false or zero is valid. Use a unique sentinel to
distinguish an omitted argument from an explicit `None`. Avoid mutable default
arguments; construct a new collection per call. `Optional[T]` means `T | None`,
not “argument may be left out.”

---

## 9. Numbers, Counts, and Units

Python integers grow rather than overflowing at a fixed machine width, but
huge arithmetic can exhaust CPU and memory. Validate magnitude and textual digit
limits before expensive conversion. Reject NaN/infinity where ordering or bounds
assume a finite number. `bool` is a subclass of `int`; validators that mean a
literal integer should decide deliberately whether to accept it. Use integer
minor units or `Decimal` for exact decimal domains, and monotonic clocks for
elapsed deadlines.

---

## 10. Collections and Data Shapes

Use a dataclass, `TypedDict`, or protocol to document a record's shape, then
validate data coming from JSON, files, network peers, or plugins. Prefer tuples
for stable sequences and immutable values where appropriate. A frozen dataclass
is not recursively immutable if a field contains a list. Specify whether a
function accepts arbitrary iterables or only materialized bounded sequences;
calling `list()` on an unknown iterator can run forever.

---

## 11. State and Mutation

Keep mutable state owned by one object/task or protect it with a suitable lock.
Validate a proposed update before changing persistent or shared state. Avoid
module globals as an implicit dependency-injection system. Copy mutable input
when retaining it beyond the call, or document the borrow contract. A shallow
copy still aliases nested values.

---

## 12. Function Design

Use keyword-only arguments for policies that would otherwise be positional
booleans. Separate decoding, validation, computation, and I/O. Return a stable
shape; do not alternate between false, a string, and an object for similar errors.
Annotate public functions and narrow interfaces using `Protocol` where useful.
Do not introduce a class solely to hide a stateless two-line function.

---

## 13. Scope

Keep references to large payloads short-lived. Close over immutable request
identifiers rather than whole request objects when possible. Avoid a loop closure
that observes a later iteration's variable; pass the value explicitly. In async
code, re-check state after every await that permits another task to mutate it.

---

## 14. Resource Lifetime

Use context managers for files, locks, and transactions; `ExitStack` or
`AsyncExitStack` can own a variable number of resources. Register cleanup as
acquisition succeeds. Do not rely on `__del__` or prompt garbage collection for
correctness. Decide how to preserve both the main exception and a cleanup error.
A context manager must not suppress failure accidentally by returning truthy
from `__exit__`.

---

## 15. Memory and Allocation

Bound caches, logs, decoded objects, retained tracebacks, and queued tasks.
Generators reduce eager allocation only while their consumers stay incremental;
`list(generator)` restores the full allocation. `deque(maxlen=...)` discards old
items silently, so do not use it for a work queue unless dropping is the policy.
Budget encoded and decoded representations separately. Use `tracemalloc` to
investigate retention before adding forced GC calls.

---

## 16. Performance

Measure with `cProfile`, `time.perf_counter`, and allocation tools on representative
loads. Avoid repeated string concatenation for large output; bounded fragments
and `str.join` make ownership clearer. Do not move work to a thread and assume
CPU speedup or cancellation; interpreter build and extension behavior matter.
Batch I/O without turning the batch into an unbounded collection.

---

## 17. Determinism

Dictionary insertion order is defined, but insertion order may depend on
nondeterministic input. Sets and hash-based iteration must not define a wire
format. Sort canonical keys explicitly. Inject clocks and randomness, fix
encoding and newline rules, and separate locale-aware presentation from stable
serialization. Use `secrets` or a reviewed cryptographic API for secret tokens,
not `random`.

---

## 18. Security

Never deserialize attacker-controlled `pickle`, execute external text with
`eval`/`exec`, or import plugins from an untrusted writable search path. Review
YAML loaders and template engines as code-execution boundaries. Use parameterized
SQL and safe argument arrays. Validate URL schemes and destinations before
network access; redirects need the same policy. An isolated virtual environment
manages packages; it is not a sandbox for hostile Python. [P3]

---

## 19. Filesystem Safety

Path normalization is not authorization. Reject embedded NUL where an API may
truncate strings; define absolute/relative path, symlink, hard-link, and file-type
policy. A `startsWith(root)` check is not containment. Under hostile concurrent
filesystem changes, resolve relative to a trusted directory handle and use
appropriate OS constraints, such as Linux `openat2` resolution flags where
available; a `realpath` check followed by a separate open can race.

Create sensitive files exclusively with restrictive permissions. For replacement,
write a temporary file in the destination directory, check write/flush/close
errors, then rename. Atomic replacement is not the same as crash durability;
when required, sync the file and containing directory using the platform API.
Preserve or intentionally change permissions and ownership. Never recursively
remove an unvalidated path supplied by another process.
Use context-managed file descriptors and `tempfile` primitives. `Path.resolve()`
and `Path.is_relative_to()` are useful lexical/snapshot checks but cannot alone
close a check-then-open race. Use descriptor-relative OS APIs for stronger Linux
policies. Check serialized byte size before a write; a Unicode character count
is not a UTF-8 byte budget.

---

## 20. Processes and Shells

An argv API prevents shell parsing, not option injection or execution of an
untrusted program. Choose the executable from trusted configuration; use `--`
only where that tool documents it. Give cwd and environment an explicit policy.
Consume stdout and stderr concurrently where necessary to avoid pipe deadlock,
cap retained bytes, and distinguish exit status, signal, timeout, and launch
failure. A nonempty stderr stream is not by itself a failed exit.

A timeout MUST have a cleanup owner: stop the process, escalate by policy, drain
or close pipes, and reap/join it. Killing one process does not necessarily stop
its descendants. Treat POSIX process groups and Windows process ownership as
separate platform implementations.
Use `subprocess` with an argument sequence and `shell=False`. `run(...,
timeout=...)` bounds a wait, while `capture_output=True` can still retain unlimited
output; use bounded streaming or a deliberate file policy for untrusted children.
`Popen.communicate(timeout=...)` requires explicit cleanup after a timeout. For
async children use `asyncio.create_subprocess_exec`, and still terminate and
reap on cancellation. [P4]

---

## 21. Concurrency and Async Work

Use `asyncio.TaskGroup` for related tasks with one lifetime, and bound admission
before task creation. A semaphore inside a million already-created tasks does not
bound task memory. `asyncio.timeout` implements cooperative cancellation, not a
hard CPU deadline. Clean up in `finally` and normally re-raise `CancelledError`.
Cancelling a thread-offload await does not forcibly stop that thread. [P5]

Use processes for killable untrusted computation; use explicit locks or message
ownership for shared mutation in both GIL and free-threaded builds.

---

## 22. Naming

Use `snake_case` for functions/variables, `PascalCase` for classes, and
`UPPER_SNAKE_CASE` for constants. Names such as `payload_size_bytes` and
`deadline_monotonic_s` expose units. Reserve a leading underscore for nonpublic
implementation details; do not invent double-underscore protocol methods.
Prefer a precise domain exception name over `SomethingError`.

---

## 23. Formatting

Use four spaces and one configured formatter, such as Ruff's formatter. Set a
100-column target, while accepting formatter exceptions for indivisible strings.
Do not run competing formatters in sequence. Keep imports explicit and use the
formatter/linter's stable ordering.

```toml
[tool.ruff]
target-version = "py312"
line-length = 100
```

Pin formatter and type-checker versions in development dependencies.

---

## 24. Comments and Documentation

Document parameter units, accepted types, raised exceptions, retained aliases,
side effects, and cancellation behavior. Type hints should describe real values,
not silence diagnostics with `Any` or `cast`. Use docstrings for public contracts
and comments for non-obvious invariants. Examples must run without production
credentials or network access unless clearly marked as integration examples.

---

## 25. Dependencies

Use a project virtual environment and a declared `pyproject.toml`; never replace
Arch's managed Python files or use `sudo pip`. Pin application dependencies with
a reviewed lock process, and verify hashes when installing from a requirements
lock that includes them. Build backends and source-distribution hooks execute
code. A resolver and vulnerability scan are useful checks, not a trust proof.

---

## 26. Language-Specific Engineering

Watch Python-specific traps: `bool` passes `isinstance(x, int)`, defaults can
share mutable objects, generators defer work/errors, properties can execute code,
and type annotations are not runtime guards. Accepting `object` means validation
is required; it cannot make a malicious in-process object safe. The reference
accepts only exact built-in lists/tuples and exact integers to keep its input
contract narrow. Production byte decoders must impose limits before creating
those containers.

---

## 27. Arch Linux Development

Use a supported Arch installation and a coherent full-system update; avoid
partial upgrades. Prefer distribution packages where they meet the declared
toolchain contract. Pin project versions separately when Arch's rolling version
moves beyond that contract. Review AUR `PKGBUILD`, sources, checksums, and hooks.
Build as an ordinary user; never use `sudo` for project package managers.

Keep configuration, caches, state, and temporary runtime files in their proper
XDG locations when writing user applications. Honor explicit overrides; avoid
assuming the current directory is trusted. Do not put credentials in a repo,
build cache, environment dump, or command line. The commands below are validation
recipes, not automatic installation scripts. Run project build code only after
reviewing the repository and its dependencies.
```sh
python --version
python -m venv .venv
# Install the project's reviewed, pinned development dependencies into .venv.
.venv/bin/python -m ruff check .
.venv/bin/python -m ruff format --check .
.venv/bin/python -m mypy --strict src
python examples/bounded_sum.py
python -O examples/bounded_sum.py
```

Choose one authoritative type-checker policy if also using Pyright/basedpyright;
explain genuine differences instead of globally suppressing diagnostics.

---

## 28. Testing

Use `unittest` or another reviewed runner. Check missing values, false/zero,
empty input, maximum count, oversize input, wrong types, negative numbers, and
resource exhaustion. Run boundary validation under `-O` to catch reliance on
assertions. For async components test timeout, cancellation, sibling failure,
stale generations, and cleanup. Property tests need bounded generators and
reproducible seeds or recorded failing examples.

---

## 29. Review Checklist

- [ ] The compiler/runtime, platform, and supported build modes are explicit.
- [ ] External bytes are bounded before decoding and shape validation.
- [ ] Assertions diagnose bugs; external rejection survives release settings.
- [ ] Numeric domain, units, conversion, and overflow policy are documented.
- [ ] Collections have both count and byte budgets.
- [ ] Ownership and borrowing are clear on success and every failure path.
- [ ] State is committed only after validation, or partial mutation is documented.
- [ ] Cancellation stops or joins owned work; a timeout is not mistaken for cleanup.
- [ ] Stale asynchronous results cannot mutate a newer generation of state.
- [ ] Paths use a stated symlink and race policy; string prefixes are not containment.
- [ ] Processes have explicit argv, cwd, environment, deadlines, and output bounds.
- [ ] Secrets are absent from logs, command arguments, build outputs, and fixtures.
- [ ] Dependencies and build hooks have been reviewed and versions recorded.
- [ ] Ordering, clocks, locale, and randomness are explicit where reproducibility matters.
- [ ] Boundary, exhaustion, cleanup, and production-mode behavior are tested.
- [ ] Ordinary functions are reviewed near 70 lines; formatting uses one tool.
- [ ] Exceptions to this guide name an owner, reason, evidence, and review date.

---

## 30. Anti-Patterns

| Avoid | Prefer |
| --- | --- |
| `assert authorized` for user access | An explicit rejection path. |
| `enabled = value or True` | A deliberate `None` check. |
| `def f(items=[])` | A sentinel/default plus fresh allocation. |
| `except BaseException: pass` | Narrow handling with cleanup and propagation. |
| Unbounded `list(iterator)` or task creation | Bounded admission and consumption. |
| `pickle.loads(untrusted_bytes)` | A bounded data format and shape validation. |

---

## 31. Reference Module

The reference computes a total from at most **1,024 nonnegative integers**,
with a maximum total of **1,000,000**. It validates count first, then visits
elements in order, returning the first element/budget error encountered. It
uses `value > maximum - total` before addition. The input remains unchanged;
no partial successful result is published. A caller must not mutate borrowed
input concurrently. The decoded container already exists: upstream byte parsing
needs its own byte, allocation, and depth limits.

Time is O(n) with n <= 1,024 for the admitted arithmetic loop. Auxiliary
accumulator state is constant-sized; runtime representation, input storage,
validation overhead, and the bundled test fixtures are separate costs.

Complete source: [examples/bounded_sum.py](examples/bounded_sum.py). Run instructions and actual validation
results are in the collection README and VALIDATION.md. This is a deliberately
small reference for arithmetic/contracts, not a claim to implement the file,
process, or async policies described elsewhere.

```python
"""Bounded pure arithmetic; run directly, including with python -O."""

ITEM_COUNT_MAX = 1024
TOTAL_MAX = 1_000_000


class ValidationError(ValueError):
    """A request violates this module's public contract."""


class InvalidInputError(ValidationError):
    pass


class InvalidItemError(ValidationError):
    pass


class TooManyItemsError(ValidationError):
    pass


class TotalExceededError(ValidationError):
    pass


def bounded_sum(items: object) -> int:
    """Accept exact list/tuple containers of exact, nonnegative built-in ints.

    Borrow only for this call. The caller must not mutate input concurrently.
    Return a total <= TOTAL_MAX; never modify input or retain it.
    """
    if type(items) is not list and type(items) is not tuple:
        raise InvalidInputError("expected a built-in list or tuple")
    if len(items) > ITEM_COUNT_MAX:
        raise TooManyItemsError("item count exceeds limit")
    total = 0
    for value in items:
        if type(value) is not int or value < 0:
            raise InvalidItemError("expected a nonnegative integer, not bool")
        if value > TOTAL_MAX - total:
            raise TotalExceededError("total exceeds limit")
        total += value
    return total


def main() -> None:
    successful = [([], 0), ([1], 1), ([999_999, 1], TOTAL_MAX), ([0] * 1024, 0)]
    for items, expected in successful:
        if bounded_sum(items) != expected:
            raise RuntimeError("success postcondition failed")
    rejected: list[tuple[object, type[ValidationError]]] = [
        (None, InvalidInputError),
        ("12", InvalidInputError),
        ([True], InvalidItemError),
        ([1.5], InvalidItemError),
        ([-1], InvalidItemError),
        ([0] * 1025, TooManyItemsError),
        ([1_000_001], TotalExceededError),
        ([TOTAL_MAX, 1], TotalExceededError),
        ([2**63 - 1], TotalExceededError),
    ]
    for items, error_type in rejected:
        try:
            bounded_sum(items)
        except error_type:
            continue
        raise RuntimeError("invalid request was accepted")
    print("Python: 13 cases passed")


if __name__ == "__main__":
    main()
```

---

## 32. Images

Use images only when they explain a relationship better than text. Give each
image descriptive alternative text and ship the asset in the same repository.
Prefer a static SVG for precise diagrams and WebP/PNG for screenshots. Strip
private metadata and credentials from screenshots before publication.

A linked image must exist. This guide does not contain placeholder image links;
the optional image syntax below is a template for a future real asset:

```markdown
![Owned resources and their cleanup paths](assets/resource-lifetime.svg)
```

Keep the contract available as prose so an image failure cannot hide a rule.

---

## 33. HTML

Use semantic Markdown first. Native disclosure widgets provide a useful
progressive enhancement without scripts:

<details>
<summary><strong>Failure contract</strong></summary>

A failure result identifies whether the operation committed state. Resource
cleanup has one owner, and cleanup errors follow a documented reporting policy.

</details>

Do not embed unsanitized user HTML. A trusted documentation renderer is a separate
execution environment from the application being documented.

---

## 34. CSS

Styling must not carry meaning that disappears when CSS is removed. Use a local
stylesheet in a controlled documentation site; GitHub-style renderers may strip
it. Maintain readable contrast, keyboard focus visibility, and a printable view.

```css
.tiger-note {
    border-inline-start: 0.25rem solid #087ea4;
    padding-inline-start: 1rem;
}
@media print {
    .tiger-interactive { display: none; }
}
```

This is an illustrative stylesheet, not active content required by this guide.
Avoid remote fonts, trackers, and styles merely to present a coding standard.

---

## 35. SVG Diagrams

For architecture drawings, use static SVG with a title, description, explicit
view box, and no scripts or external resource loads. Treat an untrusted SVG as
active document content until sanitized. Store actual assets alongside the guide.

The ownership diagram should show the resource's creator, current owner,
transfer point, and success/error/cancellation cleanup paths. A straight sequence
of labels is better expressed in prose than a large decorative diagram.

---

## 36. Video

Videos can demonstrate debugging or a formatter workflow; they must not be the
only source of a rule. Provide a transcript or accompanying steps, playback
controls, captions where practical, and a link fallback. Do not autoplay.

The following is a template, not a claim that media files are bundled:

```html
<video controls preload="none">
  <source src="assets/debugging.webm" type="video/webm">
  <a href="assets/debugging.webm">Open the debugging demonstration</a>
</video>
```

Verify the files exist before enabling this markup in a published page.

---

## 37. JavaScript in Documentation

Documentation does not require JavaScript. Prefer `<details>` for disclosure
and plain links for navigation. If a trusted site adds interactivity, keep scripts
local, apply an appropriate Content Security Policy, and validate DOM lookups.
Insert untrusted text using `textContent`, not `innerHTML`; avoid inline event
handlers and dynamic evaluation. The full standard must remain readable with
scripts disabled. No executable scripts are embedded in this guide.

---

## 38. Mathematics and Resource Models

Use mathematics to state a checkable contract, with a prose fallback.
For a zero-based slice of `length` elements, a range starting at `offset` and
containing `count` elements is valid when:

$$
0 \leq offset \leq length,\qquad 0 \leq count \leq length-offset.
$$

Check `offset <= length` before subtracting. This avoids an overflowing
`offset + count` test and allows an empty range at the end.

For admission control with at most $J$ active jobs and $Q$ queued jobs:

$$
M_{retained} \leq M_{base} + J M_{job,max} + Q M_{queued,max} + M_{cache,max}.
$$

Count parser expansion, allocator overhead, stacks, and runtime overhead in
real budgets; this model only covers the categories explicitly included.
For a measured latency budget, distinguish queue wait, I/O, compute, and commit.
No equation here is a hard-real-time guarantee.

---

## 39. Renderer Compatibility

| Feature | Plain Markdown reader | GitHub-style host | Controlled docs site |
| --- | --- | --- | --- |
| Text, tables, fenced code | Text remains useful | Supported with GFM tables | Supported |
| Relative links/images | Host-dependent | Supported when assets exist | Supported |
| `<details>` | May display markup | Usually supported | Supported |
| SVG, video | Link/text fallback | Sanitized or restricted | Policy-dependent |
| CSS and JavaScript | Not needed | Often removed | Optional, trusted only |
| Mathematics | Source remains readable | Host extension | Math renderer needed |

The shared contract and language examples remain understandable without rich
rendering. No renderer is instructed to enable untrusted scripts. Internal table
of contents links follow ordinary GitHub heading anchors.

---

## 40. Suggested Repository Layout

A minimal repository can place this guide at `docs/TIGER_STYLE_PYTHON.md`,
production code in its language-appropriate source directory, and boundary tests
alongside that code. Keep development-tool configuration, dependency pins, and
CI checks under version control. Optional real media belongs in `docs/assets/`.

In this downloadable collection, the guide is at the archive root and its
reference source is `examples/bounded_sum.py`. Relative links work when the archive is extracted
as a whole. No image/video files are required. Treat the example as a teaching
module and adapt its file/package layout before adding it to a production repo.

Keep generated binaries, caches, virtual environments, credentials, and test
scratch directories out of version control. Record tool versions in CI logs,
with environment values redacted.

---

## 41. Sources

The supplied **TIGER_STYLE_LUA(8).md**, version 1.0, supplies the document
structure and engineering priorities. Its language-specific rules are adapted,
not mechanically renamed. Primary conceptual source:
[TigerBeetle Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md).

Language/tool references (reviewed 2026-09-23; use documentation matching your
pinned version):

- **[P1]** [Python 3.14 free-threading documentation](https://docs.python.org/3.14/howto/free-threading-python.html)
- **[P2]** [Python assert statement](https://docs.python.org/3.14/reference/simple_stmts.html#the-assert-statement)
- **[P3]** [Python security considerations](https://docs.python.org/3.14/library/security_warnings.html)
- **[P4]** [Python subprocess ownership and timeouts](https://docs.python.org/3.14/library/subprocess.html)
- **[P5]** [Python tasks, groups, and cancellation](https://docs.python.org/3.14/library/asyncio-task.html)
- **[P6]** [Python data model](https://docs.python.org/3.14/reference/datamodel.html)

The numeric limits, naming choices, function-size review threshold, and example
API are this guide's policy choices, not claims that the language specification
mandates them. Toolchain validation scope is recorded in [VALIDATION.md](VALIDATION.md).

---

# Compact Tiger Style Python Card

<details>
<summary><strong>Open the condensed rules</strong></summary>

**Safety:** validate at trust boundaries; distinguish absence and failure; bound
work and storage; expose units; make ownership explicit; preserve invariants
through errors and cancellation; keep privileged operations narrow.

**Performance:** model capacities first; batch expensive work; profile realistic
loads; account for allocation and retention; keep hot paths simple and defined.

**Developer experience:** follow Python's conventions and one pinned formatter;
keep contracts visible; use precise types without confusing them with runtime
validation; test boundaries and cleanup; document justified exceptions.

</details>

**Final rule:** a reviewer should be able to identify the program's limits,
invariants, state transitions, resource owners, failure behavior, and external
capabilities without reverse-engineering hidden conventions.
