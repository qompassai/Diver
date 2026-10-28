//! The MCP tool surface diver exposes as a server: four read tools
//! and three write tools, all validated, bounded, and policy-gated.
//!
//! A port of `lua/ai/mcp/server/tools.lua`. Each tool declares its
//! name, a JSON Schema for its arguments, and honest annotations
//! (readOnlyHint and friends — hosts use these to decide what to
//! auto-approve, so a lie here is a privilege escalation). Arguments
//! are checked against the schema by hand, then policy decides
//! auto/confirm/deny, then the handler runs. A tool that fails while
//! running answers `{isError = true, ...}` — a successful JSON-RPC
//! response — while unknown tools, bad shapes, and policy refusals
//! are protocol errors (-32602 / -32000).
//!
//! Subprocess tools run argv arrays only — there is no code path
//! that builds a shell string. rg is required for search_text;
//! diagnostics are phase-1 CLI linters (luacheck/ruff/shellcheck)
//! when installed, reported honestly when absent.

use std::io::{BufRead, BufReader, Read};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

use serde_json::{Map, Value, json};

use crate::policy::{
    COMMAND_TIMEOUT_MS_MAX, COMMAND_TIMEOUT_MS_MIN, INVALID_PARAMS_CODE, Policy, PolicyError,
};

const COMMAND_TIMEOUT_MS_DEFAULT: u64 = 30_000;
const CONTENT_BYTES_MAX: usize = 512 * 1024;
const DIAG_TIMEOUT_MS: u64 = 15_000;
const LIST_ENTRIES_MAX: usize = 500;
const OUTPUT_BYTES_MAX: usize = 256 * 1024;
const READ_LINES_MAX: i64 = 2_000;
const READ_LINE_BYTES_MAX: usize = 8_192;
const SEARCH_HITS_MAX: usize = 100;
const SEARCH_TIMEOUT_MS: u64 = 15_000;
/// Per-stream collection cap for subprocess output. The handlers
/// only ever surface the first OUTPUT_BYTES_MAX bytes of the
/// concatenation; collecting far past that (and draining the rest)
/// keeps a spewing child from growing memory without bound while
/// leaving every wire-visible byte identical to the baseline.
const STREAM_COLLECT_MAX: usize = 1024 * 1024;

const ERR_INTERNAL: i32 = -32603;

/// The tool catalog, byte-faithful to the Lua server's descriptors
/// (same order — the Lua list is sorted by name — same schemas, same
/// annotations). Kept as data so the wire shape is reviewed as data.
pub fn definitions() -> Value {
    json!([
        {
            "name": "edit_file",
            "title": "Edit file",
            "description": "Replace one exact occurrence of old_text with new_text (plain string match, no fuzzy matching). Fails when old_text is absent or ambiguous. Needs a confirmation grant.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "maxLength": 4096},
                    "old_text": {"type": "string", "minLength": 1, "maxLength": 1048576},
                    "new_text": {"type": "string", "maxLength": 1048576}
                },
                "required": ["path", "old_text", "new_text"]
            },
            "annotations": {"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": false}
        },
        {
            "name": "get_diagnostics",
            "title": "Get diagnostics",
            "description": "Phase-1 diagnostics via repo CLI linters (luacheck, ruff, shellcheck) when installed. Honest when no linter applies.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "maxLength": 4096}
                },
                "required": []
            },
            "annotations": {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
        },
        {
            "name": "list_files",
            "title": "List files",
            "description": "List directory entries inside the workspace roots, newest of at most 500 entries sorted by name. Directories end with `/`.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "dir": {"type": "string", "maxLength": 4096},
                    "glob": {"type": "string", "maxLength": 256}
                },
                "required": []
            },
            "annotations": {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
        },
        {
            "name": "read_file",
            "title": "Read file",
            "description": "Read a text file inside the workspace roots. Returns a bounded line window (offset is 1-based, at most 2000 lines per call).",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "maxLength": 4096},
                    "offset": {"type": "integer", "minimum": 1},
                    "limit": {"type": "integer", "minimum": 1}
                },
                "required": ["path"]
            },
            "annotations": {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
        },
        {
            "name": "run_command",
            "title": "Run command",
            "description": "Run a command as an argv array (never a shell string). argv[0] must be a bare name from the allowlist, which defaults to empty (deny-all). Needs a confirmation grant.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "cmd": {"type": "array", "items": {"type": "string", "maxLength": 4096}, "minItems": 1, "maxItems": 32},
                    "cwd": {"type": "string", "maxLength": 4096},
                    "timeout_ms": {"type": "integer", "minimum": COMMAND_TIMEOUT_MS_MIN, "maximum": COMMAND_TIMEOUT_MS_MAX}
                },
                "required": ["cmd"]
            },
            "annotations": {"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": true}
        },
        {
            "name": "search_text",
            "title": "Search text",
            "description": "Search file contents with ripgrep (argv form, never a shell). At most 100 hits per call.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "pattern": {"type": "string", "maxLength": 4096},
                    "dir": {"type": "string", "maxLength": 4096},
                    "glob": {"type": "string", "maxLength": 256}
                },
                "required": ["pattern"]
            },
            "annotations": {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
        },
        {
            "name": "write_file",
            "title": "Write file",
            "description": "Write content to a file inside the workspace roots. mode=create refuses when the file exists; mode=overwrite must be chosen explicitly. Needs a confirmation grant.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "maxLength": 4096},
                    "content": {"type": "string", "maxLength": 1048576},
                    "mode": {"type": "string", "enum": ["create", "overwrite"]}
                },
                "required": ["path", "content", "mode"]
            },
            "annotations": {"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": false}
        }
    ])
}

fn definition(name: &str) -> Option<Value> {
    definitions()
        .as_array()
        .expect("definitions are an array")
        .iter()
        .find(|entry| entry["name"].as_str() == Some(name))
        .cloned()
}

// ---------------------------------------------------------------------------
// Argument validation — the Lua original's hand-rolled, bounded JSON
// Schema subset check. Unknown properties are rejected: fail closed
// on shapes that were not declared. Messages are the baseline's.

fn check_array(key: &str, value: &Value, prop: &Value) -> Result<(), String> {
    let items = value
        .as_array()
        .ok_or_else(|| format!("argument {key} must be an array"))?;
    if let Some(min) = prop["minItems"].as_u64()
        && (items.len() as u64) < min
    {
        return Err(format!("argument {key} needs at least {min} items"));
    }
    if let Some(max) = prop["maxItems"].as_u64()
        && (items.len() as u64) > max
    {
        return Err(format!("argument {key} exceeds {max} items"));
    }
    if let Some(item_schema) = prop.get("items") {
        for (index, item) in items.iter().enumerate() {
            check_value(&format!("{key}[{}]", index + 1), item, item_schema)?;
        }
    }
    Ok(())
}

fn is_integer(value: &Value) -> Option<f64> {
    let number = value.as_number()?;
    if number.is_i64() || number.is_u64() {
        return number.as_f64();
    }
    let f = number.as_f64()?;
    if f.is_finite() && f.fract() == 0.0 {
        Some(f)
    } else {
        None
    }
}

fn check_value(key: &str, value: &Value, prop: &Value) -> Result<(), String> {
    match prop["type"].as_str() {
        Some("string") => {
            let text = value
                .as_str()
                .ok_or_else(|| format!("argument {key} must be a string"))?;
            if let Some(min) = prop["minLength"].as_u64()
                && (text.len() as u64) < min
            {
                return Err(format!("argument {key} is too short"));
            }
            if let Some(max) = prop["maxLength"].as_u64()
                && (text.len() as u64) > max
            {
                return Err(format!("argument {key} exceeds {max} bytes"));
            }
        }
        Some("integer") => {
            let number =
                is_integer(value).ok_or_else(|| format!("argument {key} must be an integer"))?;
            if let Some(min) = prop["minimum"].as_f64()
                && number < min
            {
                return Err(format!(
                    "argument {key} is below minimum {}",
                    prop["minimum"]
                ));
            }
            if let Some(max) = prop["maximum"].as_f64()
                && number > max
            {
                return Err(format!(
                    "argument {key} exceeds maximum {}",
                    prop["maximum"]
                ));
            }
        }
        Some("boolean") => {
            if !value.is_boolean() {
                return Err(format!("argument {key} must be a boolean"));
            }
        }
        Some("array") => check_array(key, value, prop)?,
        Some("object") => {
            if !value.is_object() {
                return Err(format!("argument {key} must be an object"));
            }
        }
        _ => return Err(format!("argument {key} has an unsupported schema type")),
    }
    if let Some(choices) = prop.get("enum").and_then(Value::as_array)
        && !choices.iter().any(|choice| choice == value)
    {
        return Err(format!("argument {key} is not one of the allowed values"));
    }
    Ok(())
}

fn validate_args(schema: &Value, args: &Map<String, Value>) -> Result<(), String> {
    if let Some(required) = schema.get("required").and_then(Value::as_array) {
        for key in required.iter().filter_map(Value::as_str) {
            if !args.contains_key(key) {
                return Err(format!("missing required argument: {key}"));
            }
        }
    }
    let empty = Map::new();
    let properties = schema
        .get("properties")
        .and_then(Value::as_object)
        .unwrap_or(&empty);
    for (key, value) in args {
        let Some(prop) = properties.get(key) else {
            return Err(format!("unknown argument: {key}"));
        };
        check_value(key, value, prop)?;
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Small shared helpers.

/// The baseline's result text cap.
fn tool_text(text: &str, is_error: bool) -> (String, bool) {
    if text.len() > CONTENT_BYTES_MAX {
        let mut cut = CONTENT_BYTES_MAX;
        while !text.is_char_boundary(cut) {
            cut -= 1;
        }
        return (format!("{}\n[output truncated]", &text[..cut]), is_error);
    }
    (text.to_string(), is_error)
}

fn truncate(text: &str, limit: usize) -> String {
    if text.len() > limit {
        let mut cut = limit;
        while !text.is_char_boundary(cut) {
            cut -= 1;
        }
        format!("{} [truncated]", &text[..cut])
    } else {
        text.to_string()
    }
}

/// The OS error text the way Lua's io errors render it: the plain
/// strerror message, without std's " (os error N)" suffix.
fn os_error_text(error: &std::io::Error) -> String {
    let text = error.to_string();
    if let Some(raw) = error.raw_os_error() {
        let suffix = format!(" (os error {raw})");
        if let Some(stripped) = text.strip_suffix(&suffix) {
            return stripped.to_string();
        }
    }
    text
}

/// "cannot read file: <path>: <strerror>" — the Lua io.open error
/// shape (its message already embeds the path).
fn cannot_read(path: &str, error: &std::io::Error) -> (String, bool) {
    tool_text(
        &format!("cannot read file: {path}: {}", os_error_text(error)),
        true,
    )
}

fn has_executable(name: &str) -> bool {
    let Some(path_var) = std::env::var_os("PATH") else {
        return false;
    };
    std::env::split_paths(&path_var).any(|dir| {
        let candidate = dir.join(name);
        is_executable_file(&candidate)
    })
}

#[cfg(unix)]
fn is_executable_file(path: &std::path::Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    std::fs::metadata(path)
        .map(|meta| meta.is_file() && meta.permissions().mode() & 0o111 != 0)
        .unwrap_or(false)
}

#[cfg(not(unix))]
fn is_executable_file(path: &std::path::Path) -> bool {
    path.is_file()
}

/// A finished subprocess: exit code (None when the process died by
/// signal or was killed at the timeout — the Lua original's
/// result.code is nil then too), and its captured streams.
struct ProcessOutcome {
    code: Option<i32>,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
}

fn drain_stream<R: Read + Send + 'static>(mut stream: R) -> std::thread::JoinHandle<Vec<u8>> {
    std::thread::spawn(move || {
        let mut collected = Vec::new();
        let mut chunk = [0u8; 8192];
        loop {
            match stream.read(&mut chunk) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    if collected.len() < STREAM_COLLECT_MAX {
                        let take = (STREAM_COLLECT_MAX - collected.len()).min(n);
                        collected.extend_from_slice(&chunk[..take]);
                    }
                }
            }
        }
        collected
    })
}

/// Run an argv array (never a shell) with a timeout. Spawn failure is
/// the only Err; a timeout kills the child and reports code None.
fn run_bounded(
    argv: &[String],
    cwd: Option<&str>,
    timeout: Duration,
) -> Result<ProcessOutcome, String> {
    let mut command = Command::new(&argv[0]);
    command
        .args(&argv[1..])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if let Some(dir) = cwd {
        command.current_dir(dir);
    }
    let mut child = command
        .spawn()
        .map_err(|error| format!("failed to start: {error}"))?;
    let stdout_reader = drain_stream(child.stdout.take().expect("stdout piped"));
    let stderr_reader = drain_stream(child.stderr.take().expect("stderr piped"));
    let deadline = Instant::now() + timeout;
    let code = loop {
        match child.try_wait() {
            Ok(Some(status)) => break status.code(),
            Ok(None) => {
                if Instant::now() >= deadline {
                    let _ = child.kill();
                    let _ = child.wait();
                    break None;
                }
                std::thread::sleep(Duration::from_millis(5));
            }
            Err(error) => return Err(format!("wait failed: {error}")),
        }
    };
    let stdout = stdout_reader.join().unwrap_or_default();
    let stderr = stderr_reader.join().unwrap_or_default();
    Ok(ProcessOutcome {
        code,
        stdout,
        stderr,
    })
}

fn code_text(code: Option<i32>) -> String {
    match code {
        Some(code) => code.to_string(),
        None => "nil".to_string(),
    }
}

fn arg_string<'a>(args: &'a Map<String, Value>, key: &str) -> Option<&'a str> {
    args.get(key).and_then(Value::as_str)
}

fn arg_integer(args: &Map<String, Value>, key: &str) -> Option<i64> {
    args.get(key).and_then(is_integer).map(|f| f as i64)
}

// ---------------------------------------------------------------------------
// Handlers. Each returns Ok((text, is_error)) for an in-band answer
// or Err(PolicyError) for a protocol error — the Lua original's
// (result | nil, err) shape exactly.

type HandlerResult = Result<(String, bool), PolicyError>;

fn handle_read_file(policy: &Policy, args: &Map<String, Value>) -> HandlerResult {
    let scoped = policy.scope_path(arg_string(args, "path").expect("validated"))?;
    let offset = arg_integer(args, "offset").unwrap_or(1);
    let limit = arg_integer(args, "limit")
        .unwrap_or(READ_LINES_MAX)
        .min(READ_LINES_MAX);
    let file = match std::fs::File::open(&scoped) {
        Ok(file) => file,
        Err(error) => return Ok(cannot_read(&scoped, &error)),
    };
    let mut reader = BufReader::new(file);
    let mut lines: Vec<String> = Vec::new();
    let mut index: i64 = 0;
    let mut bytes: usize = 0;
    let mut truncated = false;
    let mut raw: Vec<u8> = Vec::new();
    loop {
        raw.clear();
        match reader.read_until(b'\n', &mut raw) {
            Ok(0) => break,
            Ok(_) => {}
            Err(_) => break,
        }
        if raw.last() == Some(&b'\n') {
            raw.pop();
        }
        index += 1;
        if index >= offset {
            if lines.len() as i64 >= limit || bytes > CONTENT_BYTES_MAX {
                truncated = true;
                break;
            }
            let mut line = String::from_utf8_lossy(&raw).into_owned();
            if line.len() > READ_LINE_BYTES_MAX {
                let mut cut = READ_LINE_BYTES_MAX;
                while !line.is_char_boundary(cut) {
                    cut -= 1;
                }
                line = format!("{} [line truncated]", &line[..cut]);
            }
            bytes += line.len() + 1;
            lines.push(line);
        }
    }
    let mut text = lines.join("\n");
    if truncated && bytes > CONTENT_BYTES_MAX {
        text = format!("{text}\n[output truncated at {CONTENT_BYTES_MAX} bytes]");
    }
    Ok(tool_text(&text, false))
}

/// Minimal glob: `*` matches any run, `?` one char, everything else
/// literal — the same restricted language the Lua original compiles
/// to a pattern for list_files/search_text name filtering.
fn glob_matches(glob: &str, name: &str) -> bool {
    let pattern: Vec<char> = glob.chars().collect();
    let text: Vec<char> = name.chars().collect();
    let (mut p, mut t) = (0usize, 0usize);
    let (mut star_p, mut star_t) = (usize::MAX, 0usize);
    while t < text.len() {
        if p < pattern.len() && (pattern[p] == '?' || pattern[p] == text[t]) {
            p += 1;
            t += 1;
        } else if p < pattern.len() && pattern[p] == '*' {
            star_p = p;
            star_t = t;
            p += 1;
        } else if star_p != usize::MAX {
            p = star_p + 1;
            star_t += 1;
            t = star_t;
        } else {
            return false;
        }
    }
    while p < pattern.len() && pattern[p] == '*' {
        p += 1;
    }
    p == pattern.len()
}

fn handle_list_files(policy: &Policy, args: &Map<String, Value>) -> HandlerResult {
    let dir_arg = arg_string(args, "dir")
        .map(str::to_string)
        .unwrap_or_else(|| policy.roots()[0].clone());
    let scoped = policy.scope_path(&dir_arg)?;
    let metadata = std::fs::metadata(&scoped);
    match metadata {
        Err(_) => return Ok(tool_text(&format!("directory not found: {dir_arg}"), true)),
        Ok(meta) if !meta.is_dir() => {
            return Ok(tool_text(&format!("not a directory: {dir_arg}"), true));
        }
        Ok(_) => {}
    }
    let glob = arg_string(args, "glob");
    if let Some(glob) = glob
        && glob.chars().any(|c| c.is_control())
    {
        return Err(PolicyError {
            code: INVALID_PARAMS_CODE,
            message: "glob contains control characters".to_string(),
        });
    }
    let reader = match std::fs::read_dir(&scoped) {
        Ok(reader) => reader,
        Err(_) => return Ok(tool_text("directory listing is unavailable", true)),
    };
    let mut entries: Vec<String> = Vec::new();
    let mut truncated = false;
    for entry in reader {
        let entry = match entry {
            Ok(entry) => entry,
            Err(error) => {
                return Ok(tool_text(&format!("cannot list directory: {error}"), true));
            }
        };
        let name = entry.file_name().to_string_lossy().into_owned();
        if let Some(glob) = glob
            && !glob_matches(glob, &name)
        {
            continue;
        }
        if entries.len() >= LIST_ENTRIES_MAX {
            truncated = true;
            break;
        }
        let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
        entries.push(if is_dir { format!("{name}/") } else { name });
    }
    entries.sort();
    let mut text = entries.join("\n");
    if truncated {
        text = format!("{text}\n[truncated at {LIST_ENTRIES_MAX} entries]");
    }
    Ok(tool_text(&text, false))
}

fn handle_search_text(policy: &Policy, args: &Map<String, Value>) -> HandlerResult {
    let dir_arg = arg_string(args, "dir")
        .map(str::to_string)
        .unwrap_or_else(|| policy.roots()[0].clone());
    let scoped = policy.scope_path(&dir_arg)?;
    if !has_executable("rg") {
        return Ok(tool_text(
            "search_text requires ripgrep (rg), which is not installed",
            true,
        ));
    }
    // argv form only: the pattern travels as one literal argument,
    // so shell metacharacters in it can never be interpreted.
    let mut argv = vec![
        "rg".to_string(),
        "--no-heading".to_string(),
        "--line-number".to_string(),
        "--no-messages".to_string(),
        "--max-count".to_string(),
        SEARCH_HITS_MAX.to_string(),
        "-e".to_string(),
        arg_string(args, "pattern").expect("validated").to_string(),
    ];
    if let Some(glob) = arg_string(args, "glob") {
        argv.push("-g".to_string());
        argv.push(glob.to_string());
    }
    argv.push("--".to_string());
    argv.push(scoped);
    let outcome = match run_bounded(&argv, None, Duration::from_millis(SEARCH_TIMEOUT_MS)) {
        Ok(outcome) => outcome,
        Err(error) => return Ok(tool_text(&format!("search {error}"), true)),
    };
    if outcome.code == Some(1) {
        return Ok(tool_text("no matches", false));
    }
    if outcome.code != Some(0) {
        let stderr = String::from_utf8_lossy(&outcome.stderr).into_owned();
        return Ok(tool_text(
            &format!(
                "search failed (exit {}): {}",
                code_text(outcome.code),
                truncate(&stderr, 2048)
            ),
            true,
        ));
    }
    let stdout = String::from_utf8_lossy(&outcome.stdout).into_owned();
    let mut hits: Vec<String> = Vec::new();
    for line in stdout.split('\n') {
        if line.is_empty() {
            continue;
        }
        if hits.len() >= SEARCH_HITS_MAX {
            break;
        }
        let mut line = line.to_string();
        if line.len() > READ_LINE_BYTES_MAX {
            let mut cut = READ_LINE_BYTES_MAX;
            while !line.is_char_boundary(cut) {
                cut -= 1;
            }
            line = format!("{} [line truncated]", &line[..cut]);
        }
        hits.push(line);
    }
    Ok(tool_text(&hits.join("\n"), false))
}

const PHASE1_LINTERS: [(&str, &[&str]); 3] = [
    ("lua", &["luacheck", "--no-color"]),
    (
        "py",
        &["ruff", "check", "--output-format=concise", "--no-cache"],
    ),
    ("sh", &["shellcheck", "-f", "gcc"]),
];

fn handle_get_diagnostics(policy: &Policy, args: &Map<String, Value>) -> HandlerResult {
    let argv: Vec<String>;
    if let Some(path) = arg_string(args, "path") {
        let scoped = policy.scope_path(path)?;
        // The Lua original's `%.([^./]+)$`: the extension is the
        // run after the basename's last dot, at least one character.
        let ext = scoped
            .rsplit('/')
            .next()
            .and_then(|base| base.rsplit_once('.'))
            .map(|(_stem, ext)| ext)
            .filter(|ext| !ext.is_empty());
        let spec = ext.and_then(|ext| {
            PHASE1_LINTERS
                .iter()
                .find(|(name, _argv)| *name == ext)
                .map(|(_name, argv)| *argv)
        });
        let Some(spec) = spec else {
            return Ok(tool_text(
                &format!("no phase-1 linter for extension .{}", ext.unwrap_or("?")),
                true,
            ));
        };
        if !has_executable(spec[0]) {
            return Ok(tool_text(
                &format!("linter not installed: {}", spec[0]),
                true,
            ));
        }
        let mut built: Vec<String> = spec.iter().map(|s| s.to_string()).collect();
        built.push(scoped);
        argv = built;
    } else {
        if !has_executable("luacheck") {
            return Ok(tool_text("linter not installed: luacheck", true));
        }
        argv = vec![
            "luacheck".to_string(),
            "--no-color".to_string(),
            policy.roots()[0].clone(),
        ];
    }
    let outcome = match run_bounded(&argv, None, Duration::from_millis(DIAG_TIMEOUT_MS)) {
        Ok(outcome) => outcome,
        Err(error) => return Ok(tool_text(&format!("diagnostics {error}"), true)),
    };
    let mut output = String::from_utf8_lossy(&outcome.stdout).into_owned();
    output.push_str(&String::from_utf8_lossy(&outcome.stderr));
    let output = truncate(&output, OUTPUT_BYTES_MAX);
    if output.is_empty() {
        return Ok(tool_text("no issues", false));
    }
    // Linters exit nonzero when they find things; findings are data.
    Ok(tool_text(&output, false))
}

fn handle_write_file(policy: &Policy, args: &Map<String, Value>) -> HandlerResult {
    let path_arg = arg_string(args, "path").expect("validated");
    let scoped = policy.scope_path(path_arg)?;
    let content = arg_string(args, "content").expect("validated");
    if arg_string(args, "mode") == Some("create") && std::fs::File::open(&scoped).is_ok() {
        return Ok(tool_text(
            &format!("file exists; mode=create refuses to overwrite: {path_arg}"),
            true,
        ));
    }
    // Best-effort parent creation; the write itself still fails
    // loudly when creation did not happen (the Lua original's
    // mkdir_p contract).
    if let Some(parent) = std::path::Path::new(&scoped).parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    match std::fs::write(&scoped, content.as_bytes()) {
        Ok(()) => Ok(tool_text(
            &format!("wrote {} bytes to {path_arg}", content.len()),
            false,
        )),
        Err(error) => Ok(tool_text(
            &format!("cannot write file: {scoped}: {}", os_error_text(&error)),
            true,
        )),
    }
}

/// Read a whole file up to a byte cap, with the Lua original's
/// error texts ("cannot read file: ..." / "file exceeds N bytes").
fn read_whole(path: &str, byte_max: usize) -> Result<Vec<u8>, (String, bool)> {
    let mut file = std::fs::File::open(path).map_err(|error| cannot_read(path, &error))?;
    let mut content = Vec::new();
    file.read_to_end(&mut content)
        .map_err(|error| cannot_read(path, &error))?;
    if content.len() > byte_max {
        return Err(tool_text(
            &format!("cannot read file: file exceeds {byte_max} bytes"),
            true,
        ));
    }
    Ok(content)
}

fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    if needle.is_empty() || haystack.len() < needle.len() {
        return None;
    }
    haystack
        .windows(needle.len())
        .position(|window| window == needle)
}

/// Exact-match replacement only: zero matches or more than one
/// match both fail loudly. The tool never fuzzes, so a typo cannot
/// rewrite the wrong text.
fn handle_edit_file(policy: &Policy, args: &Map<String, Value>) -> HandlerResult {
    let scoped = policy.scope_path(arg_string(args, "path").expect("validated"))?;
    let content = match read_whole(&scoped, CONTENT_BYTES_MAX) {
        Ok(content) => content,
        Err(text) => return Ok(text),
    };
    let old_text = arg_string(args, "old_text").expect("validated").as_bytes();
    let new_text = arg_string(args, "new_text").expect("validated");
    let Some(first) = find_subslice(&content, old_text) else {
        return Ok(tool_text("old_text not found; no changes made", true));
    };
    let rest = &content[first + old_text.len()..];
    if find_subslice(rest, old_text).is_some() {
        return Ok(tool_text(
            "old_text matches more than once; refusing ambiguous edit",
            true,
        ));
    }
    let mut updated = Vec::with_capacity(content.len() - old_text.len() + new_text.len());
    updated.extend_from_slice(&content[..first]);
    updated.extend_from_slice(new_text.as_bytes());
    updated.extend_from_slice(rest);
    match std::fs::write(&scoped, &updated) {
        Ok(()) => Ok(tool_text(
            &format!(
                "replaced 1 occurrence ({} -> {} bytes)",
                old_text.len(),
                new_text.len()
            ),
            false,
        )),
        Err(error) => Ok(tool_text(
            &format!("cannot write file: {scoped}: {}", os_error_text(&error)),
            true,
        )),
    }
}

fn handle_run_command(policy: &Policy, args: &Map<String, Value>) -> HandlerResult {
    let cmd: Vec<String> = args["cmd"]
        .as_array()
        .expect("validated")
        .iter()
        .map(|item| item.as_str().expect("validated").to_string())
        .collect();
    let checked = policy.check_command(&cmd, arg_string(args, "cwd"))?;
    let program = &checked.argv[0];
    if !has_executable(program) {
        return Ok(tool_text(
            &format!("command not found on PATH: {program}"),
            true,
        ));
    }
    // argv form only: each element is passed literally, never
    // through a shell.
    let timeout_ms = arg_integer(args, "timeout_ms")
        .map(|value| value as u64)
        .unwrap_or(COMMAND_TIMEOUT_MS_DEFAULT);
    let outcome = match run_bounded(
        &checked.argv,
        checked.cwd.as_deref(),
        Duration::from_millis(timeout_ms),
    ) {
        Ok(outcome) => outcome,
        Err(error) => return Ok(tool_text(&format!("command {error}"), true)),
    };
    let mut output = String::from_utf8_lossy(&outcome.stdout).into_owned();
    output.push_str(&String::from_utf8_lossy(&outcome.stderr));
    let output = truncate(&output, OUTPUT_BYTES_MAX);
    Ok(tool_text(
        &format!("exit code: {}\n{output}", code_text(outcome.code)),
        outcome.code != Some(0),
    ))
}

// ---------------------------------------------------------------------------
// Dispatch — the Lua tools.call flow: unknown tool / bad shape /
// policy refusal are protocol errors; failures while running are
// isError results. Never panics across the boundary (a handler panic
// is the baseline's -32603 "tool handler failed").

/// A tools/call outcome: an in-band result, or a protocol refusal
/// with the baseline's code and message.
#[derive(Debug, PartialEq, Eq)]
pub enum CallOutcome {
    Result { text: String, is_error: bool },
    Refusal { code: i32, message: String },
}

fn audit_target(args: &Map<String, Value>) -> String {
    for key in ["path", "dir", "pattern"] {
        if let Some(value) = arg_string(args, key) {
            return truncate(value, 256);
        }
    }
    if let Some(first) = args
        .get("cmd")
        .and_then(Value::as_array)
        .and_then(|items| items.first())
        .and_then(Value::as_str)
    {
        return truncate(first, 256);
    }
    String::new()
}

pub fn call(
    policy: &Policy,
    name: &str,
    args: &Map<String, Value>,
    grant: Option<&str>,
) -> CallOutcome {
    let Some(def) = definition(name) else {
        policy.audit(name, "", "unknown-tool");
        return CallOutcome::Refusal {
            code: INVALID_PARAMS_CODE,
            message: format!("unknown tool: {name}"),
        };
    };
    let target = audit_target(args);
    if let Err(message) = validate_args(&def["inputSchema"], args) {
        policy.audit(name, &target, "invalid-args");
        return CallOutcome::Refusal {
            code: INVALID_PARAMS_CODE,
            message,
        };
    }
    if let Err(reason) = policy.check_approval(name, grant) {
        policy.audit(name, &target, "denied");
        return CallOutcome::Refusal {
            code: crate::policy::POLICY_DENIED_CODE,
            message: reason,
        };
    }
    let handler = match name {
        "edit_file" => handle_edit_file,
        "get_diagnostics" => handle_get_diagnostics,
        "list_files" => handle_list_files,
        "read_file" => handle_read_file,
        "run_command" => handle_run_command,
        "search_text" => handle_search_text,
        "write_file" => handle_write_file,
        _ => unreachable!("definition without a handler: {name}"),
    };
    let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| handler(policy, args)));
    match outcome {
        Err(_) => {
            policy.audit(name, &target, "crashed");
            CallOutcome::Refusal {
                code: ERR_INTERNAL,
                message: "tool handler failed".to_string(),
            }
        }
        Ok(Err(error)) => {
            policy.audit(name, &target, "handler-error");
            CallOutcome::Refusal {
                code: error.code,
                message: error.message,
            }
        }
        Ok(Ok((text, is_error))) => {
            policy.audit(name, &target, "allowed");
            CallOutcome::Result { text, is_error }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_is_the_baselines_seven_sorted() {
        let defs = definitions();
        let names: Vec<&str> = defs
            .as_array()
            .unwrap()
            .iter()
            .map(|entry| entry["name"].as_str().unwrap())
            .collect();
        assert_eq!(
            names,
            [
                "edit_file",
                "get_diagnostics",
                "list_files",
                "read_file",
                "run_command",
                "search_text",
                "write_file"
            ]
        );
        for entry in defs.as_array().unwrap() {
            let annotations = &entry["annotations"];
            for hint in [
                "readOnlyHint",
                "destructiveHint",
                "idempotentHint",
                "openWorldHint",
            ] {
                assert!(
                    annotations[hint].is_boolean(),
                    "{} missing {hint}",
                    entry["name"]
                );
            }
        }
    }

    #[test]
    fn validation_messages_match_the_baseline() {
        let def = definition("read_file").unwrap();
        let schema = &def["inputSchema"];
        let mut args = Map::new();
        assert_eq!(
            validate_args(schema, &args).unwrap_err(),
            "missing required argument: path"
        );
        args.insert("path".to_string(), json!(42));
        assert_eq!(
            validate_args(schema, &args).unwrap_err(),
            "argument path must be a string"
        );
        args.insert("path".to_string(), json!("x"));
        args.insert("bogus".to_string(), json!(1));
        assert_eq!(
            validate_args(schema, &args).unwrap_err(),
            "unknown argument: bogus"
        );
        args.remove("bogus");
        args.insert("offset".to_string(), json!(0));
        assert_eq!(
            validate_args(schema, &args).unwrap_err(),
            "argument offset is below minimum 1"
        );
    }

    #[test]
    fn glob_matcher_handles_the_restricted_language() {
        assert!(glob_matches("*.txt", "a.txt"));
        assert!(!glob_matches("*.txt", "a.lua"));
        assert!(glob_matches("a?c", "abc"));
        assert!(!glob_matches("a?c", "ac"));
        assert!(glob_matches("*", "anything"));
        assert!(glob_matches("a*", "a"));
    }
}
