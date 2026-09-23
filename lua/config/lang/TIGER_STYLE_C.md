<!-- TIGER_STYLE_C.md — Independent language adaptation; no active scripts. -->
# Tiger Style for C

> **Safety first. Performance second. Developer experience third.**

**Guide version:** 1.0  
**Primary target:** ISO C17 core; optional C23 features explicitly gated; POSIX/Linux adapters isolated  
**Line-width review target:** 100 columns, subject to the language formatter  
**Ordinary function review threshold:** 70 physical source lines  
**Platform emphasis:** Arch Linux; portable core with explicit OS adapters

This guide follows the structure of your Lua guide while adapting contracts,
errors, numbers, ownership, concurrency, tooling, and examples to C.
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

Declare the C standard, compiler versions, data model, target architecture,
libc, and required POSIX/Linux APIs. This guide's reference uses C17. C23 features
such as checked-arithmetic facilities require a separate compiler/header feature
check; do not assume a compiler flag guarantees complete library support.
Do not assume `int` is 32 bits, `long` matches pointers, plain `char` is signed,
or all-zero bytes represent every type's semantic zero. [C1]

---

## 3. File and Module Layout

Use a small public header for types/contracts and a corresponding implementation
file for private helpers. Make private symbols `static`. Use include guards,
self-contained headers, explicit standard includes, and one clear prefix for
public names. Keep platform adapters separate from pure domain code. Avoid
header definitions that introduce surprising mutable global state.

---

## 4. Assertions, Preconditions, and Postconditions

Use `_Static_assert` for compile-time representation constraints and `assert`
for internal invariants. `NDEBUG` can remove runtime assertions; never put
validation, resource acquisition, or state changes only inside them.
External input must reach explicit checks and status returns in every build.
A non-null pointer check does not prove that the allocation is valid or long
enough; pointer provenance and object lifetime remain caller contracts. [C1]

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

Use straightforward branches, bounded loops, and exhaustive handling of accepted
state values. A cleanup label reached with `goto` can be clearer than duplicated
cleanup or deep nesting; keep labels local and ownership monotonic. Avoid
recursion for attacker-controlled depth and avoid macros that hide control flow
or evaluate arguments more than once.

---

## 7. Error Handling

Return a documented status enum and use output parameters with an explicit
failure policy. Prefer leaving outputs unchanged until success. Capture `errno`
after a failing call before cleanup can replace it; distinguish library status
from OS errno. Handle partial reads/writes, EOF, interruption, and close/flush
errors according to the actual API. Do not retry every `close` after `EINTR`:
on Linux the descriptor may already have been released and reused.

---

## 8. Absence, False, and Defaults

Distinguish a null pointer, an empty valid span, a missing optional value, and
an invalid argument. State whether `(NULL, 0)` is accepted for each API, and do
not call a memory function with a null pointer merely because the count is zero
unless its contract permits it. Zero-initialization is a type-aware language
operation; blindly applying `memset` to a representation is a different claim.

---

## 9. Numbers, Counts, and Units

Use `size_t` for object sizes, fixed-width integers where available for protocol
fields, and correct format macros/specifiers. Check `count <= SIZE_MAX / size`
before multiplying nonzero element sizes. Signed overflow is undefined behavior;
unsigned wrap is defined but rarely the correct size policy. Validate casts,
shift counts, division edge cases, and signed/unsigned comparisons. C23
`<stdckdint.h>` is an optional checked-arithmetic path after feature validation.
Decode endianness explicitly rather than casting packet bytes to structs.

---

## 10. Collections and Data Shapes

Model a sequence as a pointer plus a length and, when mutable growth matters,
a separate capacity. Document overlap and aliasing constraints. A struct does
not enforce its own invariants; use constructors/validators and keep ownership
fields together. Never serialize raw struct bytes as a portable wire format:
padding, alignment, and ABI layout need not match the protocol.

---

## 11. State and Mutation

Choose one owner for each mutable buffer and a small number of commit points.
Validate the full proposed update before exposing it, or define rollback/partial
failure semantics. `const` on one pointer does not prohibit mutation through
another alias. Global state requires explicit initialization, synchronization,
and teardown ownership; avoid hidden state in reusable library functions.

---

## 12. Function Design

Design APIs around explicit buffers, capacities, statuses, and ownership.
Avoid positional flag piles; use a small options struct with a version/size field
only when ABI evolution actually needs it. State whether an output aliases an
input, whether overlap is allowed, and how much storage the caller supplies.
Prefer simple functions over clever macro-based generic frameworks.

---

## 13. Scope

Keep acquired resources and their cleanup flags close together. Avoid shadowing
variables used by a cleanup label. Never return a pointer into automatic storage
or retain a borrowed pointer after its owner can release it. Minimize the region
holding a lock or privileged capability, and avoid unknown callbacks while a
lock protects a partially updated invariant.

---

## 14. Resource Lifetime

Use one cleanup path for a sequence of acquisitions and release in reverse order.
Record ownership immediately after each successful acquisition. Check write and
flush errors before close; closing a stream can also fail. On Linux, do not
blindly retry a failed `close` on a descriptor that may have been released.
Use `O_CLOEXEC`/appropriate spawn file actions to avoid leaking descriptors into
children. A repeated destroy API must document how it detects already-released
state; “free then leave dangling” is not idempotent teardown.

---

## 15. Memory and Allocation

Check every allocation result and overflow-prone size calculation. Keep the old
pointer until `realloc` succeeds; define zero-size allocation behavior rather
than relying on platform quirks. Bound stack allocations; avoid variable-length
arrays for external sizes. A freed pointer is invalid even if its bytes appear
unchanged. Clearing one owner pointer does not invalidate other aliases.

---

## 16. Performance

Measure throughput, allocation, cache misses, syscalls, and tail latency.
`restrict`, alignment assumptions, aliasing optimizations, and unchecked pointer
arithmetic are correctness contracts, not free speed flags. Do not enable
`-ffast-math` when NaN, infinity, signed zero, or precise numerical behavior matters.
Use representative optimized builds, and retain boundary tests in that mode.

---

## 17. Determinism

Do not let uninitialized bytes or struct padding reach hashes, logs, or the wire.
Use an explicit byte encoding and stable order for serialized maps. Fix locale
and encoding assumptions for parsing; use controlled clocks/randomness in tests.
Avoid calling `rand()` a security primitive. Floating-point reproducibility
requires an explicit compiler/platform policy, not just a fixed random seed.

---

## 18. Security

Treat all pointer arithmetic, casts, FFI, format strings, dynamic loading, and
shell/process boundaries as review points. Use a fixed format string for logging
untrusted text. Bounds-check copies; `strncpy` is not a general “safe strcpy.”
For ctype functions, convert a non-EOF byte to `unsigned char` before promotion.
Treat sanitizer findings as real defects until disproved; hardening cannot repair
an invalid lifetime or buffer contract. [C2]

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
Use POSIX descriptor-based APIs in the Linux adapter with checked flags and
modes, avoiding check-then-open authorization. Verify file types with the opened
handle rather than trusting a pathname's prior stat. Define behavior for pipes,
symlinks, devices, and `/proc`; a size from `stat` is not a universal read limit.
Create temporary files with an exclusive primitive, not a guessed predictable name.

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
Use `posix_spawn`/`execve`-family interfaces with trusted executable selection and
explicit argv/environment. Avoid `system` and `popen` for externally influenced
commands. In a multithreaded process, the child between `fork` and `exec` may call
only the operations allowed by that context; do not perform arbitrary allocation
or logging there. Establish descriptor and signal inheritance intentionally.

---

## 21. Concurrency and Async Work

Use a documented pthread/C11-atomic synchronization protocol. `volatile` is not
thread synchronization. Data races are undefined behavior; memory ordering needs
a specific happens-before argument. Prefer locks and a simple bounded work queue
over custom lock-free algorithms unless evidence justifies the complexity.

Signal handlers need an async-signal-safe design; communicate with normal code
through an appropriate minimal mechanism. Define shutdown, wakeup, cancellation,
join, and buffer lifetime before starting workers.

---

## 22. Naming

Use `snake_case` for functions/fields, `UPPER_SNAKE_CASE` for macro constants,
and a consistent public API prefix. Avoid identifiers reserved to the implementation
such as leading underscore-plus-uppercase and double underscores. Use names like
`input_count` and `output_capacity_bytes`. Prefer explicit structs/enums rather
than hiding pointer ownership inside opaque typedef naming tricks.

---

## 23. Formatting

Use a pinned clang-format configuration; four spaces and 100 columns are this
guide's defaults. Keep one statement per line and avoid compressed cleanup logic.
Use braces for multi-step control flow and a consistent policy for short branches.

```yaml
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
UseTab: Never
```

Never reformat vendored code without an ownership/update policy.

---

## 24. Comments and Documentation

Public headers should specify pointer validity, size units, overlap, thread
safety, error outcomes, output mutation, and ownership transfer. Explain why an
unchecked operation is valid, including its proof boundary. Identify whether an
interface is ISO C, POSIX, or Linux-specific. Document ABI constraints separately
from implementation details and keep examples under strict warnings.

---

## 25. Dependencies

Pin source dependencies and verify artifacts. Review configure scripts, Makefile
recipes, compiler wrappers, generated headers, and post-install hooks as executable
code. Avoid downloading dependencies during an ordinary offline build. Choose
reviewed libraries for crypto, parsers, and other subtle domains instead of
reimplementing them to reduce the apparent dependency count.

---

## 26. Language-Specific Engineering

Require explicit reviews for undefined behavior, object lifetime, strict aliasing,
integer promotion, alignment, and the abstract-machine versus hardware model.
Use sanitizers and static analysis as complementary evidence. Test release
builds with assertions disabled. Maintain a narrow, well-specified boundary
between untrusted bytes and valid pointer/length views; C cannot discover an
arbitrary pointer's true allocation length for you.

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
cc --version
mkdir -p build
cc -std=c17 -Wall -Wextra -Wpedantic -Wconversion -Wshadow \
  -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer \
  examples/bounded_sum.c -o build/bounded-sum-c
./build/bounded-sum-c
cc -std=c17 -Wall -Wextra -Wpedantic -O2 -DNDEBUG \
  examples/bounded_sum.c -o build/bounded-sum-c-release
./build/bounded-sum-c-release
```

Run ThreadSanitizer in a separate compatible build for concurrent code. For
packaging, respect reviewed Arch makepkg hardening flags; GCC's `-fhardened` is
version/platform dependent and should not be copied blindly to Clang. [C3]

---

## 28. Testing

Test empty and maximum spans, invalid arguments, output preservation on failure,
allocation failure, short I/O, interrupted syscalls, cleanup, and integer edges.
Fuzz byte parsers behind a size cap. Run ASan/UBSan, targeted static analysis,
and separate race tooling for concurrent code. Sanitizers detect exercised
classes of bugs; they do not prove absence of UB. Tests must not disappear when
`NDEBUG` disables assertions. [C2]

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
| `malloc(count * size)` without a bound | Checked multiplication and a byte cap. |
| `p = realloc(p, n)` without a temporary | Preserve the original allocation on failure. |
| `printf(user_text)` | A fixed format string. |
| `assert` as external validation | An always-executed status path. |
| `volatile` as a lock | Defined synchronization. |
| Struct casts over packet bytes | Explicit checked decoding. |

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

Complete source: [examples/bounded_sum.c](examples/bounded_sum.c). Run instructions and actual validation
results are in the collection README and VALIDATION.md. This is a deliberately
small reference for arithmetic/contracts, not a claim to implement the file,
process, or async policies described elsewhere.

```c
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#define ITEM_COUNT_MAX 1024u
#define TOTAL_MAX INT64_C(1000000)

enum SumStatus {
    SUM_OK,
    SUM_INVALID_INPUT,
    SUM_TOO_MANY_ITEMS,
    SUM_INVALID_ITEM,
    SUM_TOTAL_EXCEEDED
};

/* input must cover count live int64_t objects and remain stable during the call.
 * (NULL, 0) is valid. out must address a writable int64_t object.
 * Non-null pointers cannot be proven valid here. Failure never changes *out.
 */
static enum SumStatus bounded_sum(const int64_t *input, size_t count, int64_t *out) {
    if (out == NULL || (input == NULL && count != 0)) return SUM_INVALID_INPUT;
    if (count > ITEM_COUNT_MAX) return SUM_TOO_MANY_ITEMS;
    int64_t total = 0;
    for (size_t i = 0; i < count; ++i) {
        const int64_t value = input[i];
        if (value < 0) return SUM_INVALID_ITEM;
        if (value > TOTAL_MAX - total) return SUM_TOTAL_EXCEEDED;
        total += value;
    }
    *out = total;
    return SUM_OK;
}

int main(void) {
    const int64_t one[] = {1};
    const int64_t exact[] = {999999, 1};
    const int64_t negative[] = {-1};
    const int64_t large[] = {1000001};
    const int64_t overflow[] = {TOTAL_MAX, 1};
    const int64_t huge[] = {INT64_MAX};
    const int64_t zeros[ITEM_COUNT_MAX + 1u] = {0};
    const struct {
        const int64_t *input;
        size_t count;
        enum SumStatus status;
        int64_t expected;
    } cases[] = {
        {NULL, 0, SUM_OK, 0},
        {one, 1, SUM_OK, 1},
        {exact, 2, SUM_OK, TOTAL_MAX},
        {zeros, ITEM_COUNT_MAX, SUM_OK, 0},
        {zeros, ITEM_COUNT_MAX + 1u, SUM_TOO_MANY_ITEMS, 0},
        {NULL, 1, SUM_INVALID_INPUT, 0},
        {negative, 1, SUM_INVALID_ITEM, 0},
        {large, 1, SUM_TOTAL_EXCEEDED, 0},
        {overflow, 2, SUM_TOTAL_EXCEEDED, 0},
        {huge, 1, SUM_TOTAL_EXCEEDED, 0},
    };
    const size_t case_count = sizeof cases / sizeof cases[0];
    for (size_t i = 0; i < case_count; ++i) {
        int64_t output = -77;
        const enum SumStatus status = bounded_sum(cases[i].input, cases[i].count, &output);
        if (status != cases[i].status) return 1;
        if (status == SUM_OK && output != cases[i].expected) return 2;
        if (status != SUM_OK && output != -77) return 3;
    }
    if (bounded_sum(NULL, 0, NULL) != SUM_INVALID_INPUT) return 4;
    printf("C: %zu cases passed\n", case_count + 1u);
    return 0;
}
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

A minimal repository can place this guide at `docs/TIGER_STYLE_C.md`,
production code in its language-appropriate source directory, and boundary tests
alongside that code. Keep development-tool configuration, dependency pins, and
CI checks under version control. Optional real media belongs in `docs/assets/`.

In this downloadable collection, the guide is at the archive root and its
reference source is `examples/bounded_sum.c`. Relative links work when the archive is extracted
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

- **[C1]** [WG14 public C11 draft, foundational C semantics; C17 profile used here](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf)
- **[C2]** [Clang AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html)
- **[C3]** [GCC instrumentation and hardening options](https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html)
- **[C4]** [Clang UndefinedBehaviorSanitizer](https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html)
- **[C5]** [POSIX specification, process and file interfaces](https://pubs.opengroup.org/onlinepubs/9799919799/)
- **[C6]** [WG14 C23 draft](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n3096.pdf)

The numeric limits, naming choices, function-size review threshold, and example
API are this guide's policy choices, not claims that the language specification
mandates them. Toolchain validation scope is recorded in [VALIDATION.md](VALIDATION.md).

---

# Compact Tiger Style C Card

<details>
<summary><strong>Open the condensed rules</strong></summary>

**Safety:** validate at trust boundaries; distinguish absence and failure; bound
work and storage; expose units; make ownership explicit; preserve invariants
through errors and cancellation; keep privileged operations narrow.

**Performance:** model capacities first; batch expensive work; profile realistic
loads; account for allocation and retention; keep hot paths simple and defined.

**Developer experience:** follow C's conventions and one pinned formatter;
keep contracts visible; use precise types without confusing them with runtime
validation; test boundaries and cleanup; document justified exceptions.

</details>

**Final rule:** a reviewer should be able to identify the program's limits,
invariants, state transitions, resource owners, failure behavior, and external
capabilities without reverse-engineering hidden conventions.
