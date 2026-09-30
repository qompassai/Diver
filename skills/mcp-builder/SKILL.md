---
name: mcp-builder
description: >-
  Build and harden MCP (Model Context Protocol) servers and clients for a Neovim-first stack: the phlow agent runtime's MCP server (Python now, Rust nightly port), the rose.nvim Lua stdio client, and new servers in Rust (rmcp), TypeScript (MCP SDK v2), or Python (FastMCP). Protocol-first: verify claims against the current spec, target 2025-11-25 while designing for 2026-07-28, and never break the rose/phlow wire format. Covers tool design (naming, inputSchema, outputSchema with structuredContent, annotations as untrusted hints), stdio vs Streamable HTTP transports, and adversarial security review as a first-class phase — RCE via tool arguments, command injection, credential leakage, prompt injection smuggled in tool output, zombie processes from bad teardown, supply-chain poisoning via third-party servers. Testing splits evenly between validation and adversarial cases.
license: Apache-2.0
compatibility: Rust nightly toolchain (cargo, rustc) for the phlow Rust path; Node 18+ with npm for the TypeScript path; Python 3.10+ with uv for the Python path; network access to crates.io, npm, and PyPI to verify SDK versions against the registry; MCP Inspector via npx for manual testing; Neovim 0.10+ with the rose.nvim tree for client-side work.
metadata:
  spec_target: "2025-11-25 (design forward-compatible with 2026-07-28)"
  primary_sdk: "rmcp 3.x (modelcontextprotocol/rust-sdk)"
  ts_sdk: "@modelcontextprotocol/server 2.x (split packages)"
  python_sdk: "mcp 2.x (FastMCP)"
  client: "rose.nvim lua/rose/native/mcp.lua (Lua stdio client)"
  test_split: "50% validation / 50% adversarial"
allowed-tools: Read Edit Bash
---

# MCP Builder

ELI5: MCP is LSP for tools. Where LSP lets any editor talk to any language
server with one protocol, MCP lets any AI client talk to any tool server
with one protocol. Your client is rose.nvim (Lua, speaks MCP over stdio);
your server is phlow (Python today, Rust nightly tomorrow). This skill is how
you build, change, and attack-review anything on that link — and any new MCP
server you write.

The deep version: an MCP server is an RCE-adjacent service by construction.
It converts natural-language intent from a model into actions on a machine.
The model is not a trust boundary. Every section below is written with that
in mind.

## The workflow

1. **Verify the protocol** — read `references/protocol-versions.md`, check
   the revision you are targeting against the spec and the registry. Never
   assert protocol behavior from memory.
2. **Check the wire rule** — if the change touches rose.nvim ↔ phlow, read
   `references/rose-client.md`. The wire format stays stable; changes are
   two-sided migrations with contract tests on both sides.
3. **Design the tools** — names, schemas, annotations. On paper first.
4. **Threat-model** — walk `references/threat-model.md` before writing the
   server, not after. Every threat gets a mechanism and a mitigation, in
   writing.
5. **Build** — Rust first (`references/rust-rmcp.md`); TypeScript
   (`references/typescript-sdk.md`) or Python (`references/python-fastmcp.md`)
   only with a concrete reason.
6. **Test 50/50** — half validation, half adversarial. The adversarial half
   maps to the threat catalog.
7. **Ship** — the checklist at the end.

## Start with the protocol, not the SDK

SDKs lag the spec, and upgrading a dependency is not the same as speaking a
new revision. The current spec revision is **2026-07-28** (stateless core: no
`initialize` handshake, no `Mcp-Session-Id`, per-request version, new
`server/discover` RPC). The released SDKs you can actually build on speak
**2025-11-25**. So the house rule:

**Target 2025-11-25. Design for 2026-07-28.** No server-side session state.
`outputSchema` + `structuredContent` on every tool. No dependence on
server→client requests (no sampling, no roots, no elicitation) — anything
needing a human is a refusal-with-reason plus an explicit flag on the retry.
Immutable tool list per connection. Never use a deprecated feature, even if
your SDK still accepts it.

`references/protocol-versions.md` has the verified revision table and the
registry commands to re-check SDK versions. Confirm with a live handshake,
never with a version number — `scripts/handshake.py <server-cmd>` performs
the 2025-11-25 initialize + tools/list smoke test over stdio, checking
framing, protocol version, the tool list, and bounded teardown.

## The hard rule: the rose ↔ phlow wire stays stable

Framing, handshake, method names, tool names, schemas, annotations, error
semantics — all stable across changes. `references/rose-client.md` documents
exactly what the Lua client expects, read from `mcp.lua` itself: stdio with
one JSON-RPC object per line, `initialize` handshake negotiating 2025-11-25,
only `ping` answered server→client, fail-closed on malformed input, bounded
teardown (EOF → SIGTERM → SIGKILL → reap).

If your change alters anything on that list, it is a two-sided migration:
client and server move together, proven by contract tests on both sides
(phlow has `tests/test_mcp_contract.py`; the rose side needs its equivalent),
or it doesn't happen. Never ship a server the deployed client can't
negotiate with.

## Design the tools first

- **Names are a contract.** `snake_case`, service-prefixed, action-oriented:
  `phlow_read_file`, not `read_file`. The client merges tool lists from many
  servers; unprefixed names collide. Never rename without a migration.
- **Descriptions are model-facing.** One or two sentences, narrow and
  unambiguous, matching the handler's actual behavior exactly. A description
  that over-promises is a prompt-injection surface.
- **`inputSchema`: required, root type `object`.** Describe every parameter,
  constrain it (`maxLength`, `pattern`, ranges, enums). The schema is the
  first validator and the model's documentation — write it as both. Then
  re-validate inside the handler anyway: a compromised client can send
  anything.
- **`outputSchema` + `structuredContent` on every tool.** Typed data, not
  prose the model re-parses. `outputSchema` is restricted to root type
  `object`; the structured result SHOULD conform to it. Always return
  `content` too, for clients that can't render structure.
- **Annotations are hints, never trust boundaries.** `readOnlyHint`,
  `destructiveHint`, `idempotentHint`, `openWorldHint` — set them honestly,
  and never let your client auto-approve a call because of them. The spec is
  explicit: never make trust decisions on annotations from untrusted servers.
- **Keep tools atomic.** One tool, one job. Expose primitives; let the agent
  compose.

Error semantics, from the spec — get this exactly right: failures that
originate **from the tool** go inside the result with `isError: true`, so the
model can see and self-correct. Failures **finding** the tool go as
protocol-level JSON-RPC errors. Both carry safe messages; the detail goes to
the server log only. Full rules in `references/mcp-core.md`.

## Threat-model before you build

This is a phase, not a paragraph. Walk the catalog in
`references/threat-model.md` and write down, per tool, which threats apply
and what stops them. The short version:

| Threat | Mechanism | Mitigation |
|--------|-----------|------------|
| RCE via tool args | Argument interpolated into a shell command | argv arrays everywhere; no shell; schema-constrain the domain |
| Malicious tool output | Untrusted data smuggles instructions to the model | `structuredContent` over prose; label untrusted data; never let output steer the plan unseen |
| Credential leakage | Keys in logs, errors, or tool args | Env-only credentials; redact in logs; safe error messages; canary-token tests |
| Supply-chain poisoning | Third-party server lies in tool descriptions/annotations | Pin by hash; audit source before first connect; never auto-approve on annotations |
| Zombie processes | Client dies without reaping the server | Ordered bounded teardown: close stdin → wait → SIGTERM → SIGKILL → reap; server exits on stdin EOF |
| Path traversal / size bombs | `../` escapes, `limit: 2^31` | Canonicalize + containment-check; bound every limit, byte count, and duration |
| HTTP exposure | DNS rebinding, open binds | Bind `127.0.0.1`; validate `Origin`; require `MCP-Protocol-Version` |

If you can't name the attacker for a tool, you haven't thought hard enough.
Think like the red teamer: the model is the confused deputy, the tool
description is the attacker's prose, and the annotations are lies until
proven otherwise.

## Build it

**Default: Rust with `rmcp`.** Official SDK (`modelcontextprotocol/rust-sdk`),
tokio-based, `rmcp` + `rmcp-macros` crates. The `#[tool]` macros generate
JSON Schema from your Rust types via `schemars` — one source of truth. Never
hand-roll JSON-RPC, never use unofficial crates. Layout, patterns, and Tiger
Style notes in `references/rust-rmcp.md`.

**TypeScript** when the target is JS-only: the SDK is split now —
`@modelcontextprotocol/server` 2.x, not the frozen 1.30.0 single package.
Zod is the schema source of truth. See `references/typescript-sdk.md`.

**Python** for the current phlow server (maintenance + parity, not new
investment): package `mcp` 2.x, FastMCP, Pydantic v2 models, `uv` for
everything. Any tool changed in Python must have its contract mirrored in
the Rust port or be explicitly marked Python-only with a reason — the client
must never see the two disagree. See `references/python-fastmcp.md`.

Transports: **stdio** for local single-client (the rose link), **Streamable
HTTP** for remote multi-client. stdio framing is unforgiving: newline-
delimited messages, no embedded newlines, nothing but MCP messages on
stdout, logs on stderr. HTTP+SSE is deprecated — do not build on it.

## Test it: half validation, half adversarial

**Validation half** — the contract holds: handshake negotiates the expected
revision; `tools/list` returns exactly the registered set; every tool
round-trips valid input; `structuredContent` validates against
`outputSchema`; pagination cursors advance; error cases return `isError: true`
with safe messages; cancellation is honored.

**Adversarial half** — the threat catalog, executable. Minimum: injection
strings in every string argument; path traversal and symlink escapes;
oversized inputs; prompt-injection payloads planted in tool-output fixtures;
wrong/missing credentials with a canary token asserting nothing leaks;
client crash mid-call; SIGKILL-the-client; lying annotations; malformed
framing; version mismatch in both directions asserting an explicit
`UnsupportedProtocolVersionError`, never silent misbehavior.

Run the full suite plus the MCP Inspector (`npx
@modelcontextprotocol/inspector`) against the built binary before every
merge. A red adversarial test blocks the merge exactly like a red validation
test.

## Ship checklist

- [ ] Protocol revision verified against spec + registry today, not from memory
- [ ] Wire stability: no unilateral framing/handshake/schema changes (or a
      two-sided migration with contract tests on both sides)
- [ ] Every tool: name, description, inputSchema, outputSchema,
      structuredContent, honest annotations
- [ ] Threat walk written down per tool; mitigations in code, not comments
- [ ] 50/50 test split green, including the ten adversarial minimums
- [ ] No credentials in schemas, logs, or error messages (canary test passes)
- [ ] Teardown proven: EOF/SIGTERM exits promptly, no orphans, no zombies
- [ ] Inspector run clean against the final binary
- [ ] Rust: `cargo build` zero warnings; TS: `tsc` strict clean; Python:
      `py_compile` clean

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. The envelope for this skill carries its bundled resources:

<skill_resources>
<file>references/protocol-versions.md</file>
<file>references/mcp-core.md</file>
<file>references/rust-rmcp.md</file>
<file>references/typescript-sdk.md</file>
<file>references/python-fastmcp.md</file>
<file>references/rose-client.md</file>
<file>references/threat-model.md</file>
<file>scripts/handshake.py</file>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** recommended. Seven phases (verify protocol, check
  the wire, design tools, threat-model, build, 50/50 test, ship) is a long
  trajectory for one session. Delegate the whole loop to a subagent with
  this skill; it returns the ship checklist plus the per-tool threat walk.
