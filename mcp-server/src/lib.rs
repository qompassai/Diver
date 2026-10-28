//! Diver MCP server — Rust rmcp sidecar (WS3 of the MCP
//! standardization program, decision D-113).
//!
//! This crate replaces the in-editor Lua MCP server
//! (`lua/ai/mcp/server/`) with a standalone Rust binary speaking the
//! modern MCP era only (2026-07-28) on rmcp 3.8.0. The tool surface
//! is the Lua server's, unchanged: seven tools, their schemas and
//! annotations, the fail-closed policy gate (path scoping, per-tool
//! approval classes, the `run_command` bare-name allowlist, audit),
//! and the error taxonomy that distinguishes protocol errors
//! (-32602 / -32000 / -32603) from in-band tool failures
//! (`isError = true` results). The step-0 inventory classified all
//! seven tools as editor-independent (disk reads, `rg`, CLI linters,
//! argv subprocesses), so the sidecar executes them directly; the
//! private nvim-socket seam is untouched by this replacement.

pub mod guard;
pub mod policy;
pub mod server;
pub mod tools;
