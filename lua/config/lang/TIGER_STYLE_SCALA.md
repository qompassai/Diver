<!-- TIGER_STYLE_SCALA.md — Independent language adaptation; no active scripts. -->
# Tiger Style for Scala

> **Safety first. Performance second. Developer experience third.**

**Guide version:** 1.0  
**Primary target:** Scala 3.3+ on the JVM; JDK and compiler pinned together  
**Line-width review target:** 100 columns, subject to the language formatter  
**Ordinary function review threshold:** 70 physical source lines  
**Platform emphasis:** Arch Linux; portable core with explicit OS adapters

This guide follows the structure of your Lua guide while adapting contracts,
errors, numbers, ownership, concurrency, tooling, and examples to Scala.
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

Declare Scala, JDK, build-tool, and library versions together. This guide targets
Scala 3 on the JVM; Scala 2, Scala.js, and Scala Native need separate runtime and
FFI assumptions. Avoid describing experimental capture checking, safer exceptions,
or explicit-null settings as universal defaults. Use experimental features only
with an explicit compiler policy and migration tests. JVM garbage collection
does not provide deterministic resource cleanup.

---

## 3. File and Module Layout

Group a small domain's opaque types/enums, validation, pure operations, and
application wiring. Prefer explicit constructor dependencies over hidden global
services. Object initialization should not start threads, call remote services,
or register shutdown-sensitive resources. Keep build definitions and compiler
plugins under the same review policy as application code.

---

## 4. Assertions, Preconditions, and Postconditions

Use `assert` for internal invariants and `require` for programmer-facing
preconditions, with clear ownership of thrown failures. Compiler settings can
elide some assertion-family checks; do not place input validation or side effects
only inside them. Parse external data into a validated domain value using an
explicit `Either` or another documented result. A case-class constructor by
itself does not enforce every field relationship.

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

Use exhaustive pattern matching on enums and sealed hierarchies. Treat a new
case as a review event; a catch-all may conceal it. Prefer direct, named steps to
dense operator chains. Use `@tailrec` when a function must be tail-recursive and
still bound its total work. Collection pipelines must have known input/output
budgets; laziness can defer failure instead of eliminating it.

---

## 7. Error Handling

Use `Either[DomainError, A]` for expected rejection, `Option[A]` for absence,
and `Try` at a boundary where exception-producing code must become a value.
Do not use `.get` on these containers as the ordinary path. Model errors with
an enum/ADT so callers do not parse exception text. Catch `NonFatal` only when
recovery is meaningful, and preserve cause/context without exposing secrets.
Do not catch all `Throwable` and return a success-shaped default. [S1]

---

## 8. Absence, False, and Defaults

Represent optional domain values with `Option`, not sentinel strings or null.
Convert nullable Java values at one boundary with a deliberate policy. `Some(null)`
and `Option(null)` behave differently. Enabling `-Yexplicit-nulls` changes how
nullable reference types are represented; assess Java interoperability and the
selected compiler rather than assuming it is already enabled. [S2]
Distinguish “missing configuration” from a present `false` or zero.

---

## 9. Numbers, Counts, and Units

JVM `Int` and `Long` arithmetic does not throw automatically on overflow. Check
bounds before arithmetic, or use `Math.addExact`/`multiplyExact` when throwing
on overflow is the chosen contract. Bound `BigInt`/`BigDecimal` magnitude and
precision as resources. Use opaque types or small domain wrappers for units;
prefer a finite duration at timeout boundaries. Avoid nan/infinite floating-point
values in an ordered budget domain.

---

## 10. Collections and Data Shapes

Use immutable collections by default, while remembering that immutable
collections can contain mutable objects. Choose `Vector`, `List`, arrays, and
maps by access pattern rather than habit. Repeated indexing or length computation
on linked lists can create avoidable work. Bound collection size before costly
folds and serialization; avoid unbounded `LazyList` materialization.

---

## 11. State and Mutation

Keep pure state transitions separate from external effects. Use an immutable
state value plus one controlled commit point, or explicitly synchronize mutable
state. A `val` makes the binding stable, not the referenced object immutable.
Do not mutate a builder or array concurrently because its containing case class
looks immutable. Define generation checks for asynchronous refreshes.

---

## 12. Function Design

Give public methods explicit result types and use named parameters for policy.
Separate parsing, validation, computation, and effects; retain the compiler's
help through precise ADTs. Keep contextual parameters/givens local and unsurprising.
A reviewer should be able to discover which execution context, clock, logger,
or effect runtime an operation uses without searching the whole repository.

---

## 13. Scope

Constrain mutable builders to a local scope and publish an immutable result.
Do not retain a large request through a closure when only an ID is needed.
Avoid shadowed imports and ambiguous givens. Resource scope must cover all
asynchronous use; exiting a lexical block does not mean a `Future` created there
has completed.

---

## 14. Resource Lifetime

Use `scala.util.Using` for suitable synchronous `AutoCloseable` resources. Do not
return a lazy iterator or a running `Future` that still uses a resource after
`Using` closes it. [S3] With an effect library, use its resource abstraction and
stay within that runtime's cancellation model. Executor ownership must identify
who stops admission, cancels work, awaits termination, and handles failure.

---

## 15. Memory and Allocation

GC manages memory, not file handles, queue size, or executor shutdown. Bound
mailboxes, futures, caches, buffers, and retained exception chains. Avoid repeated
immutable concatenation in measured loops; use a local bounded builder when it
keeps the contract clear. Watch boxing and captured closures without replacing
readable code prematurely. State the maximum size of a single retained value.

---

## 16. Performance

Use JMH for JVM microbenchmarks and JFR/profiling for realistic services. Account
for warmup, JIT compilation, GC, and allocation rate. Measure p95/p99 latency and
contention, not only arithmetic throughput. Do not infer production behavior
from a single cold `System.nanoTime` loop. Keep serialization and I/O budgets
visible before optimizing higher-order collection operations.

---

## 17. Determinism

Sort keys where a stable protocol or snapshot order is required. Immutable hash
maps do not automatically mean canonical serialization. Inject clocks, random
sources, and schedulers at test boundaries. Separate locale-sensitive display
from stable identifiers. For parallel work, collect by explicit sequence rather
than completion order when the output contract is ordered.

---

## 18. Security

Treat reflection, dynamic class loading, Java serialization, macros/compiler
plugins, scripts, and build plugins as privileged code. Avoid deserializing
untrusted Java objects. Parameterize SQL, validate network destinations, and
review XML/parser entity settings when applicable. A type-safe API does not
sanitize an embedded shell, template, SQL, or URL language automatically.

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
Use Java NIO with explicit open options and file-attribute policy. `Path.normalize`
and `toRealPath` are not a full race-resistant containment mechanism. A
`SecureDirectoryStream` can help when the filesystem provider supports it;
otherwise document the weaker threat model or use a narrowly reviewed OS layer.
Handle `ATOMIC_MOVE` not being supported without silently promising atomicity.

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
Use Java `ProcessBuilder` with separate arguments and explicit environment/cwd.
Consume both streams using bounded workers, check completion status, and implement
a deadline/termination policy. Avoid shell-string interpolation through Scala
process helpers. `ProcessHandle` descendant enumeration is useful operationally
but can race and is not a security sandbox for a hostile process tree.

---

## 21. Concurrency and Async Work

Standard `Future` is eager and lacks built-in structured cancellation. Timing
out `Await` does not cancel the computation. Avoid blocking an application's
global execution context; bound the executor and its queue, and make its owner
responsible for shutdown. [S4]

For structured cancellation, select and pin an effect/runtime library explicitly,
or implement a small lifecycle around Java primitives. Do not imply Cats Effect,
ZIO, virtual threads, or structured-concurrency previews are interchangeable or
part of every Scala installation.

---

## 22. Naming

Use `lowerCamelCase` for methods/values and `UpperCamelCase` for types. Name
opaque/domain types by meaning, such as `PayloadBytes`, rather than implementation.
Use explicit unit suffixes at primitive boundaries. Avoid symbolic operators
whose evaluation or failure behavior is not obvious to an ordinary Scala reader.
Preserve external API naming when interoperability requires it.

---

## 23. Formatting

Use Scalafmt with an exact formatter version and an appropriate Scala 3 dialect.
Two-space indentation is the default profile here; 100 columns is a review target.
Choose a consistent braces/significant-indentation policy through the formatter.
Do not paste a moving `version = latest` into a reproducible configuration.
Pin Scalafix rules separately when using semantic rewrites.

---

## 24. Comments and Documentation

Use Scaladoc for public types/methods and document algebraic error cases,
resource scope, execution-context ownership, and cancellation semantics.
Comments should explain a surprising given, cast, or Java interop requirement.
Keep effect descriptions honest: returning `Future[A]` alone says little about
when work began, what it mutates, or who can stop it.

---

## 25. Dependencies

Pin compiler, JDK, build tools, compiler plugins, and dependencies. Review sbt
plugins and Scala CLI directives as executable dependency/build configuration.
A pure-looking source file may trigger downloads via directives. Avoid dynamic
versions and unreviewed snapshot repositories for reproducible applications.
Use dependency auditing without treating its output as a complete security proof.

---

## 26. Language-Specific Engineering

Use enums/sealed ADTs to make state alternatives explicit, and opaque types to
separate units without public raw construction where invariants matter. Validate
at the constructor boundary; `asInstanceOf` is not a parser. Keep implicit/given
scope narrow. Choose one coherent effect model per subsystem and document where
exceptions, futures, and typed errors cross into it.

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
java -version
scala-cli version
# Use the project's pinned Scala CLI/JDK/compiler configuration:
scala-cli run examples/bounded_sum.scala --scala 3.3.6
# For an sbt project with reviewed plugins already declared:
sbt scalafmtCheckAll test
```

The compiler pin is an example compatibility baseline, not a claim of the newest
release. First invocation can resolve dependencies; review that build first.

---

## 28. Testing

Test each ADT error case, null at foreign boundaries, integer limits, partial
I/O, cancellation ownership, and resource lifetime. Test that returned lazy values
do not depend on closed resources. Use property tests with bounded generators
for pure transformations; isolate scheduler and clock dependencies. Run on the
supported JDKs instead of assuming bytecode compatibility proves behavior.

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
| `Option.get` or `Either.toOption.get` | Exhaustive handling or propagation. |
| `Future` timeout described as cancellation | Explicit task/process lifecycle. |
| Blocking work on an unbounded/global executor | An owned bounded execution policy. |
| Lazy I/O value returned from `Using` | Consume within ownership scope. |
| `val` mistaken for deep immutability | An explicit data/aliasing contract. |
| Broad `Throwable` recovery | A defined domain or `NonFatal` boundary. |

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

Complete source: [examples/bounded_sum.scala](examples/bounded_sum.scala). Run instructions and actual validation
results are in the collection README and VALIDATION.md. This is a deliberately
small reference for arithmetic/contracts, not a claim to implement the file,
process, or async policies described elsewhere.

```scala
object BoundedSum:
  val ItemCountMax: Int = 1024
  val TotalMax: Long = 1_000_000L

  enum ValidationError:
    case TooManyItems, InvalidItem, TotalExceeded

  // A validated Scala value, not a JSON decoder or hostile-object sandbox.
  def run(input: Vector[Long]): Either[ValidationError, Long] =
    if input.length > ItemCountMax then Left(ValidationError.TooManyItems)
    else
      var total = 0L
      var index = 0
      var failure: Option[ValidationError] = None
      while index < input.length && failure.isEmpty do
        val value = input(index)
        if value < 0L then failure = Some(ValidationError.InvalidItem)
        else if value > TotalMax - total then
          failure = Some(ValidationError.TotalExceeded)
        else total += value
        index += 1
      failure match
        case Some(error) => Left(error)
        case None => Right(total)

@main def testBoundedSum(): Unit =
  import BoundedSum.*
  val cases: Vector[(Vector[Long], Either[ValidationError, Long])] = Vector(
    (Vector.empty, Right(0L)),
    (Vector(1L), Right(1L)),
    (Vector(999_999L, 1L), Right(TotalMax)),
    (Vector.fill(ItemCountMax)(0L), Right(0L)),
    (Vector.fill(ItemCountMax + 1)(0L), Left(ValidationError.TooManyItems)),
    (Vector(-1L), Left(ValidationError.InvalidItem)),
    (Vector(1_000_001L), Left(ValidationError.TotalExceeded)),
    (Vector(TotalMax, 1L), Left(ValidationError.TotalExceeded)),
    (Vector(Long.MaxValue), Left(ValidationError.TotalExceeded))
  )
  cases.zipWithIndex.foreach { case ((input, expected), index) =>
    if run(input) != expected then
      throw new IllegalStateException(s"case $index failed")
  }
  println(s"Scala: ${cases.length} cases passed")
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

A minimal repository can place this guide at `docs/TIGER_STYLE_SCALA.md`,
production code in its language-appropriate source directory, and boundary tests
alongside that code. Keep development-tool configuration, dependency pins, and
CI checks under version control. Optional real media belongs in `docs/assets/`.

In this downloadable collection, the guide is at the archive root and its
reference source is `examples/bounded_sum.scala`. Relative links work when the archive is extracted
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

- **[S1]** [Scala functional error handling](https://docs.scala-lang.org/scala3/book/fp-functional-error-handling.html)
- **[S2]** [Scala explicit nulls](https://docs.scala-lang.org/scala3/reference/experimental/explicit-nulls.html)
- **[S3]** [Scala Using resource management](https://www.scala-lang.org/api/2.13.16/scala/util/Using$.html)
- **[S4]** [Scala futures and execution contexts](https://docs.scala-lang.org/overviews/core/futures.html)
- **[S5]** [Scalafmt configuration](https://scalameta.org/scalafmt/docs/configuration.html)
- **[S6]** [Java ProcessBuilder](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ProcessBuilder.html)

The numeric limits, naming choices, function-size review threshold, and example
API are this guide's policy choices, not claims that the language specification
mandates them. Toolchain validation scope is recorded in [VALIDATION.md](VALIDATION.md).

---

# Compact Tiger Style Scala Card

<details>
<summary><strong>Open the condensed rules</strong></summary>

**Safety:** validate at trust boundaries; distinguish absence and failure; bound
work and storage; expose units; make ownership explicit; preserve invariants
through errors and cancellation; keep privileged operations narrow.

**Performance:** model capacities first; batch expensive work; profile realistic
loads; account for allocation and retention; keep hot paths simple and defined.

**Developer experience:** follow Scala's conventions and one pinned formatter;
keep contracts visible; use precise types without confusing them with runtime
validation; test boundaries and cleanup; document justified exceptions.

</details>

**Final rule:** a reviewer should be able to identify the program's limits,
invariants, state transitions, resource owners, failure behavior, and external
capabilities without reverse-engineering hidden conventions.
