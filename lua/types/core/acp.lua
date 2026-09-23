-- /qompassai/Diver/lua/types/core/acp.lua
-- Public native agent API contracts; no third-party plugin type dependencies.
-- Copyright (C) 2025 Qompass AI, All rights reserved
---@meta

---@alias AgentProtocol 'a2a'|'acp-communication'
---@alias AgentVersion '1.0'|'0.3'
---@alias AgentState
---| 'submitted'
---| 'working'
---| 'completed'
---| 'failed'
---| 'canceled'
---| 'rejected'
---| 'input-required'
---| 'auth-required'
---| 'awaiting'
---| 'cancelling'

---@class AgentEndpoint
---@field url string Explicit trusted endpoint; A2A JSONRPC URL or Communication ACP base URL.
---@field protocol? AgentProtocol Defaults to a2a.
---@field version? AgentVersion Explicit A2A wire version; defaults to 1.0.
---@field card_url? string Same-origin A2A Agent Card URL.
---@field agent_name? string Required for Communication ACP.
---@field token_env? string Environment variable containing a bearer credential.
---@field streaming? boolean Defaults to true; A2A also requires advertised capability.
---@field run_mode? string Communication ACP mode: async, sync, stream. Validated at setup.

---@class AgentOptions
---@field agents? table<string, AgentEndpoint> At most 32 trusted endpoint configurations.
---@field context? {command?: string[], global_root?: string|false}
---@field curl? string Executable, not a shell command.
---@field mappings? boolean Install conflict-aware global mappings; defaults to false.
---@field store? {enabled?: boolean, directory?: string}
---@field timeouts? {request_ms?: integer, turn_ms?: integer, poll_ms?: integer}

---@class AgentTextPart
---@field text string Nonempty UTF-8 text; total request limit 1 MiB.

---@class AgentPart
---@field text? string
---@field raw? string Base64 bytes, retained without automatic decoding/writing.
---@field url? string Retained without automatic fetching.
---@field data? unknown Structured JSON value.
---@field mediaType? string
---@field filename? string
---@field metadata? table

---@class AgentMessage
---@field id? string
---@field role string
---@field parts AgentPart[]

---@class AgentArtifact
---@field id string
---@field name? string
---@field parts AgentPart[]

---@class AgentModel
---@field id? string Task or run ID owned by this peer.
---@field context_id? string A2A context ID or Communication ACP session ID.
---@field state AgentState
---@field messages AgentMessage[]
---@field artifacts table<string, AgentArtifact>
---@field artifact_order string[]
---@field await_request? table Communication ACP agent-defined payload.
---@field bytes integer

---@class AgentPeer
---@field card table Validated Agent Card or legacy manifest; never executable.
---@field tenant? string A2A 1.0 routing value.
---@field streaming boolean

---@class AgentCancelHandle
---@field cancel fun() Idempotent local observation cancellation; not remote cancellation.

---@class AgentSession
---@field key string Local conversation UUID; not sent to peers.
---@field agent_name string Configured peer name.
---@field agent AgentEndpoint
---@field cwd string Canonical existing project root.
---@field generation integer
---@field busy boolean
---@field closed boolean
---@field remote AgentModel
---@field peer? AgentPeer
---@field buffer? integer
---@field error? string
---@field depth integer Delegation ancestry bound: 3.
---@field delegation? {parent: string, source: string, target: string, depth: integer}
---@field prompt_parts AgentTextPart[]
---@field wire table[] Bounded diagnostic payloads; not credentials or HTTP headers.
---@field wire_bytes integer
---@field polls? integer
---@field render_pending? boolean
---@field request? AgentCancelHandle
---@field timer? uv.uv_timer_t
---@field deadline? uv.uv_timer_t
---@field callback? fun(state: AgentSession?, error: string?)

---@class AgentHttpRequest
---@field url string Same configured origin; redirect following is disabled.
---@field method? 'GET'|'POST'|'DELETE'
---@field body? table
---@field stream? boolean

---@alias AgentCallback fun(state: AgentSession?, error: string?)
