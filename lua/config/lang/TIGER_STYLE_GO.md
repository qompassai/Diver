<!-- TIGER_STYLE_GO.md — Independent language adaptation; no active scripts. -->
# Tiger Style for Go

> **Safety first. Performance second. Developer experience third.**

**Guide version:** 1.0  
**Primary target:** Go 1.24+; module and toolchain versions recorded explicitly  
**Line-width review target:** 100 columns, subject to the language formatter  
**Ordinary function review threshold:** 70 physical source lines  
**Platform emphasis:** Arch Linux; portable core with explicit OS adapters

This guide follows the structure of your Lua guide while adapting contracts,
errors, numbers, ownership, concurrency, tooling, and examples to Go.
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

Declare the module's Go version, toolchain selection policy, GOOS/GOARCH, and
whether cgo is required. Go 1.24 is this guide's minimum for traversal-resistant
`os.Root` APIs; the reference algorithm itself needs no new OS APIs. A module's
language version and a selected compiler version are related but distinct.
Do not assume 64-bit `int`, goroutine scheduling order, or that cross-compilation
means the result has been tested on the target. [G1, G2]

---

## 3. File and Module Layout

Keep packages cohesive and importable without starting background work. Use
`cmd/<program>` for an executable and `internal/` for implementation boundaries.
Group constants, types, constructors/validators, operations, and tests clearly.
Avoid `init()` for network connections, hidden goroutines, or implicit global
configuration. Prefer explicit construction with dependencies passed in.

---

## 4. Assertions, Preconditions, and Postconditions

Go has no built-in assertion statement. Use tests and explicit invariant checks;
reserve `panic` for broken programmer contracts or irrecoverable internal state.
Return an `error` for invalid requests, timeout, missing files, and exhaustion.
Do not use `recover` to pretend a partially completed operation succeeded.
Compile-time interface checks are useful, but do not validate external data.

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

Use short error branches and the idiomatic early `return`. Keep switch cases
explicit and validate unknown enum-like values: a named integer type can still
hold other integers. Do not start a goroutine inside every iteration without
bounded admission. Prefer an iterative parser for deep external structures and
make all recursion budgets explicit.

---

## 7. Error Handling

Return `(value, error)` consistently; wrap with `%w` when callers should inspect
a cause using `errors.Is` or `errors.As`. Do not compare human-readable messages.
Document partial results and whether they are usable on error. Handle `Close`
errors where writes or protocol completion can fail. A typed nil pointer stored
in an `error` interface is not a nil interface. [G1]

Avoid logging and returning the same error at every layer; choose a reporting
owner and keep secrets out of wrapped context.

---

## 8. Absence, False, and Defaults

Document zero-value behavior. A nil slice, an empty slice, a nil map, and a
missing key are distinct in relevant operations and encoders. A nil map can be
read but cannot be assigned into. Use comma-ok lookup to distinguish absence
from a present zero value. Use `*bool` or an explicit optional type when omitted
and false need different meanings. A nil channel blocks send/receive forever;
use that behavior only deliberately.

---

## 9. Numbers, Counts, and Units

Use `time.Duration` for durations and explicit units at serialization boundaries.
Use fixed-width integers for wire fields, and `int` where an API requires lengths.
Go arithmetic does not automatically return overflow errors. Check arithmetic
before allocation or conversion; a cast is not validation. Prefer subtraction
against remaining capacity over a potentially overflowing sum. Validate JSON
number conversion rather than accepting an accidental `float64` approximation.

---

## 10. Collections and Data Shapes

Slices share backing arrays; passing a slice does not copy its elements. `append`
may reuse or replace that storage, so document aliasing and ownership. Maps need
synchronization for concurrent mutation/access. Bound both capacity and element
payloads. Prefer typed structs over `map[string]any` for known schemas, while
still validating decoded fields and rejecting unsupported variants.

---

## 11. State and Mutation

Confine state to one goroutine or protect it with a mutex/atomic protocol.
Sending a pointer through a channel does not automatically transfer exclusive
ownership; define who may mutate it after send. Commit derived results only if
the request generation is still current. Keep configuration immutable after
construction, or synchronize replacement of a complete configuration snapshot.

---

## 12. Function Design

Pass `context.Context` as the first parameter when an operation participates in
cancellation/deadlines; do not store request contexts in long-lived structs.
Take the narrowest useful interface at the consumer boundary. Avoid interfaces
whose only purpose is to mirror a concrete type's every method. Use an options
struct for complex construction and make zero values deliberate.

---

## 13. Scope

Keep variables near their use, and watch `:=` shadowing of an outer `err` or
resource. Language-version changes to loop variables do not fix aliasing of
pointers to shared objects. Pass captured task data explicitly where it clarifies
ownership. Keep locks scoped tightly and avoid invoking unknown callbacks while
holding a lock.

---

## 14. Resource Lifetime

After checking acquisition succeeded, register cleanup with `defer`. A defer
inside a large loop runs at function return, not each iteration; use a small
per-item function or explicit close. Do not copy a value containing a used mutex.
An owner must close owned channels once; receivers should not close a producer's
channel. `os.Exit` skips deferred cleanup, so return to the outer entry point
when cleanup is required.

---

## 15. Memory and Allocation

Garbage collection does not bound queues or prevent goroutine leaks. Cap worker
counts, channels, maps, response bodies, and buffer pools. A small subslice can
retain a large backing allocation; clone a small retained result when justified.
`sync.Pool` is a reuse optimization, not durable storage or a capacity guarantee.
Check requested sizes before `make` and avoid retaining full request objects.

---

## 16. Performance

Profile with benchmarks, `pprof`, and allocation counts. Measure contention,
queueing, and tail latency before rewriting a loop. Reuse buffers only when
ownership and reset semantics are explicit. Avoid unbounded `io.ReadAll`; a
limited reader plus a maximum-plus-one check can distinguish accepted input
from truncation. Transport decompression needs its own expanded-byte budget.

---

## 17. Determinism

Map iteration order is not specified. Sort keys before canonical output instead
of treating a particular encoder's current behavior as a universal rule. Inject
clock and randomness interfaces for deterministic tests. Do not rely on goroutine
completion order; assign sequence numbers or collect into stable indices.
Use cryptographic randomness for security-sensitive values.

---

## 18. Security

Treat cgo, `unsafe`, reflection that bypasses intended contracts, plugins,
external executables, and build directives as trust boundaries. Avoid publishing
pprof/debug endpoints on an untrusted interface. Limit HTTP headers/bodies, set
server/client timeouts, verify TLS normally, and protect against SSRF when URLs
are supplied by callers. The race detector finds exercised races; it is not a
proof that the program is race-free.

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
On Go 1.24+, consider `os.OpenRoot` and its supported descriptor-relative methods
for traversal-resistant access. `os.DirFS` alone does not confine symlink targets.
`os.Root` still does not sandbox device files, `/proc`, or mount boundaries;
choose an appropriate trusted root and file-type policy. Check the exact methods
available in your selected Go version. [G2]

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
Use `exec.CommandContext` with separate arguments. A context's default process
cancellation is not a guarantee that descendants are killed or that pipe copying
finishes immediately. Review `Cmd.Cancel` and `WaitDelay` for the chosen contract.
Use a bounded writer instead of unlimited `Output`/`CombinedOutput` on hostile
output, and always finish the command lifecycle with `Wait`. [G3]

---

## 21. Concurrency and Async Work

Contexts signal cancellation; they do not forcibly terminate arbitrary goroutines.
Every worker needs a shutdown path and an owner that waits for completion.
Bound work before launching goroutines, not only after they have started.
Pair channel operations with cancellation where a peer can disappear, and close
channels according to the sender-ownership rule.

Use mutexes, channels, or well-defined atomics to establish happens-before
relationships. A data race on a slice/interface header can be particularly
serious; do not dismiss it because Go is garbage-collected. [G4]

---

## 22. Naming

Follow Go conventions: `MixedCaps`, short package names, and no underscores in
ordinary identifiers. Exported identifiers start uppercase. Use `requestCount`
and `payloadSizeBytes`; represent duration units in `time.Duration` internally.
Use standard initialisms consistently, such as `HTTPClient` and `userID`.
Short receiver names are idiomatic when their meaning stays obvious.

---

## 23. Formatting

`gofmt` is authoritative, including its tabs. Do not force four spaces or a hard
100-column wrap onto Go output. Keep conceptual lines readable through function
and expression design. Use one reviewed import organizer if needed; formatting
must not unexpectedly rewrite APIs. Keep generated files distinguishable and
regenerate them from reviewed sources instead of hand-editing them.

---

## 24. Comments and Documentation

Write Go doc comments on exported symbols. State cancellation, concurrency,
ownership, and zero-value guarantees. Document who closes channels and resources.
Examples should show checked errors and cleanup. Do not use a comment to promise
thread safety that depends on callers guessing an unstated lock discipline.

---

## 25. Dependencies

Commit `go.mod` and `go.sum`; review replacements and toolchain directives.
Checksums verify resolved content, not suitability. Set proxy/private-module
policy intentionally to avoid leaking private module paths. Pin development
tools and audit `go generate` commands, which can execute arbitrary tools.
Review cgo dependencies and their native ABI separately from Go modules.

---

## 26. Language-Specific Engineering

A Go review should explicitly inspect slice aliasing, interface nils, channel
ownership, goroutine shutdown, error wrapping, and lock copying. Favor a small
bounded worker model over an elaborate concurrency abstraction. A function
returning on context cancellation may still owe cleanup; define when the caller
can safely release buffers used by the operation.

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
go version
gofmt -w examples/bounded_sum.go
GOTOOLCHAIN=local go run examples/bounded_sum.go
# In a reviewed module:
go vet ./...
go test ./...
go test -race ./...
go test -bench=. -benchmem ./...
```

Use `GOTOOLCHAIN=local` when CI must fail rather than automatically obtain a
new compiler. Race builds require a supported platform/toolchain configuration.

---

## 28. Testing

Use table-driven boundary tests and Go fuzz targets for parsers. Test malformed
input, cancellation before and during work, full queues, closed channels, blocked
peers, partial I/O, and shutdown joins. Run race tests on exercised concurrent
paths. Do not depend on sleeps for deterministic ordering: use synchronization
or a controlled clock. Keep fuzz input size bounded before expensive decoding.

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
| Goroutine per unbounded input item | Bounded workers and admission. |
| Defer thousands of closes in one loop | Per-iteration ownership. |
| A typed nil `error` value | An actual nil interface on success. |
| Shared map writes without synchronization | One owner or a locking protocol. |
| `panic` for malformed external data | A meaningful error return. |
| `os.DirFS` called a filesystem sandbox | A stated root and OS access policy. |

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

Complete source: [examples/bounded_sum.go](examples/bounded_sum.go). Run instructions and actual validation
results are in the collection README and VALIDATION.md. This is a deliberately
small reference for arithmetic/contracts, not a claim to implement the file,
process, or async policies described elsewhere.

```go
package main

import (
	"errors"
	"fmt"
)

const itemCountMax = 1024
const totalMax int64 = 1_000_000

var (
	errTooManyItems  = errors.New("item count exceeds limit")
	errInvalidItem   = errors.New("expected a nonnegative integer")
	errTotalExceeded = errors.New("total exceeds limit")
)

// boundedSum borrows input, which must not be mutated concurrently.
// It allocates no result buffer and returns no partial result on failure.
func boundedSum(input []int64) (int64, error) {
	if len(input) > itemCountMax {
		return 0, errTooManyItems
	}
	var total int64
	for _, value := range input {
		if value < 0 {
			return 0, errInvalidItem
		}
		if value > totalMax-total {
			return 0, errTotalExceeded
		}
		total += value
	}
	return total, nil
}

func main() {
	cases := []struct {
		input []int64
		want  int64
		err   error
	}{
		{nil, 0, nil},
		{[]int64{1}, 1, nil},
		{[]int64{999_999, 1}, totalMax, nil},
		{make([]int64, itemCountMax), 0, nil},
		{make([]int64, itemCountMax+1), 0, errTooManyItems},
		{[]int64{-1}, 0, errInvalidItem},
		{[]int64{1_000_001}, 0, errTotalExceeded},
		{[]int64{totalMax, 1}, 0, errTotalExceeded},
		{[]int64{1<<63 - 1}, 0, errTotalExceeded},
	}
	for i, tc := range cases {
		got, err := boundedSum(tc.input)
		if got != tc.want || !errors.Is(err, tc.err) {
			panic(fmt.Sprintf("case %d: got (%d, %v)", i, got, err))
		}
	}
	fmt.Printf("Go: %d cases passed\n", len(cases))
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

A minimal repository can place this guide at `docs/TIGER_STYLE_GO.md`,
production code in its language-appropriate source directory, and boundary tests
alongside that code. Keep development-tool configuration, dependency pins, and
CI checks under version control. Optional real media belongs in `docs/assets/`.

In this downloadable collection, the guide is at the archive root and its
reference source is `examples/bounded_sum.go`. Relative links work when the archive is extracted
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

- **[G1]** [Go specification](https://go.dev/ref/spec)
- **[G2]** [Go traversal-resistant file APIs](https://go.dev/blog/osroot)
- **[G3]** [Go os/exec package](https://pkg.go.dev/os/exec)
- **[G4]** [Go memory model](https://go.dev/ref/mem)
- **[G5]** [Go module reference](https://go.dev/ref/mod)
- **[G6]** [Effective Go and formatting](https://go.dev/doc/effective_go)

The numeric limits, naming choices, function-size review threshold, and example
API are this guide's policy choices, not claims that the language specification
mandates them. Toolchain validation scope is recorded in [VALIDATION.md](VALIDATION.md).

---

# Compact Tiger Style Go Card

<details>
<summary><strong>Open the condensed rules</strong></summary>

**Safety:** validate at trust boundaries; distinguish absence and failure; bound
work and storage; expose units; make ownership explicit; preserve invariants
through errors and cancellation; keep privileged operations narrow.

**Performance:** model capacities first; batch expensive work; profile realistic
loads; account for allocation and retention; keep hot paths simple and defined.

**Developer experience:** follow Go's conventions and one pinned formatter;
keep contracts visible; use precise types without confusing them with runtime
validation; test boundaries and cleanup; document justified exceptions.

</details>

**Final rule:** a reviewer should be able to identify the program's limits,
invariants, state transitions, resource owners, failure behavior, and external
capabilities without reverse-engineering hidden conventions.
