# `lua/ai` — Agent Protocols in Diver

This directory implements Diver's integrations with two industry protocols
that unfortunately share the acronym **ACP**, and documents a third one.
Read this first, because the name collision causes real confusion:

| # | Protocol | Home | What it standardizes |
|---|----------|------|----------------------|
| 1 | **Agent Context Protocol** | [prmichaelsen/agent-context-protocol](https://github.com/prmichaelsen/agent-context-protocol) | How an agent *remembers*: a documentation-first convention of markdown knowledge files (`agent/`) that persists project understanding across sessions. **No wire protocol, no RPC, no running process.** |
| 2 | **Agent Client Protocol** | [agentclientprotocol.com](https://agentclientprotocol.com) ([spec repo](https://github.com/agentclientprotocol/agent-client-protocol), [registry](https://github.com/agentclientprotocol/registry)) | How an *editor* drives a *coding agent*: JSON-RPC 2.0 over stdio — spawn agent, handshake, open session, send prompts, stream updates, approve tool use. The "LSP for agents". |
| 3 | **Agent Communication Protocol** | [agentcommunicationprotocol.dev](https://agentcommunicationprotocol.dev/introduction/welcome) | How *agents talk to each other*: a RESTful API (OpenAPI-defined) for agent discovery, manifests, and run lifecycle — sync, async, and streaming, stateful or stateless. A Linux Foundation project; BeeAI is its reference implementation. |
| 4 | **Agent2Agent (A2A)** | [a2a-protocol.org](https://a2a-protocol.org) | How *agents talk to each other*: JSON-RPC 2.0 over HTTP with `AgentCard` discovery, task lifecycle, and SSE streaming. Originated at Google; now a Linux Foundation project. **This is the one Diver speaks** (as a client), via `ai/a2a/`. |

Diver integrates **#1** (via `context.lua`), **#2** (via everything under
`ai/acp/`), and **#4** (via `ai/a2a/`, client side only). Diver does
**not** implement #3; it is documented here so the three "ACP"s are
never confused again.

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
  path. `require('ai.context')` ≠ the Agent Client Protocol.

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

### Diver's integration — everything under `ai/acp/`

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
`lua/ai/acp/` expecting REST endpoints would be a category error.

---

## 4. Agent2Agent (A2A) — the multi-agent console

**Sources:**
[spec repo](https://github.com/a2aproject/A2A) ·
[canonical spec](https://raw.githubusercontent.com/a2aproject/A2A/main/specification/a2a.proto) ·
[docs](https://a2a-protocol.org)

Originated at Google as the open protocol for **agent-to-agent**
delegation: one agent hands a task to another without sharing
internals. It is now a Linux Foundation project. Where ACP (#2) is
editor↔agent and MCP is agent↔tools, A2A is agent↔agent.

### Which A2A Diver speaks

A2A defines abstract operations (SendMessage, GetTask, CancelTask,
…) with three wire bindings: **JSONRPC**, **GRPC**, and **HTTP+JSON**.
Diver implements the **v0.3.x JSON-RPC binding** — the shape the
broad third-party SDK ecosystem speaks, and the default when a
card expresses no binding preference. The five official SDKs have
since moved to v1.0 (ProtoJSON); they are driven separately — see
"Official SDKs" below.

| Operation | Diver sends (v0.3 JSON-RPC) | v1.0 equivalent |
|---|---|---|
| Send message | `message/send` | `SendMessage` / `POST /message:send` |
| Stream | `message/stream` (SSE) | `SendStreamingMessage` / `POST /message:stream` |
| Get task | `tasks/get` | `GetTask` / `GET /tasks/{id}` |
| Cancel task | `tasks/cancel` | `CancelTask` / `POST /tasks/{id}:cancel` |

Wire details, verified against the v0.3-era docs and third-party
implementations: lowercase `role: "user"`, `kind` discriminators on
messages and parts (`{kind: "text", text: …}`, `{kind: "message",
messageId: …, …}`), kebab-case task states (`working`,
`input-required`, `completed`, …), agent card at
`/.well-known/agent-card.json` (v0.2.5 used `/.well-known/agent.json`).
Diver also reads v1.0 cards: if a card carries
`supportedInterfaces[]` instead of a top-level `url`, the first
`JSONRPC` interface is used.

### Core concepts

- **AgentCard.** A JSON discovery document: the agent's name, its
  endpoint, version, `capabilities` (`streaming`,
  `pushNotifications`), and `skills`. Diver validates every card
  before use and never executes anything from it — only the
  resolved endpoint URL is ever touched, and only after
  scheme/host checks pass.
- **Tasks.** The execution unit. `message/send` dispatches a message
  and (usually) returns a Task; `message/stream` does the same over
  SSE for progress updates; `tasks/get` polls; `tasks/cancel` aborts.
  Diver treats `completed`, `failed`, `canceled` as terminal and
  ignores unknown states defensively.

### Diver's integration — `ai/a2a/`, client side only

Diver is an A2A **client and operator console**, not a server. The
editor discovers agents, dispatches work, watches it, and aggregates
results; it never accepts inbound A2A connections. Server-side
orchestration (registries, webhooks, durable queues) belongs to
**flow**, Diver's Python runtime.

| Module | Responsibility |
|--------|---------------|
| `init.lua` | `setup()` entry point. Registers commands, installs a `VimLeavePre` autocmd that cancels all in-flight tasks. No I/O at require time. |
| `agent_card.lua` | Card validation (required fields, URL policy), `fetch()` from well-known URIs, and the local directory (`register`/`get`/`list`). |
| `client.lua` | The transport: A2A JSON-RPC 2.0 over HTTP(S) via `curl` through `vim.system` in argv form — no shell, no dependencies. Plain `http://` is accepted **only for loopback hosts** (local flow workers); everything else must be `https://`, and URLs with embedded credentials are rejected. SSE responses are parsed incrementally for `message/stream`. Bounded: 8 MiB responses, 30 s default request timeout. |
| `tasks.lua` | The supervisor: at most 8 concurrent tasks, FIFO overflow queue (64 max), per-task timeout (10 min default), generation tokens so stale callbacks from canceled tasks are ignored, and a subscriber list for the UI. Finished tasks are retained (128 max) for the monitor. |
| `fanout.lua` | Scatter-gather: dispatch one spec list to N agents, one `on_done` with results in spec order. Honors the supervisor's bounds; a fan-out-wide timeout cancels stragglers and reports partial results. |
| `ui.lua` | `:A2aTasks` floating monitor: id, agent, state, elapsed, live-refreshed. `q` closes. |
| `commands.lua` | `:A2aAgents` (list directory), `:A2aTasks` (monitor), `:A2aCancel [id]` (one task, or all with no argument). Also `:A2aSdks` (installer menu) and `:A2aSdkInstall <lang>`. |
| `sdks.lua` | Official SDK registry: install commands, toolchain detection, the floating installer menu, op dispatch, and buffer-local `<LocalLeader>aa*` maps wired by filetype. |
| `sdk_drivers.lua` | One driver program per official SDK (Python, TypeScript, Go, Java, .NET) using its documented client API. Script-kind drivers run under the language runtime; project-kind drivers get a cached scaffold under `stdpath('cache')/a2a-sdk-drivers/`. |

Deliberate scoping notes:

- **No `pushNotifications`.** A2A's webhook push would require the
  editor to run an inbound HTTP server. `message/stream` over SSE
  gives progress updates with the connection direction the editor
  already owns — strictly less attack surface.
- **No server side.** Exposing Neovim *as* an A2A agent (so other
  agents can delegate to the editor) is a possible phase 2; it needs
  an HTTP listener and an auth story, and it does not exist yet.
- **flow owns orchestration.** Durable multi-step workflows, agent
  registries shared across machines, and scheduled runs live in
  flow's Python runtime, which already speaks MCP. `ai/a2a/` is the
  interactive console in front of it.

### Official SDKs — `ai/a2a/sdks.lua` + `sdk_drivers.lua`

The SDK ecosystem has moved to **v1.0** (ProtoJSON wire shapes),
while Diver's native client above speaks **v0.3 JSON-RPC**. For
agents on the v1.0 side, Diver drives the five official SDKs
directly. One driver program per language, written against the
SDK's documented client API (all five verified against the SDK
repos on 2026-09-25):

| Language | Package | Version | Toolchain | Install |
|---|---|---|---|---|
| Python | `a2a-sdk` | 1.1.5 | Python 3.10+ | `pip install a2a-sdk` |
| TypeScript | `@a2a-js/sdk` | 1.2.1 | Node.js 20+ | `npm install @a2a-js/sdk` |
| Go | `github.com/a2aproject/a2a-go/v2` | v2 | Go 1.26+ | `go get github.com/a2aproject/a2a-go/v2` |
| Java | `org.a2aproject.sdk:a2a-java-sdk-client` (+ `-transport-jsonrpc`) | 1.3.2.Final | Java 17+ | see below |
| .NET | `A2A` | — | .NET 8+ | `dotnet add package A2A` |

SDK APIs used per op:

| Op | Python | TypeScript | Go | Java | .NET |
|---|---|---|---|---|---|
| card | `A2ACardResolver.get_agent_card()` | `fetch(…/agent-card.json)` | `agentcard.DefaultResolver.Resolve` | `A2A.getAgentCard` | `A2ACardResolver.GetAgentCardAsync` |
| send | `create_client(...).send_message(SendMessageRequest)` | `client.sendMessage` | `client.SendMessage` | `client.sendMessage(Message, consumers…)` | `A2AClient.SendMessageAsync` |
| stream | `ClientConfig(streaming=True)` | `client.sendMessageStream` | `client.SendStreamingMessage` | consumers on `sendMessage` | `client.SendStreamingMessageAsync` |
| get | `client.get_task(GetTaskRequest)` | `client.getTask` | `client.GetTask` | `client.getTask(TaskQueryParams)` | `client.GetTaskAsync` |
| cancel | `client.cancel_task(CancelTaskRequest)` | `client.cancelTask` | `client.CancelTask` | `client.cancelTask(CancelTaskParams)` | `client.CancelTaskAsync` |

How it works:

- `:A2aSdks` opens a floating installer: `j`/`k` navigate, `<CR>`
  installs the selected SDK in a terminal, `q` closes.
  `:A2aSdkInstall <lang>` installs one directly.
- `sdks.detect_all()` probes each toolchain/SDK concurrently via
  `vim.system`; the menu shows installed/missing at a glance.
  Nothing installs itself — detection never writes.
- Each op asks for the agent's **base URL** (the SDK resolves the
  card itself; the last URL is remembered as the next default),
  then hands off to the language's driver. User input travels as
  process arguments — never interpolated into generated code.
- Script-kind drivers (Python, TypeScript) run from a temp file
  under the language runtime; the TS driver runs from Neovim's cwd
  so a project-local `npm install @a2a-js/sdk` resolves.
- Project-kind drivers (Go, Java, .NET) get a cached scaffold
  under `stdpath('cache')/a2a-sdk-drivers/<lang>`, initialized once
  (`go get`, Maven/Gradle restore via the pom, `dotnet run`
  restore) and reused. Java passes args through an `args.txt` file
  because Maven's `-Dexec.args` would re-split them on spaces.
- `sdks.setup()` wires a single `FileType` autocmd group that gives
  every SDK filetype buffer-local maps — `<LocalLeader>aaa` (card),
  `<LocalLeader>aas` (send), `<LocalLeader>aaS` (stream),
  `<LocalLeader>aag` (get), `<LocalLeader>aac` (cancel),
  `<LocalLeader>aai` (installer menu). Stream ops run in a
  `:terminal` split so long output is interactive.

Caveats, labeled as found:

- The Python SDK documents v0.3 compatibility; the TS SDK has an
  opt-in v0.3 layer. For the others, treat v1.0-only agents as the
  target — Diver's native client covers v0.3.
- Java's `cancelTask` takes `CancelTaskParams` per the current
  source; an older Javadoc example showed `TaskIdParams`.
- The .NET samples README names the streaming call
  `SendMessageStreamAsync`; the interface and sample code say
  `SendStreamingMessageAsync` — the driver uses the latter.

### Quick start

```lua
local agent_card = require('ai.a2a.agent_card')
local tasks = require('ai.a2a.tasks')
local fanout = require('ai.a2a.fanout')

-- Point at a local flow worker and remember it.
agent_card.fetch('http://127.0.0.1:8100', function(ok, card, err)
    if ok then
        agent_card.register('flow-main', card)
    end
end)

-- One async task.
tasks.submit({
    agent = 'flow-main',
    message = 'Summarize the diff in lua/ai/a2a/',
    on_done = function(task)
        vim.notify('done: ' .. task.state)
    end,
})

-- Many agents at once; one callback with every result.
fanout.run({
    { agent = 'flow-main', message = 'Review lua/ai/a2a/client.lua' },
    { agent = 'flow-main', message = 'Review lua/ai/a2a/tasks.lua' },
}, {}, function(results)
    for _, r in ipairs(results) do
        vim.notify(r.agent .. ': ' .. r.state)
    end
end)
```

---

## Disambiguation cheat sheet

Three protocols, one acronym, three different jobs — plus the two that
complete the picture:

- "How does the agent **remember** project knowledge?" →
  **Agent Context Protocol** — markdown files, no network.
- "How does my **editor drive** a coding agent?" →
  **Agent Client Protocol** — JSON-RPC over stdio, client spawns agent.
- "How do **agents talk to each other**?" →
  **Agent Communication Protocol** — REST API, OpenAPI contract.
  (Or **A2A** — JSON-RPC over HTTP, AgentCard discovery. Diver speaks
  A2A as a client via `ai/a2a/`; it does not implement the
  BeeAI-style REST protocol.)
- "How does an agent **call tools**?" → **MCP** — the fourth protocol,
  complementary to all three.

Two further collisions worth knowing, so you don't chase the wrong repo:

- In Diver, `require('ai.context')` is the **Context** protocol and
  everything else under `require('ai.acp.*')` is the **Client** protocol.
  The file is deliberately named `context.lua`, not `acp.lua`.
- `require('ai.a2a.*')` is **Agent2Agent** (originated at Google, now a Linux Foundation project) —
  a different protocol family from every "ACP" above, despite the
  overlapping job description with #3.
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
