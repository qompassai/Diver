//! The rmcp server: tool surface and handler dispatch.
//!
//! The surface is the Lua server's, unchanged — the catalog is
//! served from [`crate::tools::definitions`] (the baseline's own
//! JSON), and dispatch is [`crate::tools::call`], which keeps the
//! baseline's taxonomy: policy refusals and bad shapes are protocol
//! errors with the baseline's codes, execution failures are in-band
//! `isError` results.
//!
//! Two era translations live here, both forced by the modern
//! protocol's shape:
//!
//! - **The grant channel.** The baseline reads the confirmation
//!   grant from the call's `_meta.grant`. The modern `_meta` is
//!   protocol metadata, but the SDK preserves unrecognized keys:
//!   deserialization strips the wire `_meta` into the request
//!   context, and the grant is read from there, unchanged — no
//!   wire-format change.
//! - **Dispatch serialization.** The baseline's front end was a
//!   sequential loop. rmcp dispatches concurrently, so dispatch
//!   here takes a mutex for the whole call and runs the (blocking,
//!   subprocess-driving) tool call on a blocking thread, preserving
//!   the baseline's ordering while the runtime stays responsive.
//!
//! Modern-only posture lives in two places: the era guard refuses
//! `initialize` before the SDK sees it, and
//! [`ServerHandler::supported_protocol_versions`] pins this handler
//! to 2026-07-28, so `server/discover` advertises exactly one
//! version and the SDK validates every request's `_meta` against
//! it.

use std::borrow::Cow;
use std::sync::Arc;

use rmcp::model::{
    CacheScope, CallToolRequestParams, CallToolResponse, CallToolResult, ContentBlock,
    DiscoverResult, ErrorCode, Implementation, InitializeResult, ListToolsResult,
    PaginatedRequestParams, ProtocolVersion, ServerCapabilities, Tool,
};
use rmcp::service::RequestContext;
use rmcp::{ErrorData, RoleServer, ServerHandler};
use serde_json::Value;
use tokio::sync::Mutex;

use crate::policy::Policy;
use crate::tools::{self, CallOutcome};

/// The baseline's instructions text, carried from its `initialize`
/// result into the modern discover result unchanged.
const INSTRUCTIONS: &str = "Diver MCP server. Reads are auto-approved; writes need a confirmation \
    grant; run_command uses a bare-name allowlist (default deny) and never a shell.";

/// The tool catalog: names, titles, descriptions, schemas, and
/// annotations are the baseline's own definitions — rmcp accepts
/// the raw shapes, so no schemars translation stands between the
/// baseline and the wire.
fn tool_definitions() -> Vec<Tool> {
    let definitions = tools::definitions();
    let entries = definitions.as_array().expect("definitions are an array");
    entries
        .iter()
        .map(|entry| {
            serde_json::from_value::<Tool>(entry.clone()).expect("catalog entry is a Tool")
        })
        .collect()
}

fn text_result(text: String, is_error: bool) -> CallToolResult {
    let content = vec![ContentBlock::text(text)];
    if is_error {
        CallToolResult::error(content)
    } else {
        CallToolResult::success(content)
    }
}

/// The server handler: the configured policy plus the dispatch
/// mutex. Clonable over shared state so the serve can own one clone
/// while `main` keeps another.
#[derive(Clone)]
pub struct DiverServer {
    dispatch_lock: Arc<Mutex<()>>,
    policy: Arc<Policy>,
}

impl DiverServer {
    pub fn new(policy: Policy) -> Self {
        DiverServer {
            dispatch_lock: Arc::new(Mutex::new(())),
            policy: Arc::new(policy),
        }
    }
}

impl ServerHandler for DiverServer {
    fn get_info(&self) -> InitializeResult {
        // Both model types are non-exhaustive: start from the
        // default and set exactly the fields this server reports.
        let mut server_info = Implementation::default();
        server_info.name = "diver-mcp-server".to_string();
        server_info.version = env!("CARGO_PKG_VERSION").to_string();
        let mut info = InitializeResult::default();
        info.protocol_version = ProtocolVersion::V_2026_07_28;
        info.capabilities = ServerCapabilities::builder().enable_tools().build();
        info.server_info = server_info;
        info.instructions = Some(INSTRUCTIONS.to_string());
        info
    }

    fn supported_protocol_versions(&self) -> Cow<'static, [ProtocolVersion]> {
        Cow::Borrowed(&[ProtocolVersion::V_2026_07_28])
    }

    async fn discover(
        &self,
        _context: RequestContext<RoleServer>,
    ) -> Result<DiscoverResult, ErrorData> {
        // Fleet shape (phlow's C2 handler): an hour of freshness,
        // shareable across authorization contexts.
        let mut result = DiscoverResult::from_server_info(
            self.supported_protocol_versions().into_owned(),
            self.get_info(),
        );
        result.ttl_ms = 3_600_000;
        result.cache_scope = CacheScope::Public;
        Ok(result)
    }

    async fn list_tools(
        &self,
        _request: Option<PaginatedRequestParams>,
        _context: RequestContext<RoleServer>,
    ) -> Result<ListToolsResult, ErrorData> {
        Ok(ListToolsResult {
            tools: tool_definitions(),
            ..Default::default()
        })
    }

    async fn call_tool(
        &self,
        request: CallToolRequestParams,
        context: RequestContext<RoleServer>,
    ) -> Result<CallToolResponse, ErrorData> {
        let name = request.name.to_string();
        let arguments = request.arguments.unwrap_or_default();
        // The baseline's grant channel: `_meta.grant`. rmcp strips
        // the wire `_meta` into the request context (the typed
        // params field stays empty on deserialize), so the context
        // is where the grant is read.
        let grant = context
            .meta
            .get("grant")
            .and_then(Value::as_str)
            .map(str::to_string);
        let policy = Arc::clone(&self.policy);
        let _guard = self.dispatch_lock.lock().await;
        let outcome = tokio::task::spawn_blocking(move || {
            tools::call(&policy, &name, &arguments, grant.as_deref())
        })
        .await
        .unwrap_or(CallOutcome::Refusal {
            code: -32603,
            message: "tool handler failed".to_string(),
        });
        match outcome {
            CallOutcome::Result { text, is_error } => Ok(text_result(text, is_error).into()),
            CallOutcome::Refusal { code, message } => {
                Err(ErrorData::new(ErrorCode(code), message, None))
            }
        }
    }
}

/// The wire-shape smoke: the catalog the handler serves is the
/// baseline's definitions, in order, field for field.
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_matches_the_baseline_definitions() {
        let served = serde_json::json!(tool_definitions());
        let baseline = tools::definitions();
        let served_entries = served.as_array().expect("array");
        let baseline_entries = baseline.as_array().expect("array");
        assert_eq!(served_entries.len(), baseline_entries.len());
        for (served, baseline) in served_entries.iter().zip(baseline_entries) {
            for field in ["name", "title", "description", "inputSchema", "annotations"] {
                assert_eq!(
                    served[field], baseline[field],
                    "tool {} field {field}",
                    baseline["name"]
                );
            }
        }
    }
}
