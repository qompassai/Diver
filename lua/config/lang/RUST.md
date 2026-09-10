# Tiger Style for Rust

> **Safety first. Performance second. Developer experience third.**

**Version:** 1.0  
**Primary targets:** Rust nightly, Rust 2024 edition, Cargo workspaces, Linux/Unix services, CLIs, systems code, and library crates  
**Recommended maximum line width:** 100 columns  
**Recommended ordinary function review threshold:** 70 lines  
**Recommended toolchain policy:** Pin an exact nightly date in `rust-toolchain.toml`

---

## 1. The Tiger Style Contract

Tiger Style is a hierarchy of engineering priorities:

\[
\boxed{\text{Safety} \;>\; \text{Performance} \;>\; \text{Developer Experience}}
\]

Rust provides unusually strong compile-time guarantees, but it does not make a program automatically correct. Rust cannot, by itself, prove that:

- a queue has a reasonable capacity;
- a retry loop terminates;
- a timeout is appropriate;
- an allocation cannot exhaust memory;
- an external protocol input is valid;
- a state machine transition is authorized;
- an `unsafe` proof remains valid after refactoring;
- an asynchronous result is still current;
- a subprocess cannot hang forever;
- a public API has a stable compatibility contract.

Tiger Style Rust uses Rustâ€™s type system, ownership model, exhaustive pattern matching, and standard tooling to make invalid states difficult to construct and obvious to detect.

### Working principle

> Make invalid states hard to construct, easy to detect, and impossible to silently preserve.

### When priorities conflict

1. Do not sacrifice a safety invariant for convenience.
2. Do not permit unbounded resource use for a small performance improvement.
3. Do not hide failure merely to make an API look simpler.
4. Do not optimize behavior whose correctness model is unclear.
5. Do not add abstraction when direct, explicit code is safer to audit.

### Review questions

A Tiger Style Rust function should make these questions easy to answer:

- What inputs are accepted and rejected?
- What work, memory, output, and time are bounded?
- Which values own resources and when are they dropped?
- What state can change and at which commit point?
- Which errors are expected and how are they represented?
- Which invariants are compile-time, runtime, or operational?
- What is the cancellation behavior of asynchronous work?
- Does output remain deterministic where determinism matters?
- Does this code cross a privileged boundary: filesystem, network, process, FFI, `unsafe`, or credentials?
- What nightly feature is required, and what is its removal or stabilization plan?

---

## 2. Rust Nightly Policy

Nightly is an explicit compatibility commitment, not permission to use unstable features casually.

### Pin the toolchain

Check an exact nightly into source control:

```toml
# rust-toolchain.toml
[toolchain]
channel = "nightly-YYYY-MM-DD"
profile = "minimal"
components = ["cargo", "clippy", "rustfmt", "rust-src", "miri"]
targets = []
```

Replace `YYYY-MM-DD` with a reviewed, known-good date. Do not commit a moving `nightly` channel for software that needs reproducible builds.

`rustup` supports project-local toolchain selection through `rust-toolchain.toml`, including pinned nightly channels and explicit components. [web:73]

### Unstable feature rule

Every unstable feature must have:

1. A written reason.
2. A narrow owning module.
3. A test or validation path.
4. A removal condition: stabilization, replacement, or explicit long-term dependency.
5. No broader public exposure than necessary.

```rust
// crate root only when the feature is genuinely crate-wide.
#![feature(let_chains)]

// Reason: simplifies a bounded parser branch without unsafe code.
// Removal: remove when stable Rust supports the required syntax.
```

Prefer a small internal module that contains nightly-only behavior over spreading `#![feature(...)]` assumptions throughout the crate.

### Edition and dependency baseline

```toml
# Cargo.toml
[package]
edition = "2024"
rust-version = "1.85"
```

For a nightly-only binary, `rust-version` still documents the stable language baseline where meaningful. For a public library, do not expose nightly-only APIs unintentionally unless the crate explicitly declares nightly-only support.

### Required checks

At minimum, the pinned toolchain should run:

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-features
cargo miri test --workspace
```

Miri is a nightly-only interpreter/tool that can run Cargo tests and detect classes of undefined behavior in unsafe code. [web:76]

---

## 3. Crate and Module Layout

A module should read top-to-bottom. Prefer a reader discovering the contract before the implementation details.

Recommended order:

1. Module-level documentation and safety notes.
2. Imports.
3. Public constants and public types.
4. Private constants and type aliases.
5. Error types.
6. Validation helpers.
7. Small leaf functions.
8. Orchestration functions.
9. Trait implementations.
10. Tests.

```rust
//! Bounded request queue.
//!
//! Invariant: `item_count <= capacity` at every public boundary.

use std::collections::VecDeque;

pub const REQUEST_COUNT_MAX: usize = 1_024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct QueueCapacity(usize);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QueueError {
    CapacityZero,
    CapacityExceeded,
}

#[derive(Debug)]
pub struct RequestQueue<T> {
    capacity: QueueCapacity,
    values: VecDeque<T>,
}

impl QueueCapacity {
    pub fn new(value: usize) -> Result<Self, QueueError> {
        if value == 0 {
            return Err(QueueError::CapacityZero);
        }

        if value > REQUEST_COUNT_MAX {
            return Err(QueueError::CapacityExceeded);
        }

        Ok(Self(value))
    }
}

impl<T> RequestQueue<T> {
    pub fn new(capacity: QueueCapacity) -> Self {
        Self {
            capacity,
            values: VecDeque::with_capacity(capacity.0),
        }
    }
}
```

### Layout rules

- One module should own one coherent responsibility.
- Keep public APIs small and intentional.
- Prefer explicit modules over broad prelude re-exports.
- Keep `mod.rs` / module roots light; do not hide large initialization side effects in imports.
- Keep platform-, runtime-, and feature-specific behavior behind narrow boundaries.
- Do not create abstractions for a single call site unless they encode a valuable invariant.

---

## 4. Types Are Invariants

Use types to prevent invalid values from entering the system.

### Replace primitive ambiguity

Avoid passing semantically distinct integers as raw `usize`, `u64`, or `i64` across important boundaries.

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct TimeoutMs(u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct ByteCount(u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct RetryCount(u8);
```

Use constructors to validate range and unit semantics:

```rust
impl TimeoutMs {
    pub const MIN: u64 = 1;
    pub const MAX: u64 = 30_000;

    pub fn new(value: u64) -> Result<Self, ConfigError> {
        if value < Self::MIN {
            return Err(ConfigError::TimeoutTooSmall);
        }

        if value > Self::MAX {
            return Err(ConfigError::TimeoutTooLarge);
        }

        Ok(Self(value))
    }

    pub fn as_duration(self) -> std::time::Duration {
        std::time::Duration::from_millis(self.0)
    }
}
```

### Model states explicitly

```rust
#[derive(Debug)]
pub enum ConnectionState {
    Disconnected,
    Connecting { attempt: RetryCount },
    Connected { connection_id: u64 },
    Closing,
}
```

Prefer enums to boolean combinations such as:

```rust
struct BadState {
    connected: bool,
    connecting: bool,
    closing: bool,
}
```

The boolean version permits contradictory states. The enum documents and constrains legal states.

### Newtype rules

Use a newtype when a primitive has one of these properties:

- a unit;
- a trusted range;
- a security meaning;
- a domain identity;
- a serialization boundary;
- a distinction that prevents argument reversal.

Do not add newtypes mechanically to private, obvious, local arithmetic where they obscure more than they protect.

---

## 5. Assertions and Contracts

Assertions document programmer-error invariants. `Result` documents expected operational failure.

### Use `assert!` for internal invariants

```rust
fn copy_slice<T: Clone>(values: &[T], first_index: usize, item_count: usize) -> Vec<T> {
    assert!(first_index <= values.len());
    assert!(item_count <= values.len() - first_index);

    let final_index = first_index + item_count;
    let result = values[first_index..final_index].to_vec();

    assert_eq!(result.len(), item_count);

    result
}
```

### Use normal errors for external input

```rust
fn parse_port(value: &str) -> Result<u16, ParsePortError> {
    if value.is_empty() {
        return Err(ParsePortError::Empty);
    }

    value.parse::<u16>().map_err(ParsePortError::Invalid)
}
```

### Panic policy

A library should not panic because a caller provided malformed external data. A binary may terminate on unrecoverable initialization failure, but it should provide contextual diagnostics.

```rust
fn main() -> Result<(), AppError> {
    let config = AppConfig::load()?;
    run(config)
}
```

Avoid `unwrap()` and `expect()` in production paths unless the failure is an internal impossibility and the message records the invariant:

```rust
let first = values.first().expect("non-empty validated before selection");
```

Do not use `expect("should work")`.

### `debug_assert!`

Use `debug_assert!` only for invariants that are useful during development but not required for release safety. Never make correctness depend on an invariant checked only in debug builds.

---

## 6. Bound Everything

Every system has finite resources. Encode capacity and time budgets in the design.

### Bound these resources

- allocations;
- request bodies;
- decoded fields;
- file sizes;
- line sizes;
- recursion depth;
- retry count;
- queue length;
- worker count;
- channel capacity;
- in-flight requests;
- open file/socket count;
- subprocess output;
- subprocess runtime;
- diagnostic count;
- cache entries and bytes;
- log retention;
- pagination results;
- batch size.

### Capacity invariant

For a bounded queue:

\[
0 \leq q_{\text{count}} \leq q_{\text{capacity}}
\]

A push is permitted only when:

\[
q_{\text{count}} < q_{\text{capacity}}
\]

### Bounded retry

```rust
const RETRY_COUNT_MAX: u8 = 4;

fn run_with_retry<T, E>(mut operation: impl FnMut(u8) -> Result<T, E>) -> Result<T, E> {
    for attempt in 1..=RETRY_COUNT_MAX {
        match operation(attempt) {
            Ok(value) => return Ok(value),
            Err(error) if attempt == RETRY_COUNT_MAX => return Err(error),
            Err(_) => {}
        }
    }

    unreachable!("bounded inclusive retry range always returns");
}
```

Do not write unbounded retries without a documented external termination condition.

### Bounded read example

```rust
use std::io::{self, Read};

const FILE_SIZE_BYTES_MAX: u64 = 8 * 1024 * 1024;

fn read_limited(mut reader: impl Read) -> io::Result<Vec<u8>> {
    let mut output = Vec::with_capacity(64 * 1024);
    let mut limited = reader.take(FILE_SIZE_BYTES_MAX + 1);

    limited.read_to_end(&mut output)?;

    if output.len() as u64 > FILE_SIZE_BYTES_MAX {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "input exceeds configured size limit",
        ));
    }

    Ok(output)
}
```

### Do not confuse a timeout with cancellation

A timeout describes how long a caller waits. It does not automatically stop work unless the underlying operation and ownership model support cancellation.

---

## 7. Error Handling

Every fallible operation needs a deliberate failure path.

### Error taxonomy

Separate errors by ownership and caller action:

```rust
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("configuration file is missing: {path}")]
    Missing { path: std::path::PathBuf },

    #[error("configuration is invalid: {message}")]
    Invalid { message: String },

    #[error("failed to read configuration: {source}")]
    Read {
        #[source]
        source: std::io::Error,
    },
}
```

A library should expose errors that let callers decide whether to retry, report, discard, or correct input.

### Preserve context at boundaries

```rust
fn load_config(path: &std::path::Path) -> Result<AppConfig, ConfigError> {
    let text = std::fs::read_to_string(path).map_err(|source| ConfigError::Read { source })?;

    toml::from_str(&text).map_err(|error| ConfigError::Invalid {
        message: format!("{}: {error}", path.display()),
    })
}
```

### Rules

- Do not discard errors.
- Do not turn every error into an unstructured string too early.
- Add context where information is lost across a boundary.
- Do not expose secrets in error messages.
- Prefer errors that identify the failed operation and relevant bounded metadata.
- Avoid error variants that can never be acted upon or understood.
- Do not use panics for routine network, filesystem, parse, process, or user-input failures.

### `anyhow` and `thiserror`

A practical boundary rule:

- Use a typed error enum such as `thiserror` for library/public/domain boundaries.
- Use an application error wrapper such as `anyhow` in binary orchestration code when the caller only needs a contextual failure report.

Do not leak an application-only error strategy through a library API without intent.

---

## 8. Ownership, Borrowing, and Lifetimes

Ownership is a design tool, not merely a compiler hurdle.

### Make resource ownership visible

```rust
pub struct TempDirectory {
    path: std::path::PathBuf,
}

impl TempDirectory {
    pub fn path(&self) -> &std::path::Path {
        &self.path
    }
}

impl Drop for TempDirectory {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.path);
    }
}
```

The owner of a resource should be obvious. Avoid hidden global ownership or long-lived references that obscure cleanup responsibility.

### Prefer borrowing for observation

```rust
fn validate_request(request: &Request) -> Result<(), ValidationError> {
    // Validation observes; it does not take ownership.
    Ok(())
}
```

### Move ownership deliberately

```rust
fn enqueue(queue: &mut RequestQueue<Request>, request: Request) -> Result<(), QueueError> {
    queue.push(request)
}
```

### Lifetime rules

- Use explicit lifetime annotations only when they communicate a relationship not obvious from elision.
- Do not force `'static` to evade a borrow checker error unless `'static` is truly correct.
- Do not use `Box::leak`, global caches, or leaked allocations as routine lifetime management.
- Prefer owned values across async task boundaries unless borrowing is clearly sound and reduces meaningful cost.
- Do not return references to temporary, mutable, or externally invalidatable storage.

### Clone policy

Cloning is valid when it makes ownership safe and clear. It is not free, and it should not conceal an unbounded copy.

```rust
fn build_header(name: &str) -> HeaderName {
    HeaderName::from_bytes(name.as_bytes()).expect("validated static header name")
}
```

Use `Arc` when shared ownership is necessary; do not default to `Arc<Mutex<T>>` as a substitute for state design.

---

## 9. Numbers, Indexes, and Units

Integer safety requires deliberate conversion and overflow behavior.

### Rules

- Name units in identifiers: `timeout_ms`, `payload_size_bytes`, `retry_count`.
- Use `usize` for in-memory indexing and container lengths.
- Use fixed-width integer types for on-wire, disk, ABI, and protocol fields.
- Validate every narrowing conversion.
- Use checked arithmetic at security, allocation, indexing, and external-input boundaries.
- Never silently truncate attacker-controlled or externally sourced values.

```rust
fn allocate_records(record_count: u64) -> Result<Vec<Record>, AllocationError> {
    let record_count = usize::try_from(record_count)
        .map_err(|_| AllocationError::RecordCountTooLarge)?;

    if record_count > RECORD_COUNT_MAX {
        return Err(AllocationError::RecordCountTooLarge);
    }

    Ok(Vec::with_capacity(record_count))
}
```

### Arithmetic selection

| Operation | Use when | Avoid when |
|---|---|---|
| `checked_add` / `checked_mul` | External input, allocation size, offset, security boundary | Never ignore `None` |
| `saturating_add` | A capped metric/counter is explicitly correct | Overflow must be reported |
| `wrapping_add` | Protocol/algorithm requires modular arithmetic | Ordinary counts, lengths, offsets |
| `overflowing_add` | You need both result and overflow bit | Caller would ignore overflow bit |
| Ordinary `+` | Proven local range or release behavior is explicitly acceptable | Input-controlled bounds |

### Indexing

Prefer checked access for external indexes:

```rust
fn select_item<T>(items: &[T], index: usize) -> Result<&T, SelectError> {
    items.get(index).ok_or(SelectError::IndexOutOfRange {
        index,
        item_count: items.len(),
    })
}
```

Direct indexing is appropriate when a local invariant is already established and documented.

---

## 10. Collections and Determinism

Collection choice encodes performance and correctness behavior.

### Choose intentionally

- `Vec<T>` for ordered contiguous collections.
- `VecDeque<T>` for queue/deque semantics.
- `BTreeMap` / `BTreeSet` when deterministic key order matters.
- `HashMap` / `HashSet` when average lookup cost dominates and iteration order does not matter.
- `IndexMap` only when insertion order is a deliberate dependency and the dependency cost is justified.

### Do not depend on hash iteration order

```rust
use std::collections::BTreeMap;

fn stable_headers(headers: BTreeMap<String, String>) -> String {
    headers
        .into_iter()
        .map(|(name, value)| format!("{name}: {value}"))
        .collect::<Vec<_>>()
        .join("\n")
}
```

Determinism improves reproducible builds, test reliability, caching, diff quality, debugging, and incident analysis.

### Capacity rules

- Use `with_capacity` only when a credible bound or estimate exists.
- Do not preallocate based on untrusted input before validation.
- Cap cache entries and, where relevant, retained byte size.
- Prefer eviction policy over indefinite retention.
- Do not use recursive data traversal on attacker-controlled depth without an explicit limit.

---

## 11. State and Mutation

Mutable state needs a clear owner and a small number of commit points.

### Preferred flow

```text
input
  â”‚
  â–¼
validate
  â”‚
  â–¼
compute bounded delta
  â”‚
  â–¼
validate state transition
  â”‚
  â–¼
single commit point
```

### Transaction-like update

```rust
fn apply_credit(account: &mut Account, amount: Money) -> Result<(), AccountError> {
    let next_balance = account
        .balance
        .checked_add(amount)
        .ok_or(AccountError::BalanceOverflow)?;

    if next_balance > account.credit_limit {
        return Err(AccountError::CreditLimitExceeded);
    }

    account.balance = next_balance;

    Ok(())
}
```

The calculation happens before mutation. If validation fails, the account remains unchanged.

### Rules

- Minimize mutable aliases and mutable shared state.
- Prefer immutable values until a deliberate commit point.
- Model state transitions with enums when boolean combinations can contradict.
- Keep synchronization ownership local and short-lived.
- Avoid holding locks across `.await`, blocking I/O, subprocess waits, callbacks, or user-provided code.
- Do not use global mutable state as an implicit message bus.

---

## 12. Function Design

Ordinary functions should be small enough to understand without scrolling through multiple conceptual phases.

Recommended review threshold:

\[
L_{\text{function}} \leq 70
\]

This is a review threshold, not a reason to fragment a cohesive operation into many trivial helpers.

### Rules

- Make each function have one primary responsibility.
- Put validation near the boundary.
- Name parameters by domain meaning.
- Prefer option/config structs over long positional argument lists.
- Keep leaf functions branch-light.
- Push major control-flow decisions upward.
- Push repetitive loops downward into bounded helpers.
- Return structured results rather than implicitly mutating distant state.

```rust
#[derive(Debug)]
pub struct CopyRange<'a> {
    pub source: &'a [u8],
    pub first_index: usize,
    pub item_count: usize,
}

fn copy_range(options: CopyRange<'_>) -> Result<Vec<u8>, CopyError> {
    let final_index = options
        .first_index
        .checked_add(options.item_count)
        .ok_or(CopyError::RangeOverflow)?;

    let source = options
        .source
        .get(options.first_index..final_index)
        .ok_or(CopyError::RangeOutOfBounds)?;

    Ok(source.to_vec())
}
```

### Avoid abstraction inflation

Do not introduce a trait, macro, generic, builder, async abstraction, or dependency merely because a future use case is imaginable. Add it when the current code has repeated behavior or an invariant that the abstraction genuinely improves.

---

## 13. Async, Threads, and Cancellation

Async Rust can retain correctness bugs even when the code compiles: stale results, unbounded task creation, lock contention, cancellation leaks, and task ownership failures remain design problems.

### Generation tokens for stale work

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct GenerationId(u64);

#[derive(Debug)]
pub struct SearchState {
    generation_id: GenerationId,
}

impl SearchState {
    pub fn begin_request(&mut self) -> GenerationId {
        self.generation_id.0 = self.generation_id.0.wrapping_add(1);
        self.generation_id
    }

    pub fn is_current(&self, generation_id: GenerationId) -> bool {
        self.generation_id == generation_id
    }
}
```

Use the generation token before committing an async result. If a newer request began, discard the obsolete result.

### Bounded concurrency

```rust
const JOB_COUNT_MAX: usize = 8;

// Use a semaphore, bounded worker pool, or bounded channel.
// Do not spawn one task per untrusted input item without a limit.
```

### Async rules

- Bound outstanding tasks and queue capacity.
- Define task ownership: caller-owned, supervisor-owned, or detached by explicit policy.
- Define cancellation behavior for every long-running operation.
- Reject stale results before state mutation.
- Do not hold a mutex/RwLock guard across `.await`.
- Prefer bounded channels to unbounded channels unless unbounded behavior is explicitly proven safe.
- Propagate task errors; do not silently discard `JoinHandle` failures.
- Apply timeouts at the caller boundary, then ensure the task/process/resource can actually be cancelled or reaped.
- Use structured concurrency where the runtime/library supports it.

### Blocking work

Blocking filesystem, DNS, compression, CPU-heavy parsing, and subprocess waits must not accidentally run on latency-sensitive async executor threads. Put blocking work behind a dedicated, bounded execution path.

---

## 14. Resource Lifetime and `Drop`

Every resource needs one clear owner.

Examples:

- file descriptors;
- sockets;
- subprocess handles;
- temporary files and directories;
- database transactions;
- locks;
- tracing spans;
- FFI allocations;
- task cancellation handles;
- background worker lifecycles.

### `Drop` rules

- `Drop` should be fast, deterministic where possible, and non-panicking.
- Do not perform network I/O, lengthy blocking operations, or complex fallible recovery in `Drop`.
- Provide an explicit `close`, `shutdown`, `flush`, `commit`, or `finish` operation when failure must be reported.
- Use `Drop` as a backstop for cleanup, not as the only place correctness-critical finalization occurs.

```rust
pub struct Transaction<'a> {
    connection: &'a mut Connection,
    committed: bool,
}

impl Transaction<'_> {
    pub fn commit(mut self) -> Result<(), DatabaseError> {
        self.connection.commit()?;
        self.committed = true;
        Ok(())
    }
}

impl Drop for Transaction<'_> {
    fn drop(&mut self) {
        if !self.committed {
            let _ = self.connection.rollback();
        }
    }
}
```

The explicit `commit()` carries an error. `Drop` attempts rollback but cannot safely report a normal operational error to the caller.

---

## 15. `unsafe` Rust

`unsafe` is a local proof obligation, not a performance annotation.

### Rules

- Keep `unsafe` blocks as small as possible.
- Prefer safe abstractions around unsafe internals.
- State the safety invariants directly adjacent to each unsafe block.
- Validate every precondition before entering `unsafe`.
- Do not mix complex control flow, allocation, I/O, and pointer arithmetic inside a single unsafe block.
- Use `#![deny(unsafe_op_in_unsafe_fn)]`.
- Treat `unsafe fn` callers as responsible for explicit safety preconditions.
- Test unsafe paths with Miri where applicable.
- Use sanitizers and fuzzing where applicable.
- Do not use `unsafe` to work around ownership or borrowing design problems.

```rust
#![deny(unsafe_op_in_unsafe_fn)]

/// # Safety
///
/// `pointer` must be non-null, aligned for `u32`, and point to at least one
/// initialized `u32` valid for reads for the duration of this call.
unsafe fn read_u32(pointer: *const u32) -> u32 {
    // SAFETY: The caller contract guarantees non-null, alignment, initialization,
    // and read validity for one u32.
    unsafe { pointer.read() }
}
```

### Unsafe review checklist

- What exact invariant makes this operation safe?
- Where is each invariant established?
- Can later mutation invalidate it?
- Can aliasing occur?
- Can integer arithmetic overflow before pointer arithmetic?
- Does alignment hold?
- Does the referenced memory outlive all uses?
- Is panic/unwind behavior safe across this boundary?
- Does FFI ownership match allocation and deallocation functions?
- Does Miri cover this code path where Miri is applicable?

---

## 16. Filesystem, Processes, and Networking

These are privileged boundaries. Treat all paths, environment variables, command output, and remote data as untrusted unless your threat model proves otherwise.

### Filesystem rules

- Reject NUL-containing paths.
- Normalize/canonicalize only with a documented symlink policy.
- Do not enforce containment with naive string-prefix checks.
- Use controlled temporary directories.
- Use write-temp plus atomic rename for important replacement operations.
- Define behavior for existing files, symlinks, permissions, and ownership.
- Bound file reads and directory walks.
- Do not trust file extensions as a security property.

### Direct process execution

Use argument vectors, not a shell:

```rust
use std::process::Command;

fn git_status(root: &std::path::Path, path: &std::path::Path) -> Result<String, ProcessError> {
    let output = Command::new("git")
        .current_dir(root)
        .args(["status", "--porcelain=v1", "--"])
        .arg(path)
        .output()
        .map_err(ProcessError::Spawn)?;

    if !output.status.success() {
        return Err(ProcessError::Exit {
            code: output.status.code(),
            stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
        });
    }

    String::from_utf8(output.stdout).map_err(ProcessError::Utf8)
}
```

### Process checklist

- Executable is explicit.
- Each argument is separate.
- User-controlled paths follow `--` where supported.
- Working directory is explicit.
- Environment inheritance is deliberate.
- Runtime is bounded.
- Captured stdout/stderr is bounded.
- Exit status and signal/termination state are checked.
- Machine-readable output is preferred when parsing.
- Child processes are reaped after timeout/cancellation.
- Secrets are not logged in argv, environment, stdout, or stderr.

### Network rules

- Bound request size, response size, redirects, decompression, connection count, and timeouts.
- Verify TLS by default.
- Separate connect, read, write, and total time budgets where relevant.
- Validate content type and schema before trusting a response.
- Never deserialize untrusted data into a privileged action without validation.
- Make retry policy explicit and idempotency-aware.

---

## 17. Serialization and Parsing

Parsing is an adversarial boundary by default.

### Rules

- Bound input bytes before deserialization.
- Bound nesting, string lengths, collection lengths, and recursion where format/library allows.
- Validate semantic constraints after syntactic parsing.
- Do not trust deserialized paths, URLs, identifiers, commands, or counts.
- Avoid accepting multiple ambiguous representations of the same value.
- Preserve useful error context without echoing secrets.

```rust
#[derive(Debug, serde::Deserialize)]
struct RawConfig {
    timeout_ms: u64,
    endpoint: String,
}

#[derive(Debug)]
struct AppConfig {
    timeout: TimeoutMs,
    endpoint: url::Url,
}

impl TryFrom<RawConfig> for AppConfig {
    type Error = ConfigError;

    fn try_from(raw: RawConfig) -> Result<Self, Self::Error> {
        let timeout = TimeoutMs::new(raw.timeout_ms)?;
        let endpoint = raw.endpoint.parse().map_err(|_| ConfigError::Invalid {
            message: "endpoint must be an absolute URL".to_owned(),
        })?;

        if endpoint.scheme() != "https" {
            return Err(ConfigError::Invalid {
                message: "endpoint must use HTTPS".to_owned(),
            });
        }

        Ok(Self { timeout, endpoint })
    }
}
```

Separate the permissive transport/deserialization form from the validated domain form.

---

## 18. Performance

Performance starts with design and capacity planning, not micro-optimization.

\[
T_{\text{total}}
=
T_{\text{network}}
+
T_{\text{disk}}
+
T_{\text{memory}}
+
T_{\text{cpu}}
+
T_{\text{coordination}}
\]

Investigate the largest meaningful term first.

### Rules

- Measure before optimizing hot code.
- Design bounds before profiling resource exhaustion paths.
- Batch I/O, syscalls, allocations, database operations, RPC, and logging.
- Avoid allocation in known hot loops when measurements justify it.
- Reuse buffers only with clear ownership and reset invariants.
- Prefer simple data layouts and predictable control flow in hot paths.
- Use iterators when they improve clarity; use explicit loops when they make critical bounds/control flow easier to audit.
- Do not introduce `unsafe` for performance without a benchmark and a maintained safety proof.
- Benchmark realistic input sizes and adversarial boundaries, not only happy-path microbenchmarks.

### Allocation rule

Do not allocate from untrusted capacity directly:

```rust
let capacity = usize::try_from(remote_count)?;
if capacity > ITEM_COUNT_MAX {
    return Err(Error::TooManyItems);
}

let mut items = Vec::with_capacity(capacity);
```

### Profiling tools

Use the appropriate tool for the question:

- `cargo bench` / Criterion for repeatable microbenchmarks.
- `perf`, `flamegraph`, or platform profilers for CPU behavior.
- allocator statistics and heap profiling for retained memory.
- tracing spans/metrics for end-to-end latency and queueing.
- `cargo llvm-lines`, `cargo bloat`, or binary inspection for code size when that matters.

---

## 19. Formatting, Lints, and Cargo Policy

Tooling is a correctness boundary. Make it reproducible and explicit.

### `rustfmt.toml`

Use only options supported by your pinned toolchain. Some formatting options require nightly rustfmt, so pinning nightly is especially important when format output is part of CI.

```toml
# rustfmt.toml
edition = "2024"
max_width = 100
hard_tabs = false
tab_spaces = 4
newline_style = "Unix"
use_small_heuristics = "Default"
reorder_imports = true
reorder_modules = true
remove_nested_parens = true
use_field_init_shorthand = true
use_try_shorthand = true
```

### Workspace lint baseline

```toml
# Cargo.toml
[workspace.lints.rust]
unsafe_op_in_unsafe_fn = "deny"
unused_must_use = "deny"

[workspace.lints.clippy]
all = "warn"
pedantic = "warn"
nursery = "warn"
unwrap_used = "warn"
expect_used = "warn"
panic = "warn"
todo = "warn"
unimplemented = "warn"
```

Do not copy this blindly into every crate. Some lint families are intentionally noisy for prototypes, generated bindings, tests, or low-level crates. If you allow a lint, scope the allowance tightly and document why:

```rust
#[allow(clippy::cast_possible_truncation)]
fn encode_u16(value: usize) -> u16 {
    debug_assert!(value <= u16::MAX as usize);
    value as u16
}
```

Prefer a checked conversion if the invariant is not locally proven.

### CI baseline

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-features
cargo doc --workspace --no-deps
cargo miri test --workspace
```

Rustfmt and Clippy are standard Rust tooling components; Miri requires nightly and is suited to testing unsafe-code assumptions. [web:76][web:85]

---

## 20. Testing

Test boundaries before happy-path permutations.

For a maximum \(M\), test:

\[
\{0,\;1,\;M-1,\;M,\;M+1\}
\]

when those values are meaningful.

### Test these cases

- zero;
- one;
- maximum;
- maximum plus one;
- empty input;
- malformed input;
- invalid UTF-8 where relevant;
- cancellation;
- timeout;
- retry exhaustion;
- stale async completion;
- task/child-process cleanup;
- integer conversion failure;
- overflow boundary;
- lock-contention behavior;
- deterministic ordering;
- partial I/O;
- interrupted I/O;
- permission failure;
- symlink/path traversal policy;
- all declared state transitions;
- unsafe contract violations where tools can detect them.

### Unit tests

Keep tests near the module they validate:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn queue_rejects_capacity_above_limit() {
        let result = QueueCapacity::new(REQUEST_COUNT_MAX + 1);

        assert_eq!(result, Err(QueueError::CapacityExceeded));
    }

    #[test]
    fn queue_accepts_capacity_at_limit() {
        let result = QueueCapacity::new(REQUEST_COUNT_MAX);

        assert_eq!(result, Ok(QueueCapacity(REQUEST_COUNT_MAX)));
    }
}
```

### Property and fuzz testing

Use property tests or fuzzing for parsers, serializers, protocol framing, arithmetic, state machines, and unsafe-adjacent code where the input space is too large for examples.

Useful categories:

- round-trip invariants;
- no panics on arbitrary bounded input;
- deterministic serialization;
- parser output respects domain constraints;
- resource limits hold under malformed input;
- state transitions preserve invariants.

### Concurrency testing

For synchronization-heavy code, use deterministic scheduling/model testing where practical. Do not assume ordinary tests will reliably find data races, deadlocks, or missed notifications.

---

## 21. Documentation and Comments

Comments explain **why**, constraints, safety contracts, and non-obvious tradeoffsâ€”not syntax already visible in code.

Bad:

```rust
// Increment the counter.
count += 1;
```

Better:

```rust
// Increment only after insertion succeeds so `count` remains a committed-item count.
count += 1;
```

### Documentation requirements

Document:

- public API behavior;
- error conditions;
- capacity/time limits;
- ownership and cancellation behavior;
- thread-safety and synchronization guarantees;
- state transitions;
- security-sensitive assumptions;
- `unsafe` preconditions under `# Safety`;
- panics only when a public function can panic;
- examples that compile where feasible.

### Rustdoc policy

Prefer documentation tests for simple public contracts. For an important crate:

```bash
cargo doc --workspace --no-deps
cargo test --doc --workspace
```

---

## 22. Dependencies and Features

Every dependency increases supply-chain, compatibility, build-time, and maintenance surface.

### Add dependencies only when they earn their cost

Prefer:

1. The Rust standard library.
2. Existing audited workspace utilities.
3. A small, mature, maintained crate with a narrow purpose.
4. A larger framework only when the operational benefit is clear.

### Rules

- Keep feature flags explicit and minimal.
- Default features should not silently enable heavyweight runtimes, network clients, native libraries, or unsafe behavior unless that is the crateâ€™s explicit purpose.
- Audit transitive dependencies for security-sensitive functionality.
- Pin lockfiles for binaries/applications.
- Treat build scripts (`build.rs`) and proc macros as code-execution dependencies.
- Do not download, compile, or execute arbitrary code at runtime as an installation shortcut.
- Keep optional features independently testable where practical.
- Avoid feature combinations that create undocumented behavior changes.

### Feature design

```toml
[features]
default = []
serde = ["dep:serde"]
metrics = ["dep:metrics"]
nightly = []
```

A `nightly` feature should not silently imply that the compiler itself is nightly. The crate root or build configuration must enforce and document that requirement.

---

## 23. Security Rules

Treat these as privileged boundaries:

- `unsafe`;
- FFI;
- dynamic library loading;
- process spawning;
- shell invocation;
- filesystem writes;
- archive extraction;
- deserialization;
- network requests;
- environment variables;
- credentials and key material;
- build scripts;
- proc macros;
- plugin loading;
- user-provided regular expressions;
- unbounded decompression;
- logging and telemetry.

### Core rules

- Validate untrusted input before privileged use.
- Use allowlists rather than blocklists where possible.
- Do not interpolate untrusted values into shell commands.
- Avoid `Command::new("sh").arg("-c")` and equivalents.
- Do not log tokens, passwords, private keys, session cookies, or full sensitive payloads.
- Set limits before parsing/decompression/allocation.
- Treat archive paths as traversal-sensitive.
- Use constant-time comparison for secret equality when required by the threat model.
- Avoid `unsafe` and FFI where safe alternatives meet requirements.
- Keep security decisions close to the capability boundary.

---

## 24. Review Checklist

### Safety

- [ ] Public and external inputs are validated.
- [ ] Internal invariants use assertions or types.
- [ ] All resource-consuming loops have a bound or termination proof.
- [ ] Retries, queues, task counts, caches, output, and input sizes are bounded.
- [ ] Integer conversions and arithmetic are checked where required.
- [ ] Resource ownership and cleanup are obvious.
- [ ] Mutation occurs at small, deliberate commit points.
- [ ] Errors are preserved with useful context.
- [ ] Async callbacks/results cannot commit stale state.
- [ ] Locks are not held across `.await` or blocking work.
- [ ] Filesystem, process, network, and serialization boundaries are constrained.
- [ ] Every `unsafe` block has a local safety proof.
- [ ] No secrets appear in logs or error messages.

### Performance

- [ ] The dominant resource has been identified or measured.
- [ ] Capacity and concurrency limits are explicit.
- [ ] Blocking work is isolated from async latency-sensitive paths.
- [ ] No untrusted input directly controls allocation capacity.
- [ ] Hot paths avoid unnecessary copies/allocations where measurement justifies it.
- [ ] Data structure choice matches ordering and lookup requirements.

### Developer experience

- [ ] Names state domain meaning and units.
- [ ] Ordinary functions are near or below 70 lines.
- [ ] Ordinary lines are near or below 100 columns.
- [ ] Modules read top-to-bottom.
- [ ] Public APIs, errors, limits, and cancellation behavior are documented.
- [ ] Output is deterministic where tests, persistence, or reproducibility require it.
- [ ] The nightly toolchain is pinned.
- [ ] Every unstable feature is justified and narrowly scoped.
- [ ] `cargo fmt`, Clippy, tests, and relevant dynamic analysis pass.

---

## 25. Anti-Patterns

```rust
// Unbounded task creation from untrusted input.
for request in requests {
    tokio::spawn(handle(request));
}

// Shell-injection surface.
std::process::Command::new("sh")
    .arg("-c")
    .arg(format!("git status {}", user_path.display()))
    .status()?;

// Panic for external input.
let config: Config = serde_json::from_slice(input).unwrap();

// Silent lossy conversion.
let length = remote_length as usize;

// Holding a synchronous lock across await.
let guard = state.lock().unwrap();
perform_async_work().await;
drop(guard);

// Unsafely treating untrusted bytes as initialized data.
let value = unsafe { *(bytes.as_ptr() as *const Header) };

// Unbounded cache.
cache.insert(key, value);

// Stale result can overwrite newer state.
let result = request().await;
state.current = result;

// Moving nightly baseline.
channel = "nightly"

// Cargo feature used as a substitute for a documented capability contract.
#[cfg(feature = "magic")]
fn behavior_changes_silently() {}
```

---

## 26. Reference Module

```rust
//! Bounded string normalization example.
//!
//! Safety contract:
//! - Inputs are bounded before allocation.
//! - Each item is validated before transformation.
//! - The function returns no partial result on failure.
//! - Output order equals input order.

const ITEM_COUNT_MAX: usize = 1_024;
const ITEM_SIZE_BYTES_MAX: usize = 4 * 1_024;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NormalizeError {
    ItemCountExceeded { item_count: usize },
    ItemSizeExceeded { item_index: usize, item_size_bytes: usize },
}

fn validate_items(items: &[String]) -> Result<(), NormalizeError> {
    if items.len() > ITEM_COUNT_MAX {
        return Err(NormalizeError::ItemCountExceeded {
            item_count: items.len(),
        });
    }

    for (item_index, item) in items.iter().enumerate() {
        if item.len() > ITEM_SIZE_BYTES_MAX {
            return Err(NormalizeError::ItemSizeExceeded {
                item_index,
                item_size_bytes: item.len(),
            });
        }
    }

    Ok(())
}

fn transform_items(items: &[String]) -> Vec<String> {
    let mut transformed = Vec::with_capacity(items.len());

    for item in items {
        transformed.push(item.to_uppercase());
    }

    assert_eq!(transformed.len(), items.len());

    transformed
}

pub fn normalize_items(items: &[String]) -> Result<Vec<String>, NormalizeError> {
    validate_items(items)?;

    Ok(transform_items(items))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_preserves_order() {
        let input = vec!["alpha".to_owned(), "beta".to_owned()];

        let result = normalize_items(&input);

        assert_eq!(result, Ok(vec!["ALPHA".to_owned(), "BETA".to_owned()]));
    }

    #[test]
    fn normalize_rejects_item_count_above_limit() {
        let input = vec![String::new(); ITEM_COUNT_MAX + 1];

        let result = normalize_items(&input);

        assert_eq!(
            result,
            Err(NormalizeError::ItemCountExceeded {
                item_count: ITEM_COUNT_MAX + 1,
            })
        );
    }
}
```

---

## 27. Compact Card

### Safety

- Use types to encode domain invariants.
- Validate external input and preserve contextual errors.
- Bound memory, time, retries, queues, tasks, recursion, files, output, and concurrency.
- Use checked conversion and arithmetic at important boundaries.
- Make ownership, cleanup, and mutation points obvious.
- Reject stale asynchronous results.
- Do not hold locks across `.await`.
- Keep `unsafe` minimal and prove it locally.
- Use direct argv process execution, not shell strings.
- Treat filesystem, network, serialization, environment, FFI, and build tooling as security boundaries.

### Performance

- Design capacities before optimizing.
- Measure the dominant cost.
- Batch expensive operations.
- Use bounded queues and concurrency.
- Choose data structures intentionally.
- Avoid untrusted allocation capacity.
- Do not use `unsafe` without a measured need and maintained proof.

### Developer experience

- Pin nightly by date.
- Justify every unstable feature.
- Use 4 spaces and a 100-column target.
- Keep ordinary functions near or below 70 lines.
- Prefer explicit state, errors, limits, and ownership.
- Keep module order predictable.
- Use `rustfmt`, Clippy, tests, Miri, and appropriate profiling tools.
- Make deterministic behavior the default where practical.

---

## Final Rule

A Tiger Style Rust codebase should make correctness visible.

A reviewer should be able to identify the programâ€™s limits, invariants, type boundaries, ownership model, state transitions, cleanup behavior, async cancellation policy, `unsafe` proofs, privileged operations, nightly assumptions, and failure behavior without reconstructing them from hidden conventions.

## Sources

- TigerBeetle, [Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)
- Rust, [The Rust Programming Language](https://doc.rust-lang.org/book/)
- Rust, [The Rustonomicon](https://doc.rust-lang.org/nomicon/)
- Rust, [The Unstable Book](https://doc.rust-lang.org/nightly/unstable-book/)
- rustup, [Overrides and toolchain files](https://rust-lang.github.io/rustup/overrides.html)
- rust-lang/miri, [Miri](https://github.com/rust-lang/miri/)