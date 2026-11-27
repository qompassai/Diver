# Benchmarks

Machine: primo — 13th Gen Intel i7-13620H, 16 threads, 62 GiB RAM, cargo 1.100.0 (2026-11-05).
Method: hand-rolled `std::time` harness in `benches/hot_paths.rs` (harness = false), named-constant workloads, warmup before timed loops, results printed as ns/op and ops/s.
Note: primo was under multi-lane load tonight (load average ~40+ at times), so these numbers are baselines, not peaks; expect substantial run-to-run variance on cold start in particular.

Server: `diver-mcp-server` (release bench profile; server binary located beside the bench via the primo `build/<pkg>/<hash>/out/` layout).

Workloads:
- `cold_start_discover_and_tools_list`: spawn server (`--root . --no-audit`), send `server/discover` + `tools/list` (modern era 2026-07-28), 10 reps.
- `tool_call_list_files`: one warm session, 20 warmup + 200 timed `tools/call list_files {}` (read-only).

Results (2026-11-27):
- cold_start_discover_and_tools_list: 16,088,968 ns/op (~16.1 ms) over 10 reps (an earlier run under heavier load measured 33.3 ms)
- tool_call_list_files: 608,102 ns/op (~0.61 ms), 1,644.5 ops/s over 200 calls (earlier run: 783,090 ns/op, 1,277.0 ops/s)

Example: `cargo run --example stdio_session` — discover → tools/list (7 tools) → one `list_files` call, transcript summary printed.
