# rose.nvim MCP Client — The Wire You Must Not Break

The client is `lua/rose/native/mcp.lua` (336 lines, native mode, no plugins).
It is a Lua **stdio** MCP client. Everything below is read from that file —
not from memory, not from the spec. If the file changes, this reference is
stale: re-read the file.

## What the client does

- Spawns the server with `vim.system` and an **explicit argv array** — no
  shell. `opts.cmd` must be a table of NUL-free strings or spawn fails.
- Speaks one JSON-RPC 2.0 object per line on stdout; strips trailing `\r`;
  8 MiB default max message; anything larger, non-JSON, or not JSON-RPC 2.0
  closes the client (fail-closed).
- Captures stderr (last 8 KiB) and reports it when the process exits.
- Request timeout 30 s, initialize timeout 10 s. On timeout it sends
  `notifications/cancelled` first, then fails the call.
- Teardown: EOF on the server's stdin → SIGTERM → 500 ms → SIGKILL, then
  reaps. `M.stop()` closes every live client. This is the teardown contract
  your server's shutdown path must honor (see `references/threat-model.md`).

## The handshake (2025-11-25 era)

1. Client sends `initialize` with `protocolVersion: "2025-11-25"`,
   `capabilities: {}`, `clientInfo: { name = "rose.nvim", version = "0.2.0" }`.
2. The server MUST answer with an `InitializeResult` whose `protocolVersion`
   is one of `2025-11-25`, `2025-06-18`, `2025-03-26`, `2024-11-05` —
   anything else and the client closes with "unsupported MCP protocol
   version".
3. Client sends `notifications/initialized`. The client is ready.

The phlow Python server (`flow/mcp.py`) mirrors this: it advertises
`2025-11-25`, accepts `2025-06-18` and `2025-03-26` (rose additionally tolerates
`2024-11-05`), and negotiates unknown versions down to `2025-11-25` instead
of failing. Contract tests live in `phlow/tests/test_mcp_contract.py` — they
are the executable form of this section. The Rust port is
`phlow/crates/phlow-mcp`; it must pass the same contract.

## Server→client requests: only `ping`

The client answers `ping` and rejects everything else — sampling,
elicitation, roots, arbitrary editor commands — with `-32601` "Unsupported
server request". This is deliberate, and it is why the house rule says: **a
server MUST NOT depend on server→client requests.** Anything needing a human
decision is a refusal-with-reason plus an explicit flag on the retry. (The
2026-07-28 revision formalises this as MRTR; the client got there first.)

## What your server must satisfy to work with rose.nvim

1. stdio framing exactly: newline-delimited JSON-RPC, no embedded newlines,
   nothing but MCP messages on stdout, logs on stderr.
2. Answer `initialize` with a recognized `protocolVersion`.
3. Never require sampling, elicitation, or roots. Never send the client a
   request other than `ping` and expect an answer.
4. Honor `notifications/cancelled`.
5. Exit promptly on stdin EOF / SIGTERM. No hanging cleanup.

## The hard rule

**rose.nvim ↔ phlow wire formats stay stable across changes.** That means
framing, the handshake, method names, tool names, schemas, annotations, and
error semantics. Changing any of them is a **two-sided migration**:

- Change client and server together, in lockstep.
- Prove it with contract tests on both sides (extend
  `phlow/tests/test_mcp_contract.py` and add the rose-side equivalent)
  before either side merges.
- Never ship a server that speaks a revision the deployed client can't
  negotiate, and never ship a client that requires one the server can't.

Concretely: the 2026-07-28 stateless revision has **no `initialize`
handshake**. This client cannot speak it today — it always opens with
`initialize` and requires an `InitializeResult`. Adopting 2026-07-28 on this
link means rewriting the handshake in `mcp.lua` *and* the server, with the
contract tests proving the new handshake, or not doing it at all.
