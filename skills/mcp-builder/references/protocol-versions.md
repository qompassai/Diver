# MCP Protocol Versions — Verified 2026-09-29

Read this before writing or reviewing any MCP code. The spec moves; SDKs lag
the spec. Never assert a protocol behavior from memory — check the sources
below and confirm with a live handshake, never with a version number.

## Revision history (primary source: modelcontextprotocol.io)

| Revision   | Status  | What changed (verified) |
|------------|---------|--------------------------|
| 2024-11-05 | Final   | Initial public revision. HTTP+SSE transport. |
| 2025-03-26 | Final   | Tool annotations, sampling refinements. |
| 2025-06-18 | Final   | Structured tool output (`outputSchema` + `structuredContent`), elicitation, resource links in tool results. **Removed JSON-RPC batching.** Servers classified as OAuth Resource Servers; Resource Indicators (RFC 8707) required. `MCP-Protocol-Version` header required on HTTP requests. Dedicated security best-practices page. |
| 2025-11-25 | Final   | Tasks extension (`tasks/*`), `ToolExecution.taskSupport` (`forbidden`/`optional`/`required`), tool icons. `initialize` handshake + `Mcp-Session-Id` still the negotiation mechanism. |
| 2026-07-28 | Current | **Stateless core.** `initialize` handshake and `Mcp-Session-Id` are gone. Every request carries its protocol version in `_meta["io.modelcontextprotocol/protocolVersion"]` (and the `MCP-Protocol-Version` header over Streamable HTTP). New `server/discover` RPC advertises capabilities up front; every result carries `resultType`. Server-initiated requests replaced by the Multi Round-Trip Request (MRTR) pattern. `ping`, `logging/setLevel`, `resources/subscribe` removed. Roots, Sampling, Logging deprecated under a 12-month deprecation policy. Tasks and MCP Apps are formal extensions. List responses carry cache hints. Tool list MUST NOT vary per-connection, but MAY vary by the authorization on the request (credentials are per-request input, not connection state). |

Primary sources checked 2026-09-29:

- Transports: https://spec.modelcontextprotocol.io/specification/draft/basic/transports/
  (two standard transports: stdio, Streamable HTTP; HTTP+SSE deprecated)
- Tool/result JSON Schema:
  https://raw.githubusercontent.com/modelcontextprotocol/specification/main/schema/2025-11-25/schema.json
  (Tool shape, `outputSchema`, `ToolAnnotations` hint semantics, `isError` semantics)
- 2026-07-28 changelog: https://modelcontextprotocol.io/specification/2026-07-28/changelog
  (verified via direct changelog quotations in third-party ADRs; the spec
  site's per-page tools routes returned HTTP 500 on 2026-09-29 — re-check them
  directly before relying on fine detail)

## What the SDKs actually speak (re-check at the registry, not a changelog)

"Upgrading the dependency is not the same as speaking the new revision."
Confirm with a live handshake.

```sh
# Rust (official SDK: modelcontextprotocol/rust-sdk, crate `rmcp`)
curl -s https://crates.io/api/v1/crates/rmcp | jq -r .crate.max_stable_version
# TypeScript
curl -s https://registry.npmjs.org/@modelcontextprotocol%2Fserver | jq -r '.["dist-tags"].latest'
# Python
curl -s https://pypi.org/pypi/mcp/json | jq -r .info.version
# Go
curl -s https://proxy.golang.org/github.com/modelcontextprotocol/go-sdk/@latest
```

Known landscape as of 2026-09-29 (secondary sources, re-verify):

- **Rust `rmcp` 3.x** (official, Apache-2.0, tokio): implements 2026-07-28
  while staying compatible with 2025-11-25 and earlier. `ProtocolVersion::LATEST`
  was `V_2025_11_25` in 3.1.4; `V_2026_07_28` exists — the version is selected
  by hand, not by upgrading.
- **TypeScript v2 split**: the old single `@modelcontextprotocol/sdk` is frozen
  at 1.30.0 (legacy path, speaks 2025-11-25). New packages
  `@modelcontextprotocol/server` / `/client` / `/core` 2.0.0 speak 2026-07-28.
  TS and Go need an explicit opt-in to the new revision.
- **Python `mcp` 2.x** (FastMCP): speaks 2026-07-28 with legacy back-compat —
  flips on upgrade.

## House rule for this skill

**Target 2025-11-25, design for 2026-07-28.** That means:

1. No server-side session state. Nothing on the server survives between tool
   calls that the caller could not pass back as an argument.
2. `outputSchema` + `structuredContent` on every tool. Results are typed data,
   not prose the model re-parses.
3. No reliance on server→client requests (no sampling, no roots, no
   elicitation). Anything needing a human decision is a refusal-with-reason
   plus an explicit flag on the retry — the exact shape MRTR formalises.
4. Immutable tool list per connection (may still vary by request credentials).
5. Never use a feature marked deprecated in the current revision, even if the
   SDK you are on still accepts it.

The rose.nvim ↔ phlow link is pinned to whatever revision both sides
negotiate today. Changing the negotiated revision is a two-sided migration:
client and server move together, with a conformance test proving the
handshake, or not at all. See `references/rose-client.md`.
