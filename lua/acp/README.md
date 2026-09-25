# `lua/acp` — Agent Protocols in Diver

This directory implements Diver's integrations with two industry protocols
that unfortunately share the acronym **ACP**, and documents a third one.
Read this first, because the name collision causes real confusion:

| # | Protocol | Home | What it standardizes |
|---|----------|------|----------------------|
| 1 | **Agent Context Protocol** | [prmichaelsen/agent-context-protocol](https://github.com/prmichaelsen/agent-context-protocol) | How an agent *remembers*: a documentation-first convention of markdown knowledge files (`agent/`) that persists project understanding across sessions. **No wire protocol, no RPC, no running process.** |
| 2 | **Agent Client Protocol** | [agentclientprotocol.com](https://agentclientprotocol.com) ([spec repo](https://github.com/agentclientprotocol/agent-client-protocol), [registry](https://github.com/agentclientprotocol/registry)) | How an *editor* drives a *coding agent*: JSON-RPC 2.0 over stdio — spawn agent, handshake, open session, send prompts, stream updates, approve tool use. The "LSP for agents". |
| 3 | **Agent Communication Protocol** | [agentcommunicationprotocol.dev](https://agentcommunicationprotocol.dev/introduction/welcome) | How *agents talk to each other*: a RESTful API (OpenAPI-defined) for agent discovery, manifests, and run lifecycle — sync, async, and streaming, stateful or stateless. A Linux Foundation project; BeeAI is its reference implementation. |

Diver integrates **#1** (via `context.lua`) and **#2** (via everything else in
this directory). Diver does **not** implement #3; it is documented here so
the three are never confused again.

```
                    ┌─────────────────────────────────────────┐
                    │            Agent Context Protocol       │  #1
                    │   markdown knowledge: agent/commands,   │
                    │   agent/patterns, agent/design ...      │  "what the agent knows"
                    └────────────────────┬────────────────────┘
                                         │ read by
                    ┌────────────────────▼────────────────────┐
                    │              Your editor                │
                    │          (Diver / Zed / IDE)            │  the Client
                    └───────┬────────────────────────┬────────┘
                            │ Agent Client Protocol  │
                            │ JSON-RPC over stdio    │  #2
                    ┌───────▼────────┐    ┌──────────▼───────┐
                    │  Coding agent  │◄──►│  Coding agent    │
                    │  (Claude/Codex │ Agent Communication  │  #3
                    │   /Gemini...)  │ Protocol (REST)      │
                    └───────┬────────┘    └──────────────────┘
                            │  MCP (tools: fs, shell, web...)
                            ▼
                      tool servers
```

MCP appears in the diagram because it answers the fourth question people
ask: if #2 is editor↔agent and #3 is agent↔agent, **MCP is agent↔tools**.
The Agent Client Protocol even lets a client hand MCP server configs to the
agent at `session/new`. The four protocols tile the space without overlap.

---

## 1. Agent Context Protocol — the agent's memory

**Source:** <https://github.com/prmichaelsen/agent-context-protocol>

> "Documentation-first development methodology that enables AI agents to
> understand, build, and maintain complex software projects through
> structured knowledge capture."

### The problem it solves

Every agent session starts amnesiac. Project conventions, past decisions,
the plan of record, and hard-won gotchas live in chat history that
evaporates — or in a human's head. The Agent Context Protocol turns that
implicit knowledge into explicit, machine-readable markdown that persists
across sessions, agents, and models.

### How it works

It is a **convention, not a network protocol**. There is nothing to run,
no server, no handshake. A project adopts ACP by keeping a structured
`agent/` directory:

```
my-project/
├── agent/
│   ├── commands/        # Executable directives, flat with dot notation
│   │   ├── acp.status.md
│   │   ├── git.commit.md
│   │   └── firebase.deploy.md
│   ├── patterns/        # Enforced best practices (portable packages)
│   ├── design/          # Design documents
│   ├── tasks/           # Task tracking (task-N-*.md)
│   ├── scripts/         # Helper scripts commands may invoke
│   ├── artifacts/       # Templates: glossary, reference, research
│   └── manifest.yaml    # Local package tracking
├── AGENT.md             # Entry point: tells agents how to use this directory
└── ...
```

Two flagship mechanisms:

- **Commands** (`agent/commands/`). Markdown files the agent treats as
  directives. When an agent reads one it enters *script execution mode*:
  it follows the file's steps the way an interpreter follows a script —
  conditionals, branching, loops, subroutines, argument handling, invoking
  external programs, and verification steps. Commands are invoked with
  `@namespace.command` syntax, e.g. `@git.commit` resolves to
  `agent/commands/git.commit.md`. (Older nested layout
  `agent/commands/git/commit.md` was flattened to dot notation.)
- **Patterns** (`agent/patterns/`). Best-practice documents distributed as
  publishable, consumable, portable *patterns packages* — a team can ship
  "how we write APIs" once and every project consumes it.

### Local vs global

- **Local** (default): packages installed into the project's own `agent/`,
  version-controlled with the project. Preferred for production.
- **Global**: `~/.acp/` holds `AGENT.md`, `agent/` (merged commands,
  patterns, designs, scripts), `packages/`, `projects/`, and a
  `manifest.yaml` tracking installed packages with versions and checksums.
  Global commands like `@acp.init` discover what's available anywhere.
- **Local always takes precedence over global** for the same command name.

### Diver's integration — `context.lua`

Diver implements the *lightweight, project-local* slice of this protocol:
scaffolding and browsing a project's `agent/` knowledge directory.

| Function | Command | Behavior |
|----------|---------|----------|
| `context.scaffold(root?)` | `:AcpContextScaffold` | Creates `agent/` with `SPEC.md`, `PLAN.md`, `DECISIONS.md` templates (never overwrites existing files; mode `700`) |
| `context.list(root?)` | — | Lists context files, sorted, bounded at 2000 entries |
| `context.browse(root?, how?)` | `:AcpContextBrowse` | Opens a picker (fzf when available, `vim.ui.select` otherwise) to jump to a context file |

Deliberate scoping notes, stated in the module header:

- It is **documentation tooling only** — no RPC, no subprocess.
- It is named `context.lua`, not `acp.lua`, precisely so the two
  protocols sharing the "ACP" acronym never collide in a `require(...)`
  path. `require('acp.context')` ≠ the Agent Client Protocol.

---

## 2. Agent Client Protocol — the editor↔agent wire

**Sources:** <https://agentclientprotocol.com>
([overview](https://github.com/agentclientprotocol/agent-client-protocol/blob/HEAD/docs/protocol/v1/overview.mdx),
[registry](https://github.com/agentclientprotocol/registry))

Originated at Zed. Before it, every coding agent exposed its own
undocumented wire format and every editor wrote a bespoke integration —
the exact fragmentation LSP solved for language servers. ACP is the same
idea one layer up: **a shared contract between a client (historically an
editor) and a sealed, finished coding agent.**

### Roles

- **Client** — drives. Spawns the agent as a subprocess, negotiates
  capabilities, opens sessions, sends prompts, renders streamed updates,
  and answers permission requests. *Diver is a client.*
- **Agent** — a program that uses generative AI to autonomously modify
  code (Claude Code, Codex, Gemini CLI, Cursor, Opencode, …). It owns its
  internal loop: the client never injects a system prompt or custom tools.
  ACP standardizes the UI seam around the agent, not the agent itself.

### Transport

**JSON-RPC 2.0 over the agent process's stdio**, one JSON object per
newline-delimited line. Two message kinds: *methods* (request/response)
and *notifications* (fire-and-forget). Note the deliberate difference
from LSP: **no `Content-Length` headers** — framing is pure NDJSON.

### Lifecycle

```
Client ──► Agent:  initialize            negotiate versions + capabilities
Client ──► Agent:  authenticate          only if the agent requires it
Client ──► Agent:  session/new           create session (cwd, MCP servers)
    …or    session/load                  resume with history replay
                                           (needs loadSession capability)
Client ──► Agent:  session/prompt        send a user turn
Agent  ──► Client: session/update        notifications: streamed text chunks,
                                           thoughts, tool calls, plan updates
Agent  ──► Client: session/request_permission
                                           blocks until the client answers
                                           allow/deny
Client ──► Agent:  session/cancel        notification; agent aborts the turn
Agent  ──► Client: session/prompt → { stopReason }
                                           turn ends; repeat from prompt
```

Capability negotiation happens at `initialize` in both directions, so
optional surface (`session/load`, `session/resume`, `session/set_mode`,
`session/list`, …) is only used when both sides advertise it. Agents can
also call *back into* the client: `fs/read_text_file`,
`fs/write_text_file`, `terminal/*`, and `session/request_permission`.

### Why it matters

One integration drives ~35 registered agents. Agent authors implement one
protocol instead of one per editor; editors, harnesses, and tool
middleware (permissions, session management, transcript storage) become
agent-agnostic. Bridges exist for agents that don't speak ACP natively
(they wrap a CLI or model API and re-expose it as ACP).

### Diver's integration — everything else in this directory

Diver is a full ACP **client**. Module map:

| Module | Responsibility |
|--------|---------------|
| `init.lua` | `setup()` entry point. Requires `commands` (which registers user commands), installs a `VimLeavePre` autocmd that stops all sessions. No I/O at require time. |
| `registry.lua` | Agent discovery. Two sources merged: `M.manual` (hand-maintained: `ollama` and `rose` bridges via `acp-bridge`, native `hf-inference-acp`; unverified entries warn loudly, never silently) plus the **official registry.json**, fetched on demand from `cdn.agentclientprotocol.com` and cached under `stdpath('cache')/acp/`. `:AcpRegistryRefresh` updates the cache. |
| `rpc.lua` | The transport: spawns the agent with `vim.system`, NDJSON framing on stdout, request/notification/reply dispatch, handler table for agent→client methods. Bounded: 8 MiB max line, 256 max pending requests. Owns framing only — no protocol semantics. |
| `protocol.lua` | Method-name constants and pure param builders. No I/O, no state. Pins `PROTOCOL_VERSION = 1` and identifies Diver as `qompassai-diver`. |
| `session.lua` | Session lifecycle: spawn → `initialize` (10 s handshake timeout) → `session/new` → prompt turns → cancel → teardown. Max 8 concurrent sessions. Wires `session/update` → UI/store and `permission/request` → permission prompt. |
| `permissions.lua` | Default `on_permission` handler: `vim.ui.select` Allow/Deny, 60 s bounded wait, **default deny** on timeout or dismissal. The RPC reply is only sent after the user answers. |
| `store.lua` | Transcript persistence: SQLite (`sqlite3` CLI) database at `stdpath('data')/acp/transcripts.db`, one row per user/assistant message. Silent warn (not crash) if `sqlite3` is missing — see `:checkhealth acp`. |
| `ui.lua` | Chat rendering: per-session `acp://<agent>/<key>` buffers (`filetype=acpchat`, `buftype=nofile`), streaming append of updates, tool-call summaries, auto-scroll, 20k-line cap. |
| `commands.lua` | User commands (below). Tracks the most recent session as the implicit target. |
| `health.lua` | `:checkhealth acp`: verifies `curl` (registry refresh), `sqlite3` (transcripts), and that every registered agent's executable exists, flagging unverified invocations. |

User commands:

| Command | Effect |
|---------|--------|
| `:AcpAgents` | Pick an agent from the registry and start a session |
| `:AcpStart [name]` | Start a named session (with completion) |
| `:AcpPrompt [text]` | Send a prompt to the active session (prompts for input when empty) |
| `:AcpCancel` | Cancel the active turn |
| `:AcpStop` | Stop the active session and close its buffer |
| `:AcpRegistryRefresh` | Re-fetch the official agent registry |
| `:AcpContextScaffold` | *(Agent Context Protocol)* scaffold `agent/` |
| `:AcpContextBrowse` | *(Agent Context Protocol)* browse `agent/` files |

Note the last two belong to protocol #1 — they live on the same command
namespace for discoverability, which is exactly why this README exists.

---

## 3. Agent Communication Protocol — the agent↔agent wire

**Source:** <https://agentcommunicationprotocol.dev/introduction/welcome>

A Linux Foundation open standard (developed alongside **BeeAI**, its
reference platform for discovering, testing, and sharing agents).
Where the Agent *Client* Protocol connects an editor to one agent, the
Agent *Communication* Protocol connects **agents to each other** —
across frameworks (BeeAI, LangChain, CrewAI, custom code), teams, and
organizations.

### The problem it solves

Enterprises run hundreds of agents built in isolation on incompatible
stacks. Point-to-point integrations don't scale; every pair of
frameworks needs custom glue. This protocol is the shared,
implementation-agnostic bridge: agents expose a standardized **RESTful
API**, and only minimal conformance is required for interop.

### Core concepts

- **Agent as a service.** An agent is a software service communicating
  through multimodal messages (all modalities, MIME-typed content),
  driven primarily by natural-language inputs and outputs.
- **Manifest.** Each agent publishes a manifest describing itself —
  the basis for **discovery**, which works both *online* (registry /
  directory lookup) and *offline* (metadata embedded in distribution
  packages).
- **Runs.** The execution unit. REST operations create, inspect, resume,
  and cancel runs, and stream run events — supporting **synchronous,
  asynchronous, and streaming** interactions, in **stateful or stateless**
  patterns, including long-running tasks.
- **Contract-first.** The normative contract is an **OpenAPI 3.1**
  document (`openapi.yaml`); the human reference docs are generated from
  it. Normativity lives in schemas, required fields, enums, and status
  codes rather than prose.
- **SDKs, not required.** The API is plain REST — no SDK needed — with
  official Python and TypeScript SDKs for convenience.

### Diver's relationship to it

**None, currently.** Diver neither serves nor consumes this protocol.
It is documented here for one reason: when someone says "ACP" in the
agent-interop conversation, they may mean this — and reaching for
`lua/acp/` expecting REST endpoints would be a category error.

---

## Disambiguation cheat sheet

Three protocols, one acronym, three different jobs:

- "How does the agent **remember** project knowledge?" →
  **Agent Context Protocol** — markdown files, no network.
- "How does my **editor drive** a coding agent?" →
  **Agent Client Protocol** — JSON-RPC over stdio, client spawns agent.
- "How do **agents talk to each other**?" →
  **Agent Communication Protocol** — REST API, OpenAPI contract.
- "How does an agent **call tools**?" → **MCP** — the fourth protocol,
  complementary to all three.

Two further collisions worth knowing, so you don't chase the wrong repo:

- In Diver, `require('acp.context')` is the **Context** protocol and
  everything else under `require('acp.*')` is the **Client** protocol.
  The file is deliberately named `context.lua`, not `acp.lua`.
- An unrelated community project (`kickflip73/agent-communication-protocol`)
  also calls itself "ACP" — it is a zero-server P2P agent-messaging
  experiment, **not** the Linux Foundation standard documented in
  section 3.

## References

- Agent Context Protocol — <https://github.com/prmichaelsen/agent-context-protocol>
- Agent Client Protocol — <https://agentclientprotocol.com> ·
  [spec](https://github.com/agentclientprotocol/agent-client-protocol) ·
  [registry](https://github.com/agentclientprotocol/registry)
- Agent Communication Protocol — <https://agentcommunicationprotocol.dev/introduction/welcome>
- MCP (agent↔tools, for orientation) — <https://modelcontextprotocol.io>
