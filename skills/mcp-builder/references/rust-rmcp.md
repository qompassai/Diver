# Rust MCP Servers with `rmcp` (Primary Path)

This is the primary server path for Matt's stack: phlow's MCP server is being
ported from Python to Rust nightly on phlow's `rust` branch. New MCP servers
start here unless there is a concrete reason to use another language.

## The SDK: `rmcp`

- **Official SDK**: `modelcontextprotocol/rust-sdk` (originally `4t145/rmcp`),
  Apache-2.0, tokio-based. Crates: `rmcp` (protocol implementation) and
  `rmcp-macros` (procedural macros).
- **Version selection is explicit.** `rmcp` 3.x implements the 2026-07-28
  revision while staying compatible with 2025-11-25 and earlier — but the
  protocol version is chosen in code (`ProtocolVersion::V_2025_11_25` /
  `V_2026_07_28`), not by upgrading the dependency. Re-check the latest at
  the registry before pinning:
  `curl -s https://crates.io/api/v1/crates/rmcp | jq -r .crate.max_stable_version`
- **Do not hand-roll JSON-RPC over `serde_json`.** The SDK is the audited
  framing, handshake, and transport layer. Your code is the tools.
- **Do not use unofficial crates** (`mcp-sdk`, `mcpr`, forks) — smaller user
  base means you own the spec drift.

## Project layout

One binary per server. Keep the protocol glue thin and the tools isolated:

```text
src/
├── main.rs        # arg parsing, transport selection, wiring — no tool logic
├── server.rs      # ServerHandler impl: tool/resource registration only
├── tools/         # one module per tool group (fs.rs, exec.rs, …)
│                 # each tool: input struct, output struct, handler fn
├── policy.rs      # capability flags, allow-lists, bounds (limits, timeouts)
├── audit.rs       # structured audit log (stderr or file, JSONL)
└── transport/     # stdio.rs, http.rs — transport setup only
tests/
└── conformance.rs # protocol conformance + adversarial cases (see below)
```

Why this shape: `main.rs` stays boring (easy to audit), every tool is
independently reviewable, and `policy.rs`/`audit.rs` make the security
posture visible instead of scattered through handlers.

## Tool definition pattern

```rust
use rmcp::macros::{tool, tool_handler, tool_router};
use rmcp::model::CallToolResult; // check item paths against your pinned rmcp docs
use schemars::JsonSchema; // needs the `schemars` feature flag (not default)
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, JsonSchema)]
pub struct ReadFileInput {
    /// Path relative to the allowed root. Canonicalized and
    /// containment-checked in the handler — the schema is the
    /// floor, not the ceiling.
    pub path: String,
    #[serde(default = "default_limit")]
    pub limit: u32,
}

#[derive(Debug, Serialize, JsonSchema)]
pub struct ReadFileOutput {
    pub path: String,
    pub content: String,
    pub truncated: bool,
}

#[derive(Debug, Clone)]
struct FsTools;

#[tool_router]
impl FsTools {
    #[tool(
        name = "phlow_read_file",
        description = "Read a text file under the allowed root. \
                       Returns content and whether it was truncated.",
        annotations(read_only_hint = true)
    )]
    async fn read_file(&self, input: Parameters<ReadFileInput>) -> ... {
        // 1. Re-validate: canonicalize, containment-check, bound limit.
        // 2. Do the work with a timeout.
        // 3. Return structured output; tool-originated failures become
        //    isError results with safe messages, detail to the audit log.
        //    Never panic across a tool call — a panic is uncontrolled teardown.
    }
}

#[tool_handler]
impl ServerHandler for FsTools {
    // …capabilities, server info…
}
```

Notes:

- The `#[tool]` macro generates the JSON Schema from your Rust types via
  `schemars` — one source of truth for the schema, no hand-written JSON.
- `description` is model-facing prose: precise, no promises the handler
  doesn't keep.
- Every tool gets `outputSchema`-backed structured output. If the macro
  surface doesn't expose `structuredContent` cleanly in your pinned version,
  say so in the code comment and file it — don't silently return prose-only.
- Errors: tool-originated failures become `isError: true` results with safe
  messages (see `references/mcp-core.md`). Never `panic!` across a tool call —
  a panic is an uncontrolled teardown; return the error.

## Transports

- **stdio** (local, single client — the rose.nvim ↔ phlow link): the client
  spawns your binary; you read JSON-RPC from stdin, write to stdout, log to
  stderr. Nothing else touches stdout. Handle EOF-on-stdin as shutdown.
- **Streamable HTTP** (remote): bind `127.0.0.1` by default, validate
  `Origin`, require `MCP-Protocol-Version`. Auth before work.

## Testing (the 50/50 split)

`tests/conformance.rs` plus unit tests per tool module:

- **Validation half**: handshake succeeds and negotiates the expected
  revision; `tools/list` returns the exact registered set; each tool round-
  trips valid input; `outputSchema` validates against actual
  `structuredContent`; pagination cursors advance; error cases return
  `isError: true` with safe messages.
- **Adversarial half**: the ten cases in `references/threat-model.md`
  (injection strings, traversal, size bombs, prompt-injection fixtures,
  credential canary, client crash, SIGKILL-the-client, lying annotations,
  malformed framing, version mismatch).
- Run `cargo test` and the MCP Inspector
  (`npx @modelcontextprotocol/inspector`) against the built binary before
  every merge. `cargo build` warnings are failures — fix them, don't allow
  them.

## Tiger Style notes for this codebase

- Explicit contracts on every tool handler: document preconditions (what the
  input guarantees after validation) and postconditions (what the output
  guarantees) in doc comments. `debug_assert!` the postconditions.
- Bounded work: every I/O has a timeout, every list has a limit, every
  buffer has a cap. Unbounded reads are bugs.
- No hidden behavior: no ambient config files, no env-var side channels
  beyond the documented credential variables, no network calls a tool
  description doesn't disclose.
