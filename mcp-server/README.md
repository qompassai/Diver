# diver-mcp-server — the Diver MCP server, as a Rust sidecar

The Rust replacement for Diver's in-editor Lua MCP server
(`lua/ai/mcp/server/`), built in WS3 of the MCP standardization
program (decision D-113). It speaks the modern MCP era only
(2026-07-28) on rmcp 3.8.0, over stdio, with the Lua server's tool
surface unchanged:

- **Tools (7)** — read: `read_file`, `list_files`, `search_text`,
  `get_diagnostics`; write: `write_file`, `edit_file`, `run_command`.
  Schemas and annotations are the baseline's own, served as data.
- **Policy gate** — per-tool auto/confirm/deny decision before any
  handler runs; path scoping against workspace roots with secret
  locations denied; `run_command` is argv-only (never a shell)
  behind a bare-name allowlist that defaults to deny-all; audit
  records append to the same `tool-calls.jsonl` the Lua server
  writes through `ai.security.auditlog`.
- **Error taxonomy** — policy refusal is a protocol error `-32000`;
  unknown tool / bad params `-32602`; handler crash `-32603`; a
  tool *execution* failure is a successful response with
  `isError = true`. Legacy `initialize` contact is refused with
  `-32022` naming 2026-07-28.

The step-0 inventory classified all seven tools as
editor-independent (disk reads, `rg` search, CLI linters, argv
subprocesses — the Lua server's "phase 2" live-editor diagnostics
were never part of its shipped surface), so the sidecar executes
them directly and the private nvim-socket seam is untouched.

## Placement (recorded at WS3 step 0)

The crate lives in this repository, beside the Lua server it
replaces — the same shape as phlow's MCP crate inside the phlow
repo. The standardization program named two candidate homes (a
workspace member alongside the diver repo, or a small standalone
repo); the in-repo home was chosen because the server is Diver's
own surface (its config, its registry, its cutover flag), and
moving this one self-contained directory to a standalone repo
later is a mechanical lift if the Owner rules otherwise. No push
of this repo happens without the Owner's per-push word, as with
all of Diver.

## Usage

```
diver-mcp-server [--root DIR]... [--grant-token TOKEN]
                 [--confirm-grant TOOL]... [--allow-command NAME]...
                 [--audit-log PATH] [--no-audit]
```

The flags are the Lua policy module's setup fields, one for one:
`--root` is `roots` (repeatable; default is the working directory),
`--confirm-grant TOOL` pre-approves one confirm-class tool
(`confirm_grants`), `--grant-token` sets the token a call may
carry as `_meta.grant` (`grant_token`), and `--allow-command NAME`
adds one bare command name to the `run_command` allowlist
(`run_allowlist`, empty by default). The audit log defaults to the
Neovim data directory's `diver/tool-calls.jsonl`;
`--audit-log` overrides the path and `--no-audit` disables it.

Launched by a host the same way the Lua server was — an argv array
in the host's server configuration (for Diver itself, a registry
entry), speaking newline-delimited JSON-RPC on stdio. Stdout
carries protocol traffic only; diagnostics go to stderr.
Configuration errors exit with code 2 before the protocol starts.
