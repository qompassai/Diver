//! Wire battery: drive the built binary over stdio through the
//! modern session shape and the baseline's case classes — happy
//! paths, policy outcomes (auto / confirm-denied / grant /
//! allowlist), error classes, and the F-1 empty-arguments shape.

use std::io::{BufRead, BufReader, Write};
use std::process::{Child, Command, Stdio};

use serde_json::{Value, json};

const MODERN_META: &str = r#"{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientInfo":{"name":"test","version":"0"},"io.modelcontextprotocol/clientCapabilities":{}}"#;

struct Fixture {
    dir: std::path::PathBuf,
}

impl Fixture {
    fn new() -> Fixture {
        let dir =
            std::env::temp_dir().join(format!("diver-mcp-server-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(dir.join("sub")).unwrap();
        std::fs::write(dir.join("hello.txt"), "line one\nline two\nline three\n").unwrap();
        std::fs::write(dir.join("sub/code.lua"), "local M = {}\nreturn M\n").unwrap();
        Fixture { dir }
    }

    fn path(&self) -> String {
        self.dir.to_string_lossy().into_owned()
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

struct Session {
    child: Child,
    stdin: std::process::ChildStdin,
    stdout: BufReader<std::process::ChildStdout>,
    next_id: u64,
}

impl Session {
    fn spawn(fixture: &Fixture) -> Session {
        let mut child = Command::new(env!("CARGO_BIN_EXE_diver-mcp-server"))
            .args([
                "--root",
                &fixture.path(),
                "--grant-token",
                "tok",
                "--allow-command",
                "echo",
                "--no-audit",
            ])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .expect("spawn server");
        let stdin = child.stdin.take().expect("stdin");
        let stdout = BufReader::new(child.stdout.take().expect("stdout"));
        Session {
            child,
            stdin,
            stdout,
            next_id: 1,
        }
    }

    fn request(&mut self, method: &str, params: Value) -> Value {
        let id = self.next_id;
        self.next_id += 1;
        let frame = json!({"jsonrpc": "2.0", "id": id, "method": method, "params": params});
        writeln!(self.stdin, "{frame}").expect("write request");
        self.stdin.flush().expect("flush");
        let mut line = String::new();
        loop {
            line.clear();
            let read = self.stdout.read_line(&mut line).expect("read response");
            assert!(read > 0, "server closed stdout answering {method}");
            let response: Value = serde_json::from_str(&line).expect("response is JSON");
            if response["id"] == json!(id) {
                return response;
            }
        }
    }

    fn call(&mut self, name: &str, arguments: Value, grant: bool) -> Value {
        let mut meta: Value = serde_json::from_str(MODERN_META).unwrap();
        if grant {
            meta["grant"] = json!("tok");
        }
        self.request(
            "tools/call",
            json!({"name": name, "arguments": arguments, "_meta": meta}),
        )
    }

    fn text(&mut self, name: &str, arguments: Value, grant: bool) -> (String, bool) {
        let response = self.call(name, arguments, grant);
        let result = &response["result"];
        let text = result["content"][0]["text"]
            .as_str()
            .unwrap_or_else(|| panic!("call {name} returned no text content: {response}"));
        (
            text.to_string(),
            result["isError"].as_bool().unwrap_or(false),
        )
    }
}

impl Drop for Session {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

#[test]
fn wire_battery() {
    let fixture = Fixture::new();
    let mut session = Session::spawn(&fixture);

    // Discover: exactly one supported version, the baseline's
    // identity and instructions.
    let discover = session.request(
        "server/discover",
        json!({"_meta": serde_json::from_str::<Value>(MODERN_META).unwrap()}),
    );
    let result = &discover["result"];
    assert_eq!(result["supportedVersions"], json!(["2026-07-28"]));
    assert_eq!(result["ttlMs"], json!(3600000));
    assert_eq!(result["cacheScope"], json!("public"));
    let info: Value = serde_json::from_str(MODERN_META).unwrap();
    let _ = info;
    assert!(
        result["instructions"]
            .as_str()
            .unwrap()
            .starts_with("Diver MCP server.")
    );

    // Legacy contact: the designed refusal, connection stays up.
    let legacy = session.request(
        "initialize",
        json!({"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "x", "version": "0"}}),
    );
    assert_eq!(legacy["error"]["code"], json!(-32022));
    assert_eq!(legacy["error"]["data"]["requested"], json!("2025-11-25"));
    assert_eq!(legacy["error"]["data"]["supported"], json!(["2026-07-28"]));

    // tools/list: the seven baseline tools, in order.
    let list = session.request(
        "tools/list",
        json!({"_meta": serde_json::from_str::<Value>(MODERN_META).unwrap()}),
    );
    let names: Vec<&str> = list["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|tool| tool["name"].as_str().unwrap())
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

    // Read happy path + window.
    let (text, is_error) = session.text("read_file", json!({"path": "hello.txt"}), false);
    assert_eq!(text, "line one\nline two\nline three");
    assert!(!is_error);
    let (text, _) = session.text(
        "read_file",
        json!({"path": "hello.txt", "offset": 2, "limit": 1}),
        false,
    );
    assert_eq!(text, "line two");

    // The F-1 shape end-to-end: list_files takes no required args.
    let (text, is_error) = session.text("list_files", json!({}), false);
    assert!(text.contains("hello.txt"), "listing: {text}");
    assert!(!is_error);

    // Error taxonomy: unknown tool and bad shapes are protocol
    // errors; a scope escape is -32602; a secret path is -32000.
    let unknown = session.call("nope", json!({}), false);
    assert_eq!(unknown["error"]["code"], json!(-32602));
    assert_eq!(unknown["error"]["message"], json!("unknown tool: nope"));
    let missing = session.call("read_file", json!({}), false);
    assert_eq!(
        missing["error"]["message"],
        json!("missing required argument: path")
    );
    let escape = session.call("read_file", json!({"path": "../outside.txt"}), false);
    assert_eq!(
        escape["error"]["message"],
        json!("path escapes workspace roots")
    );

    // Policy outcomes: write without a grant is denied; with the
    // grant it lands; create over an existing file is an in-band
    // failure.
    let denied = session.call(
        "write_file",
        json!({"path": "new.txt", "content": "abc", "mode": "create"}),
        false,
    );
    assert_eq!(denied["error"]["code"], json!(-32000));
    assert_eq!(
        denied["error"]["message"],
        json!("tool requires a confirmation grant: write_file")
    );
    let (text, is_error) = session.text(
        "write_file",
        json!({"path": "new.txt", "content": "abc", "mode": "create"}),
        true,
    );
    assert_eq!(text, "wrote 3 bytes to new.txt");
    assert!(!is_error);
    let (text, is_error) = session.text(
        "write_file",
        json!({"path": "new.txt", "content": "abc", "mode": "create"}),
        true,
    );
    assert!(text.starts_with("file exists; mode=create refuses"));
    assert!(is_error);

    // run_command: granted but not allowlisted is -32000; granted
    // and allowlisted runs argv-only.
    let not_listed = session.call("run_command", json!({"cmd": ["ls"]}), true);
    assert_eq!(
        not_listed["error"]["message"],
        json!("command not in allowlist: ls")
    );
    let (text, is_error) = session.text("run_command", json!({"cmd": ["echo", "hi"]}), true);
    assert_eq!(text, "exit code: 0\nhi\n");
    assert!(!is_error);

    // Ping (with the modern _meta every request carries) answers
    // an empty result. A meta-less ping is refused by the SDK
    // itself with -32602: in this era the _meta is not optional.
    let ping = session.request(
        "ping",
        json!({"_meta": serde_json::from_str::<Value>(MODERN_META).unwrap()}),
    );
    assert_eq!(ping["result"], json!({}));
}
