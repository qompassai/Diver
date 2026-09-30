# MCP Core Design Rules

The durable design rules for any MCP server. Adapted from the upstream
best-practices guide, corrected against the 2025-11-25 JSON Schema and the
current transports spec (verified 2026-09-29). Language-specific SDK notes
live in `references/rust-rmcp.md`, `references/typescript-sdk.md`, and
`references/python-fastmcp.md`.

## Tool design

- **Names are a contract.** `snake_case`, service-prefixed, action-oriented:
  `github_create_issue`, not `create_issue`. The prefix exists because the
  client merges tool lists from many servers; unprefixed names collide.
  Never rename a tool without a migration — clients and agents key on names.
- **Descriptions are for the model.** One or two sentences that narrowly and
  unambiguously describe what the tool does. The description must match the
  actual behavior exactly; a description that promises more than the handler
  delivers is a prompt-injection surface (threat 2 in `threat-model.md`).
- **`inputSchema`: required, root type `object`.** Every parameter gets a
  description, constraints (`maxLength`, `pattern`, `minimum`/`maximum`,
  `enum`), and examples where they clarify. The schema is the first validator
  and the model's documentation — write it like both.
- **`outputSchema` + `structuredContent` on every tool.** `outputSchema` is
  restricted to root type `object`. The structured result SHOULD conform to
  it. Always return `content` too (unstructured, for clients that can't render
  structure), but put the machine-readable truth in `structuredContent`.
- **Annotations are hints, not guarantees.** `readOnlyHint` (default false),
  `destructiveHint` (default true; meaningful only when `readOnlyHint` is
  false), `idempotentHint` (default false), `openWorldHint` (default true).
  Set them honestly — they drive UI and risk display — but the spec is
  explicit: clients must never make trust decisions on annotations from
  untrusted servers. Your own client must not either.
- **Keep tools atomic and focused.** One tool, one job. Workflow tools that
  compose three API calls are fine when the composition is the product; don't
  build them to hide a bad schema. When in doubt, expose the primitives and
  let the agent compose.

## Response formats and pagination

- Return both: `content` (human-readable text) and `structuredContent`
  (typed JSON). Never make the model re-parse prose to recover structure you
  already had.
- Paginate every listing tool. Respect `limit`, return `has_more` /
  `next_cursor` / `total_count`, default 20–50 items, never load the full set
  into memory. Bound response bytes as well as item counts.

## Error handling (spec semantics — get this exactly right)

From the 2025-11-25 schema, `CallToolResult.isError`:

- Errors that originate **from the tool** (bad argument, upstream API 500,
  file not found) go **inside the result object** with `isError: true` —
  NOT as a protocol-level JSON-RPC error. The model needs to see the failure
  to self-correct; a protocol error hides it.
- Errors in **finding** the tool, or the server not supporting tool calls at
  all, go as **MCP protocol-level error responses** (standard JSON-RPC codes).

And in both cases: helpful but not revealing. Say what failed and what to try
next; never leak stack traces, paths, credentials, or internal topology.
Log the detailed reason server-side (stderr), return the safe message
client-side.

## Transports

Two standard transports. Pick one deliberately; don't support both unless
you have a reason.

|              | stdio | Streamable HTTP |
|--------------|-------|-----------------|
| Deployment   | Local, single client | Remote, many clients |
| Setup        | Client spawns subprocess | Independent service |
| Real-time server→client | No (use MRTR pattern) | Yes, via SSE streams |
| Auth         | Process boundary | OAuth 2.1 / tokens required |

**stdio framing rules** (from the spec — violations corrupt the stream):

- Messages are JSON-RPC, newline-delimited, and MUST NOT contain embedded
  newlines.
- The server MUST NOT write anything to stdout except valid MCP messages.
  All logging goes to stderr as UTF-8. One stray `print()` on stdout and the
  client parses garbage.
- The client launches the server, writes requests to its stdin, and tears
  down by closing stdin and terminating the subprocess.

**HTTP+SSE (the old 2024-11-05 transport) is deprecated.** Do not build on it.
If you must interoperate with an old server, the spec's backwards-compat
guide covers hosting both endpoints — read it there, not here.

## Security baseline (every server, no exceptions)

The full catalog is `references/threat-model.md`. The non-negotiable floor:

1. No shell interpolation of tool arguments — argv arrays everywhere.
2. Credentials from the environment, never from tool arguments; redact in
   logs; safe messages in `isError` results.
3. Schema validation on input AND re-validation in the handler.
4. Path canonicalization under an allowed root; bounded limits and sizes.
5. Bounded, ordered teardown: close stdin → wait → SIGTERM → SIGKILL → reap.
6. HTTP servers: bind `127.0.0.1`, validate `Origin`, require the
   `MCP-Protocol-Version` header.

## Naming

- Rust: `{service}_mcp` crate/binary (e.g. `phlow_mcp`).
- TypeScript: `{service}-mcp-server` (e.g. `phlow-mcp-server`).
- Python: `{service}_mcp` (e.g. `phlow_mcp`).
- No version numbers in names. Names are stable identifiers — see the wire
  stability rule in `references/rose-client.md`.
