# Arch Wiki DAP Adapter Verdicts

<!-- Worker F — Phase 1 research. Every row in the Arch Wiki
     "Debug adapter protocol" table (fetched 2026-09-28) was checked
     against the adapter's own upstream source (not the wiki's word).

     Policy: the verdict is about the *listed package*, not the
     language. A CONFIRM means the listed package is a real DAP
     adapter; "covered" means Diver's lua/dap/ already debugs that
     language through that adapter (or an equivalent one). A DENY
     means the listed package is not a DAP adapter (LSP-only, native
     debugger with no DAP server, or miscategorised tooling).

     Do not stage or commit other workers' files with this one. -->

## Summary

- 34 wiki entries audited against primary sources.
- **18 CONFIRM** — the listed package really speaks DAP.
  - Already covered by `lua/dap/`: ansibug, bashdb (via
    vscode-bash-debug), cpptools (via LLDB/GDB DAP), gdb, delve,
    vscode-js-debug, java-debug, kotlin-debug-adapter,
    PowerShellEditorServices, debugpy, scala-debug-adapter,
    lldb-dap, crystal (via GDB/LLDB DAP).
  - **Not covered — Phase 2 candidates**: Dart SDK
    (`dart debug_adapter`), buildg (`buildg dap serve`), ElixirLS
    (debug adapter), Godot (built-in DAP), Earlybird (OCaml),
    Perl-LanguageServer (bundled DAP), vscDebugger (R).
  - **Exact-adapter gaps despite language coverage**: cpptools
    (OpenDebugAD7) and BugStalker (`bs --dap-local/--dap-remote`);
    both languages are covered through LLDB/GDB instead.
- **16 DENY** — language servers, native debuggers with no DAP
  server, GDB servers, and miscategorised tooling. Rationale per row.
- **1 discrepancy needing coordinator decision**: the wiki's Haskell
  entry is Well-Typed's official `hdb` (well-typed/haskell-debugger,
  a real DAP adapter for GHC 9.14+), *not* phoityne's
  haskell-debug-adapter that the three plan files (and worker B's
  lane) target. Diver's `lua/dap/haskell.lua` covers a different
  adapter than the wiki lists.

## Verdict table

| # | Wiki entry | Listed package | Verdict | Diver coverage | Rationale |
|---|-----------|----------------|---------|----------------|-----------|
| 1 | Arduino | openocd | **DENY** | — | OpenOCD is a GDB/JTAG remote server, not a DAP server. DAP only
via an adapter layer (e.g. VS Code's Cortex-Debug, or a GDB-DAP
bridge). Embedded C/C++ is already covered by `gdb.lua`/`lldb.lua`. |
| 2 | Ansible | ansibug | **CONFIRM** | `lua/dap/ansible.lua` | Existing module (workers A/B lane). |
| 3 | Bash | bashdb | **CONFIRM** | `lua/dap/bash.lua` | bashdb is the debugger; DAP is provided by the
vscode-bash-debug bridge (bashdb in `~/workspace/tools/dap/`
MANIFEST). The wiki conflates the debugger with the bridge; the
effective adapter chain is real. |
| 4 | C, C++, Objective-C | cpptools | **CONFIRM** | `lua/dap/gdb.lua`, `lua/dap/lldb.lua`,
`lua/dap/lldb-dap.lua` (languages covered; adapter not wired) |
OpenDebugAD7 (the cpptools debug adapter) is a real DAP adapter —
CodeLite drives `OpenDebugAD7 --server` as DAP (upstream
microsoft/vscode-cpptools docs). Diver covers C/C++/ObjC via
GDB/LLDB DAP instead; cpptools itself is an optional exact-adapter
addition, not a gap. |
| 5 | C# | omnisharp-roslyn | **DENY** | `lua/dap/csharp.lua` | omnisharp-roslyn is an LSP language
server, not DAP. The .NET DAP adapter is netcoredbg, which
`csharp.lua` already uses — the existing module is correct. |
| 6 | Crystal | crystal | **DENY** (direct) | `lua/dap/gdb.lua`, `lua/dap/lldb.lua` |
Crystal ships no DAP adapter of its own; compiled Crystal is native
code and debuggable through GDB/LLDB DAP, which already exist.
Language covered, exact-adapter entry does not exist. |
| 7 | Dart | Dart SDK | **CONFIRM** | **NEW candidate**: `lua/dap/dart.lua` |
The Dart SDK ships official DAP adapters: `dart debug_adapter` and
`dart debug_adapter --test` (upstream
`pkg/dds/tool/dap/README.md`, fetched 2026-09-28). |
| 8 | Dockerfile | buildg | **CONFIRM** | **NEW candidate**: `lua/dap/dockerfile.lua` |
Upstream buildg documents `buildg dap serve` over stdio and ships
Neovim examples (`examples/dap/README.md`, fetched 2026-09-28).
Earlier heuristics ("just a builder") were wrong. |
| 9 | Elixir | elixir-ls | **CONFIRM** | **NEW candidate**: `lua/dap/elixir.lua` |
ElixirLS ships a real DAP debugger (`debug_adapter.sh` launch
configurations, interpreted-module debugging). Being an LSP as well
does not disqualify it. |
| 10 | Elm | elm-language-server | **DENY** | — | LSP-only language server; no
debugging capability, no DAP adapter. |
| 11 | Flow | flow | **DENY** | — | Static type checker for JavaScript;
ships no debugger or DAP adapter. |
| 12 | Fortran | gdb | **CONFIRM** | `lua/dap/gdb.lua` | GDB's `-i=dap` DAP
mode covers Fortran. (Note: `gdb.lua` currently has uncommitted
changes from another worker lane — not touched.) |
| 13 | GDScript | godot | **CONFIRM** | **NEW candidate**: `lua/dap/godot.lua` |
The Godot editor exposes built-in DAP support for GDScript on its
debug-adapter TCP port (upstream plugin changelog + project
article, fetched 2026-09-28). |
| 14 | Go | delve | **CONFIRM** | `lua/dap/go.lua` | Existing module; delve
in `~/workspace/tools/dap/` MANIFEST. |
| 15 | Haskell | ghc (official) | **CONFIRM — DISCREPANCY** | `lua/dap/haskell.lua`
(covers a *different* adapter) | The wiki's link
(well-typed.github.io/haskell-debugger) is `hdb`
(well-typed/haskell-debugger): "a modern step-through debugger for
GHC Haskell" whose README states "Since `hdb` implements the Debug
Adapter Protocol (DAP)" — for GHC 9.14+. It is a real, official
DAP adapter. But the three DAP plan files (and worker B's lane)
built `haskell.lua` against phoityne's `haskell-debug-adapter`
instead. Coordinator decision needed: adopt the wiki's official
`hdb`, keep phoityne, or wire both. |
| 16 | JavaScript | vscode-js-debug | **CONFIRM** | `lua/dap/node.lua` | Existing
module; vscode-js-debug in `~/workspace/tools/dap/` MANIFEST. |
| 17 | Java | java-debug | **CONFIRM** | `lua/dap/java.lua` | Existing module
(microsoft/java-debug is the well-known Java DAP adapter). |
| 18 | Kotlin | kotlin-debug-adapter | **CONFIRM** | `lua/dap/kotlin.lua` | Existing
module; adapter in `~/workspace/tools/dap/` MANIFEST, smoke-tested. |
| 19 | Lua | lua-stdlib `_debug` | **DENY** | — | Not a debugger at all: a
115-line MIT debug-hints registry (argcheck/deprecate/level/strict,
modes default/safe/fast). Already integrated into Moonwalk (commit
1e4ee5a, pushed 2026-09-28) — `debugger.lua` loads it and honors
`MOONWALK_DEBUG`. Nothing to add. |
| 20 | OCaml, Reason | earlybird | **CONFIRM** | **NEW candidate**:
`lua/dap/ocaml.lua` | Earlybird is a real DAP adapter for OCaml
bytecode (`opam install earlybird`; upstream
hackwaly/ocamlearlybird README). The old standalone VS Code
extension is deprecated; the adapter itself is current. |
| 21 | OmniSharp | omnisharp-roslyn | **DENY** | `lua/dap/csharp.lua` | Duplicate
listing of row 5 — same verdict and rationale (LSP, not DAP;
netcoredbg is the correct .NET DAP adapter). |
| 22 | Perl | Perl-LanguageServer | **CONFIRM** | **NEW candidate**:
`lua/dap/perl.lua` | richterger/Perl-LanguageServer bundles a real
DAP debug adapter (verified against upstream). The bundled debug
support is DAP-capable, not LSP-only. |
| 23 | PHP | phpdbg | **DENY** | `lua/dap/php.lua` | phpdbg is a PHP
SAPI/debugger, not a DAP server. Diver correctly uses
vscode-php-debug, which bridges DAP to Xdebug/DBGP — the existing
module is correct; the wiki's package is not DAP. |
| 24 | PowerShell | PowerShellEditorServices | **CONFIRM** | `lua/dap/powershell.lua`
| Existing module; adapter in `~/workspace/tools/dap/` MANIFEST.
Caveat recorded: debugger transport needs named pipes/Unix sockets
plus the session-details file — plain stdio disables debugging
(upstream README). |
| 25 | Python | debugpy | **CONFIRM** | `lua/dap/python.lua` | Existing module;
debugpy in `~/workspace/tools/dap/` MANIFEST. |
| 26 | R | vscDebugger | **CONFIRM** | **NEW candidate**: `lua/dap/r.lua` |
manuelhentschel/vscDebugger is a real (partial) DAP implementation:
upstream documents DAP request dispatch and socket transport
(upstream README + CONTRIBUTING.md, fetched 2026-09-28). |
| 27 | Rome | biome | **DENY** | — | Formatter/linter/LSP ("Rome"
was the predecessor project name). No debugger and no DAP adapter
exists for Biome. |
| 28 | Rust | bugstalker | **CONFIRM** | `lua/dap/rust.lua` (language covered via
lldb-dap; BugStalker not wired) | BugStalker 0.4+ speaks DAP:
stdio via `bs --dap-local`, TCP via `bs --dap-remote` (upstream
`doc/DAP.md`, fetched 2026-09-28). Exact adapter is an optional
addition; Rust is already debugged through `rust.lua`'s lldb-dap. |
| 29 | Ruby | byebug | **DENY** | `lua/dap/ruby.lua` | byebug is not a DAP
adapter. Diver correctly uses `rdbg` (Ruby's `debug` gem), which
does speak DAP — the existing module is correct. |
| 30 | Scala | scala-debug-adapter | **CONFIRM** | `lua/dap/scala.lua` | Existing
module; the adapter normally starts through BSP/Metals/Bloop
(`debug-adapter-start`), which `scala.lua` already drives. |
| 31 | SQL | pldebugger | **DENY** (direct) | `lua/dap/sql.lua`,
`lua/dap/postgres.lua` | pldebugger is a pldbgapi C extension, not
a DAP server. DAP exists only via a separate third-party bridge
(ng-galien/plpgsql-dap, translates DAP → pldbgapi). Existing SQL
modules cover the database-debugging path. |
| 32 | LaTeX | texlab | **DENY** | — | LSP-only language server; no
debugging capability. |
| 33 | TypeScript | vscode-js-debug | **CONFIRM** | `lua/dap/node.lua` | Same
adapter as row 16; one module covers both. |
| 34 | Zig | lldb | **CONFIRM** | `lua/dap/zig.lua` + `lua/dap/lldb-dap.lua` |
LLVM's `lldb-dap` is explicitly a standalone DAP command-line tool;
`zig.lua` already drives it. (Note: `lldb.lua`/`lldb-dap.lua`
currently have uncommitted changes from another lane — not touched.) |

## Phase 2 new-module candidates (ranked)

New `lua/dap/*.lua` modules warranted by confirmed adapters with no
Diver coverage:

1. `dart.lua` — Dart SDK `dart debug_adapter` / `--test` (official,
   documented).
2. `elixir.lua` — ElixirLS DAP debugger.
3. `godot.lua` — Godot editor's built-in GDScript DAP server (TCP).
4. `ocaml.lua` — Earlybird (`opam install earlybird`).
5. `perl.lua` — Perl-LanguageServer bundled DAP.
6. `r.lua` — vscDebugger (R).
7. `dockerfile.lua` — buildg `dap serve` (stdio).

Optional exact-adapter additions despite existing language coverage:

- cpptools (`OpenDebugAD7`) — row 4; languages already covered by
  GDB/LLDB DAP.
- BugStalker — row 28; Rust already covered by `rust.lua`'s lldb-dap.

## Overlaps and discrepancies with other lanes

- **Do not edit**: `lua/dap/zig.lua`, `lua/dap/haskell.lua`,
  `lua/dap/php.lua`, `lua/dap/ruby.lua`, `lua/dap/ansible.lua` —
  workers A/B territory. This file only notes verdicts about them.
- **Uncommitted foreign changes** observed 2026-09-28 (not staged,
  not committed, not touched): `lua/dap/TODO.md`,
  `lua/dap/ansible.lua`, `lua/dap/gdb.lua`, `lua/dap/init.lua`,
  `lua/dap/lldb-dap.lua`, `lua/dap/lldb.lua`, `lua/dap/php.lua`,
  `lua/dap/ruby.lua`, and new `lua/dap/renderdoc.lua`.
- **Haskell discrepancy (row 15)**: wiki lists official `hdb`; Diver
  (per the three plan files) built against phoityne's
  haskell-debug-adapter. Needs the coordinator's call.
- **Row 31 note**: `pldebugger` DENY is as listed — the separate
  `ng-galien/plpgsql-dap` bridge is real but is a different project,
  not the wiki's package.
- Renderdoc (`lua/dap/renderdoc.lua`, another lane's new file):
  independently confirmed as a non-DAP graphics helper (renderdoccmd
  wrapper), consistent with the wiki-page finding.

## Sources

- Arch Wiki: https://wiki.archlinux.org/title/Debug_adapter_protocol
  (fetched 2026-09-28).
- ktock/buildg `examples/dap/README.md`; dart-lang SDK
  `pkg/dds/tool/dap/README.md`; ElixirLS docs; Godot editor/plugin
  docs; godzie44/bugstalker `doc/DAP.md`;
  manuelhentschel/vscDebugger (README + CONTRIBUTING.md);
  hackwaly/ocamlearlybird README; PowerShell/PowerShellEditorServices
  README; CodeLite debugger docs (OpenDebugAD7 `--server`);
  microsoft/vscode-cpptools `Documentation/Debugger/How To Debug
  MIEngine.md`; well-typed/haskell-debugger README
  ("implements the Debug Adapter Protocol (DAP)");
  richterger/Perl-LanguageServer upstream. All fetched 2026-09-28.

## Authoritative report reconciliation (2026-09-28)

Source: `~/workspace/user/files/neovim-debuggers_0_z25f.md`
("Maintained Debuggers and Adapters for Neovim", September 2026) —
Matt's uploaded inventory. It **supersedes the wiki list** for
confirm/deny purposes: where the report corrects the wiki, the
report wins. The wiki rows above stand except as corrected here.

### Report-sourced DENY additions

Not debugger entries — do not add:

- Legacy Node V8 debug protocol (unmaintained, undocumented;
  Inspector/CDP via vscode-js-debug instead).
- `lldb-vscode` as a new-work target (renamed to `lldb-dap` in
  LLVM 18; prefer `lldb-dap`).
- LLDB-MI for new work (legacy).
- `pdb`, `jdb`, `phpdbg`, browser DevTools **as direct DAP
  adapters** (valid debuggers/clients, not DAP — need bridges).
- `mockdebug` (protocol test fixture), `java-test` (test
  launcher), `vscode-java-decompiler` (decompiler) as debugger
  entries.
- Installing both Delve native DAP (`dlv dap`) and the old VS Code
  Go proxy (Delve exposes DAP directly; don't double-install).

### Report corrections to wiki rows

- **Row 9 (Elixir)**: the report adds WhatsApp **EDB** — a modern
  debugger covering both Erlang and Elixir over executable/stdio
  DAP — alongside the real ElixirLS debugger. Plan: wire EDB for
  both languages, keep the ElixirLS option.
- **Row 15 (Haskell)**: the report validates phoityne's
  `haskell-debug-adapter` (listed by the DAP project and the
  Mason registry) — this supports *keeping* Diver's current
  `haskell.lua` target. Well-Typed's official `hdb` (GHC 9.14+)
  remains Matt's call (adopt / keep phoityne / wire both).
- **Row 19 (Lua)**: the report's actionable set lists
  `local-lua-debugger-vscode`, but Matt's standing choice is
  **Moonwalk** (native, integrated into the config). No change;
  Moonwalk remains the Lua debugger.
- **Rows 5/21 (C#), 23 (PHP), 29 (Ruby)**: the report confirms
  netcoredbg, Xdebug + vscode-php-debug, and rdbg respectively —
  the existing `csharp.lua`, `php.lua`, `ruby.lua` choices are
  correct; the wiki's packages stay denied.
- **Row 1 (Arduino/OpenOCD)**: the report confirms the
  GDB-concentrator route — OpenOCD needs no DAP in itself; MCU
  workflows go through the GDB DAP remote-target template
  (gdbserver / QEMU gdbstub / OpenOCD / `rr` / lldb-server).
- **Row 4 (cpptools)**: report lists OpenDebugAD7 as the bridge
  for GDB older than 14 — stays an optional exact-adapter
  addition.
- **Row 28 (BugStalker)**: not in the report's actionable set —
  stays optional.

### Report-sourced new candidates (not on the wiki list)

From the report's actionable executable set, not yet covered by
`lua/dap/`:

- `probe-rs` (`probe-rs dap-server`, TCP) — embedded
  ARM/RISC-V. Report priority (d).
- `cortex-debug` — Cortex-M through OpenOCD/J-Link/pyOCD/ST-Link.
  Report priority (d).
- `firefox-debug-adapter` — Firefox remote debugging protocol
  (web targets).
- Erlang: `edb` (WhatsApp) and/or `els_dap` — fold into the
  Elixir/EDB work above.
- Opt-in only (validate latest release + standalone entry point
  before adding): Julia `DebugAdapter.jl`, GraalVM `--dap`,
  RobotCode, `bzl` (Bazel/Starlark), Wing, Puppet Editor
  Services, ESP32 debug adapter.
- `local-lua-debugger-vscode` — superseded by Moonwalk for Matt;
  not adding.

`buildg` (wiki row 8, CONFIRM) is not contradicted by the report —
it simply isn't mentioned there; it stays a phase-2 candidate.

### Registry model adoption (design target)

New work follows the report's `DebugBackend` shape — debugger
backend + transport + protocol, not "every entry is a DAP
executable":

```lua
---@class DebugBackend
---@field id string
---@field languages string[]
---@field debugger string  -- gdb, lldb, Xdebug, JDWP runtime, ...
---@field adapter string|nil -- lldb-dap, vscode-js-debug, php-debug, ...
---@field transport 'stdio'|'tcp'|'pipe'|'unix'
---@field protocol 'dap'|'mi'|'jdwp'|'cdp'|'dbgp'|'rsp'
---@field dap_native boolean
---@field probe fun(): boolean
---@field build_config fun(ctx: table): table
```

Concretely: a new `lua/dap/backend.lua` holds the registry plus
the generic executable/stdio and server/TCP DAP transports
(report priority a), and `probe()` health checks must distinguish
Neovim-side / adapter-side / debugger-side / remote-target
failures. GDB becomes the protocol concentrator: one `gdb.lua`
DAP definition reused across C/C++/Rust/Zig/Fortran/Ada/D/asm,
plus a reusable GDB Remote target template (report priority d).
Language-specific adapters land only on filetype/toolchain
detection (report priority e).
