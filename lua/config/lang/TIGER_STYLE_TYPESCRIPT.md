<!-- TIGER_STYLE_TYPESCRIPT.md — Independent language adaptation; no active scripts. -->
# Tiger Style for TypeScript

> **Safety first. Performance second. Developer experience third.**

**Guide version:** 1.0  
**Primary target:** TypeScript 5.9 strict profile; ES2022+; Node and browser boundaries separated  
**Line-width review target:** 100 columns, subject to the language formatter  
**Ordinary function review threshold:** 70 physical source lines  
**Platform emphasis:** Arch Linux; portable core with explicit OS adapters

This guide follows the structure of your Lua guide while adapting contracts,
errors, numbers, ownership, concurrency, tooling, and examples to TypeScript.
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

Pin TypeScript, runtime, module format, and target library definitions. This
guide uses a TypeScript 5.9-compatible strict profile and ES2022; the standalone
reference is compiled to CommonJS for its test recipe. Browser and Node APIs are
not interchangeable. A newer JavaScript engine does not automatically supply a
TypeScript compiler or every configured library declaration.

Types are erased. `as`, `satisfies`, and interfaces do not validate JSON at runtime.
Native TypeScript execution/stripping, when offered by a runtime, is not a
replacement for `tsc --noEmit`. [T1]

---

## 3. File and Module Layout

Keep type declarations, limits, runtime validators, pure functions, and effectful
adapters visibly separated. Do not start timers, sockets, downloads, or workers
just by importing a module. Choose ESM or CommonJS deliberately and match package
metadata, emitted paths, and module resolution. Avoid circular imports that make
initialization order part of correctness.

---

## 4. Assertions, Preconditions, and Postconditions

Use runtime guards to narrow `unknown`. A user-defined assertion signature is
a promise to the compiler; its implementation must actually test the condition.
Do not use non-null assertions or casts to bypass external validation. Internal
invariant failures can throw, while expected validation failures should use the
subsystem's declared result/error contract. Do not depend on `console.assert`
to terminate execution.

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

Use discriminated unions and exhaustive switches for domain states. A `never`
check helps compile-time exhaustiveness only after the runtime boundary has
validated the discriminator. Avoid nested ternaries for effectful logic. Bound
loops and output size when traversing parsed objects; “functional” `.map()` does
not stop an enormous input from allocating an enormous result.

---

## 7. Error Handling

Choose a discriminated `Result<T, E>` for expected failures or typed thrown errors
with one handling boundary. Catch values as `unknown`; not every thrown value is
an `Error`. Handle every started promise through an await or an explicit owner.
Do not catch and replace a useful failure with `undefined`. Preserve causes and
redact secret context before logs or serialized errors.

---

## 8. Absence, False, and Defaults

`undefined`, `null`, false, zero, and empty strings are different. Use `??` when
both null and undefined mean missing; use an explicit comparison if only one
does. Do not default with `||` when false/zero is valid. Enable
`exactOptionalPropertyTypes` so omitted and explicitly undefined properties do
not blur unintentionally. `JSON.stringify` can omit undefined properties; define
a wire representation for absence deliberately. [T1]

---

## 9. Numbers, Counts, and Units

JavaScript `number` is floating-point; validate `Number.isSafeInteger` for exact
integer domains, not merely `typeof value === "number"`. Reject NaN/infinity and
out-of-range values. Use `bigint` for larger integers with explicit serialization;
JSON does not natively serialize bigint values. Avoid bitwise tricks that coerce
counts to signed 32-bit numbers. A string's `.length` counts UTF-16 code units,
not UTF-8 bytes or grapheme clusters.

---

## 10. Collections and Data Shapes

Use `unknown` at untrusted boundaries and validate a bounded record/array shape.
Prefer `Map` for untrusted dictionary keys, or a carefully constructed null-prototype
record where a plain object is necessary. Avoid unsafe recursive merging of
keys such as `__proto__`. Readonly types are compile-time access restrictions,
not deep runtime freezing. Sparse arrays need an explicit policy; holes are not
valid numeric elements merely because `.length` is bounded.

---

## 11. State and Mutation

Centralize mutation and compute proposed state before committing it. A single
JavaScript event loop does not eliminate races between awaits. Use a generation
or request identity before applying delayed results. `const` prevents rebinding,
not object mutation. Copy or transfer ownership of mutable data when workers or
callbacks can outlive the caller.

---

## 12. Function Design

Use explicit public return types, discriminated option objects, and small
interfaces. Separate parsing from trusted-domain functions. Avoid excessive
generic conditional types that make the actual runtime shape harder to audit.
A branded type should have a validated constructor; an exported unchecked cast
undoes the benefit. Document whether inputs are borrowed, copied, or retained.

---

## 13. Scope

Keep listeners, timers, and closures scoped to an owner. Remove listeners during
teardown and avoid closing over an entire DOM tree or request body when an ID is
enough. Revalidate DOM nodes/resources after asynchronous waits. Avoid using a
module singleton as a hidden shared cache without limits and an eviction policy.

---

## 14. Resource Lifetime

Use `try/finally` and explicit dispose/close methods unless the selected runtime
and toolchain have verified support for disposal syntax and interfaces.
Clear owned timers, remove listeners, abort owned I/O, and await shutdown.
`FinalizationRegistry` is not deterministic cleanup. If disposal can fail,
document how it is reported without silently losing the original error.

---

## 15. Memory and Allocation

Bound Maps, caches, strings, buffers, queued promises, worker messages, and DOM
nodes. A `Promise.all(items.map(...))` starts all work eagerly; a semaphore inside
each task still leaves every promise allocated. Use bounded admission and a
bounded queue. Shared ArrayBuffer/worker transfers need an explicit ownership
and synchronization policy. A short view can retain a much larger ArrayBuffer.

---

## 16. Performance

Profile using the selected Node/browser tools and representative workloads.
Avoid quadratic copying via repeated spread inside loops. Streaming reduces
peak memory only if all stages respect backpressure and cumulative bounds.
Separate CPU-heavy work from the event loop when justified, but bound worker
count and transfer size. Measure responsiveness and tail latency, not just a
microbenchmark's fastest run.

---

## 17. Determinism

Object property enumeration has rules, but they are not a universal canonical
encoding. Choose a deterministic serialization order explicitly, and define how
numbers, dates, and absence are encoded. Inject clock/random functions in tests;
use platform cryptographic APIs for tokens. Do not let asynchronous completion
order accidentally determine a persisted result.

---

## 18. Security

Never use `eval` or `new Function` on untrusted data. Avoid `innerHTML` for text;
use safe DOM APIs and context-appropriate output encoding. Validate schemas before
merging configuration, constrain URL destinations, and parameterize SQL.
Separate browser-origin/CSP policy from Node filesystem/process authority.
Neither TypeScript's type checker nor Node's `vm` contexts are a general sandbox
for hostile code.

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
On Node, use `fs`/`fs.promises` APIs with deliberate flags, permissions, and
handle ownership. `path.resolve`/`path.relative` do not eliminate symlink races.
If a hostile-directory threat model requires descriptor-relative confinement
beyond the available high-level API, use a reviewed native/OS boundary or isolate
the filesystem view. Browser file access has a different user-grant model.

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
On Node, use `spawn` or `execFile` with separate arguments and `shell: false`.
`exec` evaluates a shell command. `execFile` has a buffer cap but still needs a
termination/lifecycle policy; streaming with `spawn` needs your own retention
bounds. An AbortSignal does not promise process-tree termination. Windows batch
files have distinct execution behavior: do not claim POSIX rules cover them. [T2]

---

## 21. Concurrency and Async Work

Pass an AbortSignal to APIs that actually support it, and distinguish an
abort request from settled completion. `Promise.race` with a timeout does not
cancel its losing operation. Keep a bounded task registry, abort owned work on
teardown, await settlement, and reject stale results before commit. Use Web
Workers or Node worker threads for appropriate CPU isolation, while separately
addressing shared-memory and process-level security.

---

## 22. Naming

Use `camelCase` for variables/functions and `PascalCase` for types/classes.
Use clear constants such as `ITEM_COUNT_MAX` when that is the project's chosen
convention. Name primitive units explicitly: `timeoutMs`, `payloadSizeBytes`.
Avoid `I` prefixes on every interface and cryptic single-letter generics when
the generic parameters have meaningful domain roles.

---

## 23. Formatting

Use one pinned formatter and lint profile. The example compiler settings are:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "noEmitOnError": true
  }
}
```

Use a matching NodeNext profile for an ESM project instead of copying CommonJS
blindly. `noUncheckedIndexedAccess` requires checking possibly absent reads. [T3]
Two spaces and a 100-column formatter target are this guide's defaults.

---

## 24. Comments and Documentation

Document runtime constraints with TSDoc/JSDoc alongside static signatures:
limits, units, mutation, retained references, errors, and cancellation semantics.
Explain any deliberate `any`, non-null assertion, or cast at its narrow boundary.
Do not let a generated `.d.ts` file promise stronger validation than the runtime
implementation provides.

---

## 25. Dependencies

Commit the package lock appropriate to the selected package manager and use
its immutable/frozen install mode in CI. Review install scripts, native addons,
transitive dependencies, and bundler/compiler plugins. `--ignore-scripts` reduces
one execution surface but can also disable required builds; decide deliberately.
Do not run project package managers as root or download a formatter implicitly
from an editor mapping.

---

## 26. Language-Specific Engineering

Audit the static/runtime gap explicitly. Compile-time readonly, branding,
`satisfies`, and unions guide trusted code; only actual checks validate incoming
values. Keep Node and browser authority adapters separate. Test both type-level
constraints and runtime rejection. Validate plain decoded data, not arbitrary
hostile Proxy objects supplied by already-executing untrusted JavaScript.

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
node --version
./node_modules/.bin/tsc --noEmit
# Use the locally installed, pinned tools from the reviewed project:
./node_modules/.bin/prettier --check .
./node_modules/.bin/eslint .
```

The bundled standalone example has an exact compile-and-run recipe in the
collection README. Use local binaries so a missing tool does not trigger an
unreviewed on-demand download.

---

## 28. Testing

Test the decoder with null, undefined, booleans, fractional numbers, NaN,
infinity, unsafe integers, sparse arrays, oversize collections, and prototype-like
keys. Test rejection under emitted JavaScript too; a type-only test cannot prove
runtime validation. For async adapters check abort before start, abort during
I/O, timeout cleanup, and a stale result arriving after a newer request.

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
| `JSON.parse(text) as Config` | Bounded decode to unknown, then validation. |
| `value!` on external data | A real presence check. |
| `value || default` with valid false/zero | Deliberate nullish/presence handling. |
| Unlimited `Promise.all` | Bounded admission and queue. |
| Timeout race described as cancellation | Abort plus owned settlement/cleanup. |
| Untrusted recursive object merge | A validated schema and safe key policy. |

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

Complete source: [examples/bounded_sum.ts](examples/bounded_sum.ts). Run instructions and actual validation
results are in the collection README and VALIDATION.md. This is a deliberately
small reference for arithmetic/contracts, not a claim to implement the file,
process, or async policies described elsewhere.

```typescript
const ITEM_COUNT_MAX = 1024;
const TOTAL_MAX = 1_000_000;

type ValidationError =
  | "invalid-input"
  | "too-many-items"
  | "invalid-item"
  | "total-exceeded";
type Result =
  | { readonly ok: true; readonly value: number }
  | { readonly ok: false; readonly error: ValidationError };

// Validate plain decoded values, not hostile in-process Proxy objects.
// Borrow only for this synchronous call; never mutate or retain input.
function boundedSum(input: unknown): Result {
  if (!Array.isArray(input)) return { ok: false, error: "invalid-input" };
  const items: readonly unknown[] = input;
  if (items.length > ITEM_COUNT_MAX) return { ok: false, error: "too-many-items" };
  let total = 0;
  for (const value of items) {
    if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
      return { ok: false, error: "invalid-item" };
    }
    if (value > TOTAL_MAX - total) return { ok: false, error: "total-exceeded" };
    total += value;
  }
  return { ok: true, value: total };
}

const cases: ReadonlyArray<readonly [unknown, Result]> = [
  [[], { ok: true, value: 0 }],
  [[1], { ok: true, value: 1 }],
  [[999_999, 1], { ok: true, value: TOTAL_MAX }],
  [Array(1024).fill(0), { ok: true, value: 0 }],
  [Array(1025).fill(0), { ok: false, error: "too-many-items" }],
  [null, { ok: false, error: "invalid-input" }],
  [[true], { ok: false, error: "invalid-item" }],
  [[-1], { ok: false, error: "invalid-item" }],
  [[1.5], { ok: false, error: "invalid-item" }],
  [[NaN], { ok: false, error: "invalid-item" }],
  [[Infinity], { ok: false, error: "invalid-item" }],
  [[Number.MAX_SAFE_INTEGER + 1], { ok: false, error: "invalid-item" }],
  [Array(1), { ok: false, error: "invalid-item" }],
  [[1_000_001], { ok: false, error: "total-exceeded" }],
  [[TOTAL_MAX, 1], { ok: false, error: "total-exceeded" }],
];
for (const [input, expected] of cases) {
  const actual = boundedSum(input);
  const equal = actual.ok
    ? expected.ok && actual.value === expected.value
    : !expected.ok && actual.error === expected.error;
  if (!equal) throw new Error("bounded sum contract failed");
}
console.log(`TypeScript: ${cases.length} cases passed`);
export { boundedSum, type Result, type ValidationError };
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

A minimal repository can place this guide at `docs/TIGER_STYLE_TYPESCRIPT.md`,
production code in its language-appropriate source directory, and boundary tests
alongside that code. Keep development-tool configuration, dependency pins, and
CI checks under version control. Optional real media belongs in `docs/assets/`.

In this downloadable collection, the guide is at the archive root and its
reference source is `examples/bounded_sum.ts`. Relative links work when the archive is extracted
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

- **[T1]** [TypeScript compiler configuration](https://www.typescriptlang.org/tsconfig/)
- **[T2]** [Node child-process API](https://nodejs.org/api/child_process.html)
- **[T3]** [TypeScript unchecked indexed access](https://www.typescriptlang.org/tsconfig/noUncheckedIndexedAccess.html)
- **[T4]** [TypeScript narrowing](https://www.typescriptlang.org/docs/handbook/2/narrowing.html)
- **[T5]** [ECMAScript language specification](https://tc39.es/ecma262/)
- **[T6]** [Node filesystem API](https://nodejs.org/api/fs.html)

The numeric limits, naming choices, function-size review threshold, and example
API are this guide's policy choices, not claims that the language specification
mandates them. Toolchain validation scope is recorded in [VALIDATION.md](VALIDATION.md).

---

# Compact Tiger Style TypeScript Card

<details>
<summary><strong>Open the condensed rules</strong></summary>

**Safety:** validate at trust boundaries; distinguish absence and failure; bound
work and storage; expose units; make ownership explicit; preserve invariants
through errors and cancellation; keep privileged operations narrow.

**Performance:** model capacities first; batch expensive work; profile realistic
loads; account for allocation and retention; keep hot paths simple and defined.

**Developer experience:** follow TypeScript's conventions and one pinned formatter;
keep contracts visible; use precise types without confusing them with runtime
validation; test boundaries and cleanup; document justified exceptions.

</details>

**Final rule:** a reviewer should be able to identify the program's limits,
invariants, state transitions, resource owners, failure behavior, and external
capabilities without reverse-engineering hidden conventions.
