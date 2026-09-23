<!-- TIGER_STYLE_ZIG.md — Independent language adaptation; no active scripts. -->
# Tiger Style for Zig

> **Safety first. Performance second. Developer experience third.**

**Guide version:** 1.0  
**Primary target:** Zig 0.16.0; version-sensitive I/O and build APIs must match that toolchain  
**Line-width review target:** 100 columns, subject to the language formatter  
**Ordinary function review threshold:** 70 physical source lines  
**Platform emphasis:** Arch Linux; portable core with explicit OS adapters

This guide follows the structure of your Lua guide while adapting contracts,
errors, numbers, ownership, concurrency, tooling, and examples to Zig.
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

Pin the compiler, target triple, libc choice, and optimization mode. This guide
uses the **0.16.0** language and its I/O architecture; it does not present older
`std.fs` or child-process snippets as portable across releases. Review release
notes before moving the pin. The reference module is pure computation.

`Debug` and `ReleaseSafe` retain runtime safety checks; `ReleaseFast` and
`ReleaseSmall` do not provide the same protection by default. Require explicit
external-input checks in every mode. Prefer `ReleaseSafe` for safety-sensitive
production work unless a measured, reviewed exception justifies another mode.

---

## 3. File and Module Layout

Order a module as imports, domain constants, public types/error sets, validation,
private leaf work, public orchestration, and tests. Export only the intended API.
Keep `build.zig` and `build.zig.zon` small enough to audit as executable build
configuration. Put platform-specific I/O behind a narrow module, rather than
scattering `builtin.os` branches through domain logic.

---

## 4. Assertions, Preconditions, and Postconditions

Use `std.debug.assert` for internal invariants, and `comptime` checks for
properties the compiler can prove. Assert before dereferencing or narrowing when
the premise is internal; validate external values with ordinary error returns.
`unreachable` is a correctness claim, not a convenient fallback. It may become
unchecked illegal behavior in an unsafe build. Never route malformed packets,
OOM, timeouts, or user configuration to `catch unreachable`. [Z1]

A postcondition should state the ownership of a returned slice as well as its
length. Tests must exercise rejection in optimized builds too.

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

Prefer exhaustive `switch` over a tagged union for domain states. Avoid a broad
`else` that silently hides a new state. Keep loops inside bounded leaf operations;
move policy decisions outside hot loops. Bound recursive parsers with explicit
stacks or depth budgets. Do not increase compile-time branch quotas to conceal
an accidentally exponential metaprogram.

---

## 7. Error Handling

Return a documented error union such as `ValidationError!u64` for expected
rejection. Use `try` to propagate and `catch` to handle a specific recovery policy.
Keep public error sets meaningful; a generic `anyerror` surface loses useful
information. `defer` is unconditional scope cleanup; `errdefer` handles error-exit
cleanup until successful ownership transfer. Do not register both to free the
same allocation. [Z1]

Report cleanup failure without discarding the operation's original cause.

---

## 8. Absence, False, and Defaults

Use `?T` for absence and `E!T` for failure. `!?T` can express a fallible lookup
that may find nothing, but document each outcome. Unwrap optional values with
`if`/`orelse` at boundaries. Use `.?` only after an established invariant. A
zero-valued counter or `false` option remains a value. `undefined` is neither
absence nor a request for safe initialization; every read must follow a write.

---

## 9. Numbers, Counts, and Units

Choose integer widths by domain; use `usize` for addressable collection lengths,
not as an implicit wire format. Before adding an untrusted increment, test it
against remaining capacity. Use `@addWithOverflow`/`@mulWithOverflow` when explicit
overflow reporting is needed; choose wrapping `+%` or saturating `+|` only when
that behavior is the specification. Validate narrowing and float-to-int domains.
Bytes are not UTF-8 code points; encode endianness explicitly in protocols.

---

## 10. Collections and Data Shapes

Prefer slices with lengths over raw many-item pointers at ordinary boundaries.
A slice borrows memory; it does not own or extend its lifetime. Use enums/tagged
unions to prevent incompatible fields from coexisting. Bound both container
capacity and the size of each retained element. For 0.16's unmanaged-container
interfaces, pass the allocator where the API requires it; do not transplant an
older allocator-owning constructor. [Z2]

---

## 11. State and Mutation

Give each mutable object one owner or a documented synchronization protocol.
Compute a proposed change locally and commit after all fallible validation.
Document iterator and pointer invalidation on resize, removal, or arena reset.
`const` access is not proof that no other alias can mutate the allocation.
Do not publish pointers into growable storage before its lifetime is stable.

---

## 12. Function Design

Make allocator, I/O interface, and ownership parameters explicit where required.
Keep pure validation separate from acquisition and side effects. Use an options
struct when several flags describe a policy; avoid a row of positional booleans.
A generic helper earns its place only when its compile-time constraints and
runtime behavior remain clearer than the repeated concrete code.

---

## 13. Scope

Declare `const` by default and `var` only for actual mutation. Keep a borrow in
a smaller scope than its owner. Do not return a pointer to stack storage or store
an arena-backed value beyond the arena's lifetime. Minimize values captured by
concurrent work; transfer stable owned data where a callback can outlive the
calling scope.

---

## 14. Resource Lifetime

Register `defer` immediately after acquisition. Use `errdefer` while constructing
an owned result, then transfer ownership explicitly on success. State which
allocator must free each returned allocation. A resource with a fallible flush
needs an explicit checked finish step; destruction alone may be insufficient.
A repeated teardown operation must either be idempotent or reject the second
call through a documented state check.

---

## 15. Memory and Allocation

Prefer caller-provided buffers or fixed capacities when the maximum is known.
Otherwise accept an allocator, cap allocation sizes, and test allocation failure.
An arena simplifies bulk lifetime but can retain every transient allocation
until reset; it is not a memory bound. Avoid mixing allocators across free/resize.
Check count-times-element-size calculations before requesting bytes. Borrowed
sub-slices can retain a large owner even when the view is small.

---

## 16. Performance

Measure allocation count, cache locality, copies, syscalls, and tail latency.
Do not remove runtime safety because a benchmark merely appears faster. Keep
input validation outside a hot loop only when all its premises remain valid.
Use representative optimized builds and real target CPUs. Cross-compilation
success is not a substitute for running tests on the target architecture.

---

## 17. Determinism

Do not serialize a hash map in its iteration order. Sort externally observable
keys or use a protocol-defined order. Inject clocks and random sources into tests;
cryptographic randomness must come from an approved entropy API, not a test PRNG.
Avoid serializing raw struct memory: layout, padding, endianness, and undefined
bytes are not a stable format.

---

## 18. Security

Treat FFI, pointer casts, integer-to-pointer conversion, dynamic libraries,
build scripts, and external processes as privileged boundaries. Keep casts
localized with alignment, provenance, length, and lifetime justification. Runtime
safety cannot validate arbitrary external C ownership. Use reviewed crypto
primitives rather than hand-written algorithms; do not log secret buffers.

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
In 0.16, use the filesystem operations provided through the pinned `std.Io`
interfaces and retain a trusted directory handle where appropriate. A Zig slice
containing a path is not a capability. Review how the selected backend handles
symlinks, cancellation, and partial writes. [Z2]

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
Use the pinned `std.process`/`std.Io` process interface, with explicit argument
slices. Zig 0.16 changed process and environment APIs substantially; copy the
signature from that version's standard library and test its termination paths.
Never hide a shell in a helper that claims to accept a safe argv list. [Z2]

---

## 21. Concurrency and Async Work

Zig 0.16 introduces I/O as an interface with futures/groups and cancellation;
do not assume the older language-level async examples describe today's standard
library. [Z2] Pass the I/O dependency explicitly and follow its ownership rules.
Bound group size before starting work, cancel and await owned work before freeing
its data, and treat cancellation as a real error path.

For CPU threads, define shared state and synchronization separately. An allocator
safe for concurrent use does not make the objects it allocates thread-safe.

---

## 22. Naming

Follow Zig conventions: `TitleCase` types, `camelCase` functions, and
`snake_case` values/fields. Use domain names such as `payload_size_bytes` and
`timeout_ms`. All-caps constants are not required; a clear `item_count_max` works
with normal Zig style. Keep exported names stable and avoid abbreviations that
hide ownership or measurement units.

---

## 23. Formatting

`zig fmt` owns formatting. Do not replace its four-space layout with a custom
cross-language rule. Aim for readable lines near 100 columns and review cohesive
functions around 70 lines. Use one statement per line in explanatory code. Check
formatting in CI with `zig fmt --check`; never manually fight its stable output.

---

## 24. Comments and Documentation

Use `//!` for module documentation and `///` for public declarations. Document
allocator ownership, borrowed lifetimes, aliasing restrictions, limits, error
sets, and build-mode assumptions. Comments should explain why an unchecked
operation is valid at that point, not merely repeat its syntax. Keep examples
under the compiler version recorded in the repository.

---

## 25. Dependencies

Declare dependencies in the pinned build configuration with integrity metadata
where supported. A hash identifies bytes; it does not make a dependency benign.
Review `build.zig` execution as code with the build user's authority. Prefer
standard-library facilities or small internal code when they meet the contract;
use a mature reviewed dependency when reimplementation would be riskier.

---

## 26. Language-Specific Engineering

Review five Zig-specific boundaries explicitly: allocator identity, borrow
lifetime, build-mode safety, `comptime` resource cost, and C ABI assumptions.
Use `extern` layout only for a declared foreign ABI; packed structures are not a
shortcut for portable packet parsing. Decode fields from bytes deliberately.
Pin the standard library with the compiler, and maintain a migration checklist
for I/O, container, build, and process APIs at each toolchain upgrade.

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
zig version
zig fmt --check examples/bounded_sum.zig
zig test examples/bounded_sum.zig
zig test examples/bounded_sum.zig -O ReleaseSafe
zig test examples/bounded_sum.zig -O ReleaseFast
```

The last command verifies explicit rejection survives disabled safety checks;
it is not an endorsement of an unsafe production configuration.

---

## 28. Testing

Use `std.testing` for boundary cases and `std.testing.allocator` when testing
owned allocations. Add failure-injection tests for each allocation/acquisition
step. Test zero, one, the maximum, maximum plus one, overflow candidates, and
invalid variants. Exercise cancellation and cleanup with an instrumented backend.
The bundled reference uses no allocator; its tests exercise only the declared
bounded arithmetic contract, not filesystem or networking behavior.

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
| `catch unreachable` on user input or OOM | Return the domain or allocation error. |
| A returned stack slice | A caller-owned buffer or explicitly owned allocation. |
| `undefined` used as a default value | Initialize every field before observing it. |
| Hidden global allocator | Explicit allocator ownership. |
| `+%` to silence overflow checks | A documented arithmetic policy. |
| Old process/I/O snippets with a new compiler | Version-matched APIs and tests. |

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

Complete source: [examples/bounded_sum.zig](examples/bounded_sum.zig). Run instructions and actual validation
results are in the collection README and VALIDATION.md. This is a deliberately
small reference for arithmetic/contracts, not a claim to implement the file,
process, or async policies described elsewhere.

```zig
const std = @import("std");

pub const item_count_max: usize = 1024;
pub const total_max: u64 = 1_000_000;
pub const ValidationError = error{ TooManyItems, InvalidItem, TotalExceeded };

/// Borrows input for this call. No allocation, retained reference, or mutation.
pub fn boundedSum(input: []const i64) ValidationError!u64 {
    if (input.len > item_count_max) return error.TooManyItems;
    var total: u64 = 0;
    for (input) |value| {
        if (value < 0) return error.InvalidItem;
        const amount: u64 = @intCast(value);
        if (amount > total_max - total) return error.TotalExceeded;
        total += amount;
    }
    std.debug.assert(total <= total_max);
    return total;
}

test "bounded sum success and capacity edges" {
    try std.testing.expectEqual(@as(u64, 0), try boundedSum(&.{}));
    try std.testing.expectEqual(@as(u64, 1), try boundedSum(&.{1}));
    try std.testing.expectEqual(total_max, try boundedSum(&.{ 999_999, 1 }));
    const at_limit = [_]i64{0} ** item_count_max;
    try std.testing.expectEqual(@as(u64, 0), try boundedSum(&at_limit));
    const over_limit = [_]i64{0} ** (item_count_max + 1);
    try std.testing.expectError(error.TooManyItems, boundedSum(&over_limit));
}

test "invalid and overflowing requests are returned as errors" {
    try std.testing.expectError(error.InvalidItem, boundedSum(&.{-1}));
    try std.testing.expectError(error.TotalExceeded, boundedSum(&.{1_000_001}));
    try std.testing.expectError(error.TotalExceeded, boundedSum(&.{ 1_000_000, 1 }));
    try std.testing.expectError(error.TotalExceeded, boundedSum(&.{std.math.maxInt(i64)}));
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

A minimal repository can place this guide at `docs/TIGER_STYLE_ZIG.md`,
production code in its language-appropriate source directory, and boundary tests
alongside that code. Keep development-tool configuration, dependency pins, and
CI checks under version control. Optional real media belongs in `docs/assets/`.

In this downloadable collection, the guide is at the archive root and its
reference source is `examples/bounded_sum.zig`. Relative links work when the archive is extracted
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

- **[Z1]** [Zig 0.16 language reference](https://ziglang.org/documentation/0.16.0/)
- **[Z2]** [Zig 0.16 release notes and I/O migration](https://ziglang.org/download/0.16.0/release-notes.html)
- **[Z3]** [Zig documentation and standard library entry point](https://ziglang.org/documentation/)

The numeric limits, naming choices, function-size review threshold, and example
API are this guide's policy choices, not claims that the language specification
mandates them. Toolchain validation scope is recorded in [VALIDATION.md](VALIDATION.md).

---

# Compact Tiger Style Zig Card

<details>
<summary><strong>Open the condensed rules</strong></summary>

**Safety:** validate at trust boundaries; distinguish absence and failure; bound
work and storage; expose units; make ownership explicit; preserve invariants
through errors and cancellation; keep privileged operations narrow.

**Performance:** model capacities first; batch expensive work; profile realistic
loads; account for allocation and retention; keep hot paths simple and defined.

**Developer experience:** follow Zig's conventions and one pinned formatter;
keep contracts visible; use precise types without confusing them with runtime
validation; test boundaries and cleanup; document justified exceptions.

</details>

**Final rule:** a reviewer should be able to identify the program's limits,
invariants, state transitions, resource owners, failure behavior, and external
capabilities without reverse-engineering hidden conventions.
