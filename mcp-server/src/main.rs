#![forbid(unsafe_code)]
//! Diver MCP server entry point (the WS3 sidecar).
//!
//! Usage: `diver-mcp-server [--root DIR]... [--grant-token TOKEN]
//! [--confirm-grant TOOL]... [--allow-command NAME]...
//! [--audit-log PATH] [--no-audit]`
//!
//! Speaks MCP on stdio. All diagnostics go to stderr; stdout
//! carries protocol traffic only. Configuration errors fail fast
//! with exit code 2 before the protocol starts. The flags are the
//! Lua policy module's setup fields, one for one: `--root` is
//! `roots`, `--confirm-grant` is `confirm_grants`, `--grant-token`
//! is `grant_token`, `--allow-command` is `run_allowlist`.
//!
//! As of WS3 (MCP standardization program, decision D-113) this
//! server runs on rmcp, the official Rust MCP SDK, and speaks the
//! modern protocol era only (2026-07-28): sessions open with
//! `server/discover`, and every request carries its protocol
//! version in `_meta` — there is no `initialize` handshake. Legacy
//! contact is refused at the stdio front door (see `guard`) with
//! the typed `-32022` unsupported-version error, naming 2026-07-28
//! as the one supported version. The tool surface and the policy
//! gate are the retired Lua server's, unchanged.

use std::path::PathBuf;
use std::process::ExitCode;
use std::sync::Arc;

use diver_mcp_server::guard;
use diver_mcp_server::policy::{Policy, default_audit_path};
use diver_mcp_server::server::DiverServer;
use rmcp::ServiceExt;
use rmcp::transport::async_rw::AsyncRwTransport;
use tokio::sync::Mutex;

/// Duplex buffer between the era guard and the SDK service. Request
/// lines can reach the 8 MiB line bound; the SDK consumes
/// incrementally, so this only needs to cover response bursts.
const DUPLEX_BUFFER_BYTES: usize = 1024 * 1024;

const USAGE: &str = "usage: diver-mcp-server [--root DIR]... [--grant-token TOKEN] \
    [--confirm-grant TOOL]... [--allow-command NAME]... [--audit-log PATH] [--no-audit]";

fn main() -> ExitCode {
    let policy = match parse_args() {
        Ok(policy) => policy,
        Err(message) => {
            eprintln!("diver-mcp-server: {message}");
            eprintln!("{USAGE}");
            return ExitCode::from(2);
        }
    };
    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            eprintln!("diver-mcp-server: cannot start the async runtime: {error}");
            return ExitCode::FAILURE;
        }
    };
    match runtime.block_on(run(policy)) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("diver-mcp-server: serve loop ended: {error}");
            ExitCode::FAILURE
        }
    }
}

/// Wire the pieces together: the guard owns stdio, the SDK service
/// sits behind an in-process duplex, and a pump copies its responses
/// back to stdout through the same lock the guard writes with.
async fn run(policy: Policy) -> std::io::Result<()> {
    let (client_side, server_side) = tokio::io::duplex(DUPLEX_BUFFER_BYTES);
    let (server_read, server_write) = tokio::io::split(server_side);
    let (client_read, client_write) = tokio::io::split(client_side);
    let stdout: guard::SharedStdout = Arc::new(Mutex::new(tokio::io::stdout()));

    let ordering = guard::Ordering::new();
    let handler = DiverServer::new(policy);
    let serve = tokio::spawn(async move {
        let transport = AsyncRwTransport::new_server(server_read, server_write);
        match handler.serve(transport).await {
            Ok(running) => running
                .waiting()
                .await
                .map(|_| ())
                .map_err(|e| std::io::Error::other(e.to_string())),
            // The client closed the connection before selecting a
            // lifecycle (a probe, a spawn check, a client that only
            // ever wanted the refusal): the baseline treated bare
            // EOF as a clean end of session, and so do we.
            Err(rmcp::service::ServerInitializeError::ConnectionClosed(_)) => Ok(()),
            Err(e) => Err(std::io::Error::other(e.to_string())),
        }
    });
    let mut pump = tokio::spawn(guard::pump(
        client_read,
        Arc::clone(&stdout),
        Arc::clone(&ordering),
    ));

    // When stdin reaches EOF the guard shuts the duplex write side
    // down, which ends the SDK service; the pump ends when the
    // service's transport drops. The pump wait is bounded as a
    // backstop: a response still in flight when the service ends
    // gets its chance to drain, but a wedged pump cannot hang exit.
    let guard_result = guard::run(tokio::io::stdin(), client_write, stdout, ordering).await;
    let serve_result = match serve.await {
        Ok(result) => result,
        Err(e) => Err(std::io::Error::other(e.to_string())),
    };
    if tokio::time::timeout(std::time::Duration::from_secs(2), &mut pump)
        .await
        .is_err()
    {
        pump.abort();
    }
    guard_result.and(serve_result)
}

/// Parse the (deliberately tiny) CLI into the policy configuration.
fn parse_args() -> Result<Policy, String> {
    let mut roots: Vec<String> = Vec::new();
    let mut confirm_grants: Vec<(String, bool)> = Vec::new();
    let mut grant_token: Option<String> = None;
    let mut run_allowlist: Vec<String> = Vec::new();
    let mut audit_log: Option<PathBuf> = None;
    let mut audit_disabled = false;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        let mut take_value = |flag: &str| -> Result<String, String> {
            args.next()
                .ok_or_else(|| format!("{flag} requires a value"))
        };
        match arg.as_str() {
            "--root" => roots.push(take_value("--root")?),
            "--grant-token" => grant_token = Some(take_value("--grant-token")?),
            "--confirm-grant" => {
                confirm_grants.push((take_value("--confirm-grant")?, true));
            }
            "--allow-command" => run_allowlist.push(take_value("--allow-command")?),
            "--audit-log" => audit_log = Some(PathBuf::from(take_value("--audit-log")?)),
            "--no-audit" => audit_disabled = true,
            "--help" | "-h" => {
                return Err(
                    "diver-mcp-server speaks MCP on stdio; it has no interactive mode".to_string(),
                );
            }
            other => return Err(format!("unknown argument: {other}")),
        }
    }
    let cwd = std::env::current_dir()
        .map_err(|error| format!("cannot determine the working directory: {error}"))?;
    let cwd = cwd.to_string_lossy().into_owned();
    let audit_path = if audit_disabled {
        None
    } else if audit_log.is_some() {
        audit_log
    } else {
        default_audit_path()
    };
    Ok(Policy::new(
        &roots,
        &cwd,
        &confirm_grants,
        grant_token,
        &run_allowlist,
        audit_path,
    ))
}
