//! Fail-closed policy for the MCP server: path scoping, per-tool
//! approval classes, `run_command` argv[0] allowlist, and audit
//! logging.
//!
//! A line-for-line port of `lua/ai/mcp/server/policy.lua` — refusal
//! codes and messages are the baseline's own, including its quirks
//! (the secret-directory message carries the directory part's own
//! leading dot after the literal one, e.g. "..ssh"). Every path
//! argument is normalized, absolutized, and checked against the
//! workspace roots before anything touches the filesystem; a `..`
//! that climbs out of the roots is rejected, symlinks are resolved
//! and re-checked, and secret locations (~/.ssh and friends) are
//! denied even when they sit inside a root. Writes need an explicit
//! confirmation grant; run_command only runs bare argv[0] names from
//! an allowlist that defaults to empty (deny-all), and commands
//! never go through a shell.
//!
//! Refusals are values, never panics: code -32602 for
//! malformed/out-of-scope input, -32000 for policy denials. Audit
//! logging never fails a tool call.

use std::collections::{HashMap, HashSet};
use std::io::Write as _;
use std::path::PathBuf;

const ARG_COUNT_MAX: usize = 32;
const ARG_LENGTH_MAX: usize = 4096;
const AUDIT_DECISION_MAX: usize = 64;
const AUDIT_TARGET_MAX: usize = 256;
const AUDIT_TOOL_MAX: usize = 128;
const AUDIT_VIA_MAX: usize = 64;
const PATH_LENGTH_MAX: usize = 4096;

/// Bounds for the run_command timeout_ms argument. Exported so the
/// tool schema shares one source of truth with the policy module.
pub const COMMAND_TIMEOUT_MS_MAX: i64 = 120_000;
pub const COMMAND_TIMEOUT_MS_MIN: i64 = 1_000;

pub const INVALID_PARAMS_CODE: i32 = -32602;
pub const POLICY_DENIED_CODE: i32 = -32000;

const SECRET_BASENAMES: [&str; 5] = [".env", "id_dsa", "id_ecdsa", "id_ed25519", "id_rsa"];
const SECRET_DIR_PARTS: [&str; 4] = [".aws", ".gnupg", ".pki", ".ssh"];
const SECRET_SUFFIXES: [&str; 2] = [".key", ".pem"];

#[derive(Clone, Copy, PartialEq, Eq)]
enum Approval {
    Auto,
    Confirm,
    Deny,
}

/// Reads are auto-approved; everything that mutates or reaches the
/// outside world needs an explicit grant. Unknown tools are denied,
/// never defaulted.
fn approval_class(tool: &str) -> Approval {
    match tool {
        "get_diagnostics" | "list_files" | "read_file" | "search_text" => Approval::Auto,
        "edit_file" | "run_command" | "write_file" => Approval::Confirm,
        _ => Approval::Deny,
    }
}

/// A policy refusal: -32602 for bad input, -32000 for a denial.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PolicyError {
    pub code: i32,
    pub message: String,
}

fn policy_error(code: i32, message: impl Into<String>) -> PolicyError {
    PolicyError {
        code,
        message: message.into(),
    }
}

/// Lexically collapse `.` and `..` without touching the filesystem,
/// so the root check sees the true shape of the path. A `..` past
/// the filesystem root stays at the root and then fails the root
/// check. (The Lua original splits on `[^/]+`; empty segments are
/// skipped the same way here.)
fn collapse(path: &str) -> String {
    let is_abs = path.starts_with('/');
    let mut parts: Vec<&str> = Vec::new();
    for part in path.split('/') {
        if part.is_empty() || part == "." {
            continue;
        }
        if part == ".." {
            if parts.last().is_some_and(|last| *last != "..") {
                parts.pop();
            } else if !is_abs {
                parts.push("..");
            }
        } else {
            parts.push(part);
        }
    }
    let out = parts.join("/");
    if is_abs {
        format!("/{out}")
    } else if out.is_empty() {
        ".".to_string()
    } else {
        out
    }
}

/// Truncate to at most `max` bytes without splitting a UTF-8
/// character (the audit record caps from the Lua original).
fn truncate_bytes(text: &str, max: usize) -> &str {
    if text.len() <= max {
        return text;
    }
    let mut end = max;
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    &text[..end]
}

/// The configured policy: workspace roots, confirmation grants, the
/// grant token, the run_command allowlist, and the audit log path.
/// Mirrors `policy.setup(opts)` in the Lua original — the sidecar's
/// CLI flags carry exactly these fields.
#[derive(Debug, Clone)]
pub struct Policy {
    audit_path: Option<PathBuf>,
    confirm_grants: HashMap<String, bool>,
    grant_token: Option<String>,
    roots: Vec<String>,
    run_allowlist: HashSet<String>,
}

/// A run_command argv after policy validation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckedCommand {
    pub argv: Vec<String>,
    pub cwd: Option<String>,
}

impl Policy {
    /// Build the policy. Relative roots anchor at `cwd` (the Lua
    /// original anchored at the editor's working directory); with no
    /// roots the cwd itself is the single root.
    pub fn new(
        roots: &[String],
        cwd: &str,
        confirm_grants: &[(String, bool)],
        grant_token: Option<String>,
        run_allowlist: &[String],
        audit_path: Option<PathBuf>,
    ) -> Policy {
        let mut collapsed_roots: Vec<String> = roots
            .iter()
            .map(|root| {
                if root.starts_with('/') {
                    collapse(root)
                } else {
                    collapse(&format!("{cwd}/{root}"))
                }
            })
            .collect();
        if collapsed_roots.is_empty() {
            collapsed_roots.push(collapse(cwd));
        }
        Policy {
            audit_path,
            confirm_grants: confirm_grants.iter().cloned().collect(),
            grant_token,
            roots: collapsed_roots,
            run_allowlist: run_allowlist.iter().cloned().collect(),
        }
    }

    /// The configured roots (a copy, as in the Lua original).
    pub fn roots(&self) -> Vec<String> {
        self.roots.clone()
    }

    fn check_scoped(&self, abs: &str) -> Result<(), PolicyError> {
        let rooted = self
            .roots
            .iter()
            .any(|root| abs == root || abs.starts_with(&format!("{root}/")));
        if !rooted {
            return Err(policy_error(
                INVALID_PARAMS_CODE,
                "path escapes workspace roots",
            ));
        }
        for part in abs.split('/') {
            if SECRET_DIR_PARTS.contains(&part) {
                return Err(policy_error(
                    POLICY_DENIED_CODE,
                    format!("denied: path under secret directory .{part}"),
                ));
            }
        }
        let base = abs.rsplit('/').next().unwrap_or("");
        if SECRET_BASENAMES.contains(&base) {
            return Err(policy_error(
                POLICY_DENIED_CODE,
                format!("denied: secret file name {base}"),
            ));
        }
        for suffix in SECRET_SUFFIXES {
            if base.len() > suffix.len() && base.ends_with(suffix) {
                return Err(policy_error(
                    POLICY_DENIED_CODE,
                    format!("denied: credential file suffix {suffix}"),
                ));
            }
        }
        Ok(())
    }

    /// Normalize, absolutize (relative paths anchor at the first
    /// root), and scope a caller-supplied path. Symlinks are
    /// resolved and re-checked so a link inside the roots cannot
    /// point outside them.
    pub fn scope_path(&self, path: &str) -> Result<String, PolicyError> {
        if path.is_empty() {
            return Err(policy_error(
                INVALID_PARAMS_CODE,
                "path must be a non-empty string",
            ));
        }
        if path.len() > PATH_LENGTH_MAX {
            return Err(policy_error(
                INVALID_PARAMS_CODE,
                format!("path exceeds {PATH_LENGTH_MAX} bytes"),
            ));
        }
        if path.chars().any(|c| c.is_control()) {
            return Err(policy_error(
                INVALID_PARAMS_CODE,
                "path contains control characters",
            ));
        }
        let abs = if path.starts_with('/') {
            collapse(path)
        } else {
            collapse(&format!("{}/{path}", self.roots[0]))
        };
        self.check_scoped(&abs)?;
        // Symlink resolution: std::fs::canonicalize plays the role
        // of vim.uv.fs_realpath — it fails for paths that do not
        // exist, and the Lua original skipped the re-check then too.
        if let Ok(resolved) = std::fs::canonicalize(&abs) {
            let resolved = resolved.to_string_lossy().into_owned();
            if resolved != abs {
                let resolved = collapse(&resolved);
                if let Err(inner) = self.check_scoped(&resolved) {
                    return Err(policy_error(
                        inner.code,
                        format!("symlink target denied: {}", inner.message),
                    ));
                }
                return Ok(resolved);
            }
        }
        Ok(abs)
    }

    /// Approval class gate. A headless server cannot prompt, so
    /// `confirm` tools are denied unless the operator pre-approved
    /// them at setup or the call carries the configured grant token
    /// (the tools/call `_meta.grant` value, passed in as `grant`).
    pub fn check_approval(&self, tool: &str, grant: Option<&str>) -> Result<(), String> {
        match approval_class(tool) {
            Approval::Auto => Ok(()),
            Approval::Deny => Err(format!("tool denied by policy: {tool}")),
            Approval::Confirm => {
                if self.confirm_grants.get(tool).copied().unwrap_or(false) {
                    return Ok(());
                }
                if let (Some(carried), Some(configured)) = (grant, self.grant_token.as_deref())
                    && carried == configured
                {
                    return Ok(());
                }
                Err(format!("tool requires a confirmation grant: {tool}"))
            }
        }
    }

    /// Validate a run_command argv: dense string array, bounded, no
    /// NUL bytes, bare argv[0] (no `/`, so PATH resolution only)
    /// present in the allowlist, optional cwd scoped like any other
    /// path. Never a shell string. (Density is a JSON-array given by
    /// the time this runs; the Lua original re-checked it because
    /// its arrays are tables.)
    pub fn check_command(
        &self,
        argv: &[String],
        cwd: Option<&str>,
    ) -> Result<CheckedCommand, PolicyError> {
        if argv.is_empty() || argv.len() > ARG_COUNT_MAX {
            return Err(policy_error(
                INVALID_PARAMS_CODE,
                format!("cmd must have 1..{ARG_COUNT_MAX} elements"),
            ));
        }
        for part in argv {
            if part.is_empty() {
                return Err(policy_error(
                    INVALID_PARAMS_CODE,
                    "cmd elements must be non-empty strings",
                ));
            }
            if part.len() > ARG_LENGTH_MAX {
                return Err(policy_error(
                    INVALID_PARAMS_CODE,
                    format!("cmd element exceeds {ARG_LENGTH_MAX} bytes"),
                ));
            }
            if part.contains('\0') {
                return Err(policy_error(
                    INVALID_PARAMS_CODE,
                    "cmd element contains a NUL byte",
                ));
            }
        }
        let program = &argv[0];
        if program.contains('/') {
            return Err(policy_error(
                INVALID_PARAMS_CODE,
                "argv[0] must be a bare command name, not a path",
            ));
        }
        if !self.run_allowlist.contains(program) {
            return Err(policy_error(
                POLICY_DENIED_CODE,
                format!("command not in allowlist: {program}"),
            ));
        }
        let scoped_cwd = match cwd {
            Some(dir) => Some(self.scope_path(dir)?),
            None => None,
        };
        Ok(CheckedCommand {
            argv: argv.to_vec(),
            cwd: scoped_cwd,
        })
    }

    /// Append one audit record to the audit log — the same record
    /// shape and location as `ai.security.auditlog` writes for the
    /// Lua server ({ts, tool, target, via: "mcp-server", decision}
    /// as one JSON line). Best-effort by contract: any failure is
    /// swallowed, never a failed tool call.
    pub fn audit(&self, tool: &str, target: &str, decision: &str) {
        let Some(path) = &self.audit_path else {
            return;
        };
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let record = serde_json::json!({
            "ts": ts,
            "tool": truncate_bytes(tool, AUDIT_TOOL_MAX),
            "target": truncate_bytes(target, AUDIT_TARGET_MAX),
            "via": truncate_bytes("mcp-server", AUDIT_VIA_MAX),
            "decision": truncate_bytes(decision, AUDIT_DECISION_MAX),
        });
        let mut line = record.to_string();
        line.push('\n');
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        if let Ok(mut file) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
        {
            let _ = file.write_all(line.as_bytes());
        }
    }
}

/// The default audit log path: the Neovim data directory's
/// `diver/tool-calls.jsonl`, matching `ai.security.auditlog`'s
/// `stdpath('data')` resolution ($XDG_DATA_HOME/nvim, else
/// ~/.local/share/nvim). None when no home directory is known.
pub fn default_audit_path() -> Option<PathBuf> {
    let data_home = std::env::var_os("XDG_DATA_HOME")
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .or_else(|| {
            std::env::var_os("HOME")
                .filter(|value| !value.is_empty())
                .map(|home| PathBuf::from(home).join(".local/share"))
        })?;
    Some(
        data_home
            .join("nvim")
            .join("diver")
            .join("tool-calls.jsonl"),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn policy(roots: &[&str]) -> Policy {
        Policy::new(
            &roots.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
            "/",
            &[],
            Some("tok".to_string()),
            &["echo".to_string()],
            None,
        )
    }

    #[test]
    fn collapse_matches_the_lua_lexical_rules() {
        assert_eq!(collapse("/a/b/../c"), "/a/c");
        assert_eq!(collapse("/a/./b//c/"), "/a/b/c");
        assert_eq!(collapse("/../x"), "/x");
        assert_eq!(collapse("a/../../b"), "../b");
        assert_eq!(collapse(""), ".");
        assert_eq!(collapse("/"), "/");
    }

    #[test]
    fn scope_rejects_escapes_and_secrets_with_baseline_messages() {
        let p = policy(&["/work"]);
        assert_eq!(p.scope_path("a/b.txt").unwrap(), "/work/a/b.txt");
        assert_eq!(
            p.scope_path("../out").unwrap_err().message,
            "path escapes workspace roots"
        );
        let secret = p.scope_path(".ssh/key").unwrap_err();
        assert_eq!(secret.code, POLICY_DENIED_CODE);
        assert_eq!(secret.message, "denied: path under secret directory ..ssh");
        assert_eq!(
            p.scope_path("id_ed25519").unwrap_err().message,
            "denied: secret file name id_ed25519"
        );
        assert_eq!(
            p.scope_path("cert.pem").unwrap_err().message,
            "denied: credential file suffix .pem"
        );
    }

    #[test]
    fn approval_classes_and_grant_paths() {
        let p = policy(&["/work"]);
        assert!(p.check_approval("read_file", None).is_ok());
        assert_eq!(
            p.check_approval("write_file", None).unwrap_err(),
            "tool requires a confirmation grant: write_file"
        );
        assert!(p.check_approval("write_file", Some("tok")).is_ok());
        assert!(p.check_approval("write_file", Some("wrong")).is_err());
        assert_eq!(
            p.check_approval("nope", Some("tok")).unwrap_err(),
            "tool denied by policy: nope"
        );
    }

    #[test]
    fn command_checks_match_the_baseline() {
        let p = policy(&["/work"]);
        let ok = p
            .check_command(&["echo".to_string(), "hi".to_string()], None)
            .unwrap();
        assert_eq!(ok.argv.len(), 2);
        assert_eq!(
            p.check_command(&["/bin/echo".to_string()], None)
                .unwrap_err()
                .message,
            "argv[0] must be a bare command name, not a path"
        );
        let denied = p.check_command(&["ls".to_string()], None).unwrap_err();
        assert_eq!(denied.code, POLICY_DENIED_CODE);
        assert_eq!(denied.message, "command not in allowlist: ls");
    }
}
