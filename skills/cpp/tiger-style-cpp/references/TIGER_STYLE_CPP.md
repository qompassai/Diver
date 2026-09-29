<!-- TIGER_STYLE_CPP.md — Independent language adaptation; no active scripts. -->
# Tiger Style for C++

> **Safety first. Performance second. Developer experience third.**

**Guide version:** 1.0  
**Primary target:** C++23 reference profile; C++20 projects need an explicit expected alternative  
**Line-width review target:** 100 columns, subject to the language formatter  
**Ordinary function review threshold:** 70 physical source lines  
**Platform emphasis:** Arch Linux; portable core with explicit OS adapters

This guide follows the structure of your Lua guide while adapting contracts,
errors, numbers, ownership, concurrency, tooling, and examples to C++.
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

Declare language standard, compiler, standard library, ABI, exception policy,
and target platform. This guide's reference uses C++23 `std::expected`; a C++20
project must select a reviewed alternative result type rather than assuming that
header exists. Do not describe C++26 proposals/features as C++23 guarantees.
Compiler support and standard-library support are separate checks. Keep C/POSIX
adapters and compiler extensions visibly isolated.

---

## 3. File and Module Layout

Use small namespaces and self-contained public headers with narrow exports.
Place domain types and contracts before private implementation helpers. Avoid
surprising global initialization and destruction dependencies. Headers should
not import broad namespaces into their consumers. Modules may be useful, but
must match the project's actual compiler/build support instead of being assumed.

---

## 4. Assertions, Preconditions, and Postconditions

Use `static_assert` for compile-time constraints and `assert` for internal
invariants, understanding that `NDEBUG` can remove the latter. Validate external
input explicitly in every configuration. Avoid side effects inside assertions.
A C++23 `std::span` describes a borrowed range; indexing is not a universal checked
access guarantee. Prove indices before access rather than treating a view type
as runtime bounds enforcement.

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

Use exhaustive handling of valid domain alternatives through enums/variants.
Keep parser loops bounded and avoid recursive ownership graphs without a depth
policy. Prefer named steps to dense template/algorithm expressions when the
failure or allocation order matters. A range pipeline can borrow dangling data
or defer work; review the lifetime and evaluation contract of each stage.

---

## 7. Error Handling

Choose an exception policy and typed expected-error policy per subsystem.
`std::expected<T, E>` can represent routine domain failure, but does not make the
operations used to produce it nonthrowing. Check state before accessing its value
or error. [X1] Document exception guarantees: unchanged state, valid but changed
state, or explicit partial effects. Never allow an exception to cross a C ABI
boundary; translate it at the boundary.

---

## 8. Absence, False, and Defaults

Use `std::optional` for absence, `std::expected` for failure, and variants for
multiple meaningful states. Do not use a null pointer or magic integer to carry
several unrelated meanings. A moved-from object is valid but its value is
specified only by that type's contract; do not assume every moved-from object is
empty. `operator[]` on a map can insert a default value; use `find` when merely
checking presence.

---

## 9. Numbers, Counts, and Units

Use exact domain types and `std::chrono` durations. Signed integer overflow is
undefined behavior; unsigned wrapping is not automatically a safe capacity policy.
Check before conversion and before arithmetic. Avoid narrowing through C-style
casts, and do not silently convert a negative count to `size_t`. Use checked
remaining-capacity arithmetic for sizes. Validate finite floating-point values
and define whether exact decimal or integer arithmetic is required.

---

## 10. Collections and Data Shapes

Prefer standard containers and explicit views with documented ownership.
`std::string_view` and `std::span` borrow; they do not extend lifetime. Know the
invalidation rules for container growth, erase, moves, and rehashing. Use `at`
where exception-based checked access fits, or explicitly guard indices.
Avoid `vector<bool>` when ordinary element-reference semantics matter. Bound
both element count and the bytes owned by each element.

---

## 11. State and Mutation

Keep state transitions local and publish complete valid objects. Prefer value
semantics where the copy/move costs and invariants are clear. `const` access does
not establish deep immutability or prevent races through other aliases. For
multi-step mutation, use a temporary plus commit/swap when that actually provides
the promised guarantee, including allocator and swap exception behavior.

---

## 12. Function Design

Use narrow interfaces, explicit result types, and domain options instead of
boolean flag lists. Accept views for borrowed input only when the caller's
lifetime obligation is clear. Do not return references to temporaries or local
variables. Constrain templates where it documents a real requirement; avoid
metaprogramming that makes basic control flow or error ownership opaque.

---

## 13. Scope

Keep locks, views, and temporary owners in the smallest useful scope. A lambda
capturing `this` does not keep the object alive. Avoid reference captures when
work can escape the call. Shared ownership is a specific design decision, not a
blanket fix for lifetime errors; define whether callbacks hold a strong owner,
a weak observer, or a joined lexical task.

---

## 14. Resource Lifetime

Use RAII and the Rule of Zero where possible. Prefer `unique_ptr` for exclusive
heap ownership; use `shared_ptr` only for genuine shared ownership and break
cycles deliberately. Destructors must not let exceptions escape. A file or
transaction whose completion can fail needs an explicit checked finish/commit
operation before nonthrowing cleanup. RAII preserves lifetime; it does not
necessarily report write durability or transactional success. [X2]

---

## 15. Memory and Allocation

Bound container growth and allocation size before `reserve`, resize, or parsing.
`reserve` does not initialize elements or change size. Treat `bad_alloc` according
to the application's declared policy. `std::pmr` can expose allocator control,
but every value must outlive neither its memory resource nor its backing storage.
An arena reduces individual frees while potentially retaining all transient
allocations. Avoid manual `new`/`delete` in ordinary application ownership.

---

## 16. Performance

Measure before selecting custom allocators, small-buffer optimizations, move
tricks, or lock-free containers. Account for cache locality, allocation, copies,
I/O, and tail latency. Do not replace defined behavior with aliasing or lifetime
UB to win a benchmark. `std::move` is a cast enabling move semantics, not proof
that a cheap move occurs. Keep numerical optimization flags within the declared
floating-point contract.

---

## 17. Determinism

Do not serialize raw object representation: padding, vptrs, pointer values,
ABI, and endianness are not a portable format. Unordered container iteration
must not define canonical output. Inject clocks/randomness in tests and define
locale/text encodings. Use a reviewed cryptographic random source for secrets;
`std::random_device` has implementation-dependent properties, so audit the
security requirement rather than inferring it from the name.

---

## 18. Security

Review reinterpretation, C-style casts, raw pointers, FFI, format strings,
serialization, dynamic loading, and build plugins as trust boundaries. Prefer
standard/library facilities with explicit bounds. Avoid constructing views from
invalid pointer/length pairs. Use compiler warnings, sanitizers, and static
analysis together; none makes a hostile plugin safe inside your process.

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
`std::filesystem` is useful for paths and ordinary filesystem operations, but
is not by itself a race-resistant confinement API. Use error-code overloads or
exceptions according to a consistent policy. For a hostile-directory boundary,
use a narrow reviewed POSIX/Linux adapter with descriptor-relative resolution.
Do not promise transactional replacement merely because a high-level rename
succeeded; define metadata and durability requirements.

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
C++23 has no standard general-purpose child-process API. On Arch use a reviewed
POSIX adapter around `posix_spawn`/`execve`, or a justified process library.
RAII wrappers should own descriptors and reap children, while explicit operations
report launch/wait/termination failures. Avoid `std::system` for external inputs,
and do not confuse a C++ string builder with safe shell quoting.

---

## 21. Concurrency and Async Work

Prefer owned threads such as `std::jthread` when its lifecycle fits, with an
explicit stop-token protocol. Stop requests are cooperative; a destructor join
can block forever if the task ignores stopping or waits on uninterruptible I/O.
Keep task count and queue size bounded and design wakeup/join behavior first.
Data races are undefined behavior; `volatile` does not synchronize.

Do not confuse `std::async` futures or coroutines with a structured cancellation
runtime. A coroutine frame can outlive referenced objects and needs a clear owner.

---

## 22. Naming

Use one project convention consistently; this profile uses `snake_case` for
functions/variables, `PascalCase` for domain types, and descriptive constants.
Preserve standard-library spelling when naming interoperable concepts. Avoid
implementation-reserved identifiers, unnecessary abbreviations, and prefixes
that hide ownership semantics. Use `payload_size_bytes` and chrono duration
types to expose units.

---

## 23. Formatting

Use a pinned clang-format style with four spaces and a 100-column target.
Let formatting express existing structure; do not combine unrelated statements
to reduce line count. Keep includes organized and public headers self-contained.

```yaml
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
UseTab: Never
```

Run semantic rewrites separately from formatting so reviewers can see behavior
changes. Generated and vendored files need an explicit formatting policy.

---

## 24. Comments and Documentation

Document view lifetimes, ownership transfer, thread safety, invalidation,
exception guarantees, and complexity/resource bounds. A `noexcept` annotation
must be justified across all called operations; termination on a missed throw is
observable behavior. Comments should explain why a cast or manual lifetime step
is valid. Make examples compile in the declared language/library profile.

---

## 25. Dependencies

Pin dependencies and review CMake, Meson, compiler, generator, and package-manager
hooks as executable code. Avoid automatic network fetching during a reproducible
build unless explicitly designed and integrity-checked. Review ABI boundaries,
standard library selection, exception/RTTI compatibility, and native transitive
dependencies. Use established libraries for subtle parsers and cryptography.

---

## 26. Language-Specific Engineering

Make ownership visible in types without pretending types prove all lifetime
relationships. Inspect borrowed views, iterator invalidation, captured references,
move behavior, exception safety, and allocator-resource lifetime. Prefer Rule of
Zero designs and small ADTs over inheritance used only for code reuse. Keep
experimental language features out of the baseline until toolchain and library
support are pinned and tested.

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
c++ --version
mkdir -p build
c++ -std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow \
  -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer \
  examples/bounded_sum.cpp -o build/bounded-sum-cpp
./build/bounded-sum-cpp
c++ -std=c++23 -Wall -Wextra -Wpedantic -O2 -DNDEBUG \
  examples/bounded_sum.cpp -o build/bounded-sum-cpp-release
./build/bounded-sum-cpp-release
```

Use a separate supported ThreadSanitizer build for concurrency. Respect Arch's
reviewed packaging hardening policy without assuming flags transfer unchanged
between GCC and Clang or between standard libraries.

---

## 28. Testing

Test expected-error alternatives, empty and maximum views, invalid lifetime
scenarios through sanitizers, allocation/constructor failure, output preservation,
and exception guarantees. Test move and iterator invalidation assumptions where
used. Exercise cancellation and destructor joins with controlled dependencies.
Run release tests with `NDEBUG` and keep test checks active independently of
`assert`. Sanitizers and fuzzing supplement ownership review; they do not replace it.

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
| Escaping `string_view` into a destroyed string | An owned string or a proven borrow. |
| Shared ownership everywhere | One explicit owner when possible. |
| `reserve(n)` followed by indexing past size | Construct/resize valid elements first. |
| Throwing destructor or unchecked flush | Explicit fallible finish, nonthrowing cleanup. |
| `jthread` assumed to forcibly cancel work | A cooperative stop and wakeup protocol. |
| Casts used to bypass a domain invariant | A checked constructor/conversion. |

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

Complete source: [examples/bounded_sum.cpp](examples/bounded_sum.cpp). Run instructions and actual validation
results are in the collection README and VALIDATION.md. This is a deliberately
small reference for arithmetic/contracts, not a claim to implement the file,
process, or async policies described elsewhere.

```cpp
#include <array>
#include <cstdint>
#include <expected>
#include <iostream>
#include <limits>
#include <span>

constexpr std::size_t item_count_max = 1024;
constexpr std::int64_t total_max = 1'000'000;
enum class SumError { too_many_items, invalid_item, total_exceeded };

// Borrows a valid live span for this call. No allocation, mutation, or retention.
[[nodiscard]] std::expected<std::int64_t, SumError>
bounded_sum(std::span<const std::int64_t> input) {
    if (input.size() > item_count_max) return std::unexpected(SumError::too_many_items);
    std::int64_t total = 0;
    for (const auto value : input) {
        if (value < 0) return std::unexpected(SumError::invalid_item);
        if (value > total_max - total) return std::unexpected(SumError::total_exceeded);
        total += value;
    }
    return total;
}

int main() {
    const std::array<std::int64_t, 1> one{1};
    const std::array<std::int64_t, 2> exact{999'999, 1};
    const std::array<std::int64_t, 1> negative{-1};
    const std::array<std::int64_t, 1> large{1'000'001};
    const std::array<std::int64_t, 2> overflow{total_max, 1};
    const std::array<std::int64_t, 1> huge{std::numeric_limits<std::int64_t>::max()};
    const std::array<std::int64_t, item_count_max> zeros{};
    const std::array<std::int64_t, item_count_max + 1> too_many{};
    struct Case {
        std::span<const std::int64_t> input;
        std::expected<std::int64_t, SumError> expected;
    };
    const std::array<Case, 9> cases{{
        {{}, 0},
        {one, 1},
        {exact, total_max},
        {zeros, 0},
        {too_many, std::unexpected(SumError::too_many_items)},
        {negative, std::unexpected(SumError::invalid_item)},
        {large, std::unexpected(SumError::total_exceeded)},
        {overflow, std::unexpected(SumError::total_exceeded)},
        {huge, std::unexpected(SumError::total_exceeded)},
    }};
    for (const auto& item : cases) {
        if (bounded_sum(item.input) != item.expected) return 1;
    }
    std::cout << "C++: " << cases.size() << " cases passed\n";
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

A minimal repository can place this guide at `docs/TIGER_STYLE_CPP.md`,
production code in its language-appropriate source directory, and boundary tests
alongside that code. Keep development-tool configuration, dependency pins, and
CI checks under version control. Optional real media belongs in `docs/assets/`.

In this downloadable collection, the guide is at the archive root and its
reference source is `examples/bounded_sum.cpp`. Relative links work when the archive is extracted
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

- **[X1]** [C++ draft expected specification](https://eel.is/c++draft/expected)
- **[X2]** [C++ Core Guidelines: resource and ownership guidance](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- **[X3]** [C++ draft span specification](https://eel.is/c++draft/views.span)
- **[X4]** [C++ draft stop tokens and jthread](https://eel.is/c++draft/thread)
- **[X5]** [Clang AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html)
- **[X6]** [GCC instrumentation and hardening](https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html)

The numeric limits, naming choices, function-size review threshold, and example
API are this guide's policy choices, not claims that the language specification
mandates them. Toolchain validation scope is recorded in [VALIDATION.md](VALIDATION.md).

---

# Compact Tiger Style C++ Card

<details>
<summary><strong>Open the condensed rules</strong></summary>

**Safety:** validate at trust boundaries; distinguish absence and failure; bound
work and storage; expose units; make ownership explicit; preserve invariants
through errors and cancellation; keep privileged operations narrow.

**Performance:** model capacities first; batch expensive work; profile realistic
loads; account for allocation and retention; keep hot paths simple and defined.

**Developer experience:** follow C++'s conventions and one pinned formatter;
keep contracts visible; use precise types without confusing them with runtime
validation; test boundaries and cleanup; document justified exceptions.

</details>

**Final rule:** a reviewer should be able to identify the program's limits,
invariants, state transitions, resource owners, failure behavior, and external
capabilities without reverse-engineering hidden conventions.
