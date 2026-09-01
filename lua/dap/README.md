<!-- /qompassai/Diver/lua/dap/README.md -->
<!-- Qompass AI Diver DAP Docs -->
<!-- Copyright (C) 2026 Qompass AI, All rights reserved -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

<div align="center">

# Qompass AI Diver Tiger-Style Debug Adapter Protocol (DAP) Docs

**Native-first debugging for Neovim 0.13+**

</div>

> [!NOTE]
> The config filename identifies the Diver Lua module. The expandable entry below it
> lists the actual debugger adapter, backend, or transport used for that language.
>
> Diver prefers standalone/native DAP implementations and direct `vim.debug` integration.
> VS Code extension assets are used only when the upstream debugger is actually delivered
> through that extension and there is no capability-equivalent standalone adapter.

## Current Diver DAP modules

The currently implemented DAP modules represented by this README are:

```text
android.lua
apex.lua
bash.lua
csharp.lua
go.lua
java.lua
kotlin.lua
lua.lua
mojo.lua
nix.lua
node.lua
postgres.lua
powershell.lua
python.lua
rust.lua
scala.lua
sql.lua
sqlite.lua
unreal.lua
```

`init.lua` is the project-aware native DAP registry/loader and is not itself a language adapter.

---

# Adapter index

<details>
  <summary><strong>Ada</strong> — <code>gdb.lua</code></summary>

- **Filetypes / runtime:** `ada`
- **Diver config:** [`gdb.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/gdb.lua)
- **Debug adapter stack:**
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — `gdb -i=dap` — primary.
</details>

<details>
  <summary><strong>Android</strong> — <code>android.lua</code></summary>

- **Filetypes / runtime:** `java`, `kotlin`, Rust/native C/C++ libraries, Android app processes.
- **Diver config:** [`android.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/android.lua)
- **Debug adapter stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — `lldb-dap` — native-code DAP.
  - [**lldb-server**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-server) — device-side native debug server.
  - [**Android Debug Bridge**](https://android.googlesource.com/platform/packages/modules/adb/) — `adb` — device/process transport.
  - [**JDWP**](https://docs.oracle.com/en/java/javase/25/docs/specs/jpda/jdwp-spec.html) / `jdb` — Java/Kotlin VM transport.
- **Activation policy:** project-gated by Android project markers rather than loaded for every Java/Kotlin/Rust buffer.
</details>

<details>
  <summary><strong>Ansible</strong> — <code>ansible.lua</code></summary>

- **Filetypes / runtime:** `ansible`, `yaml.ansible`
- **Diver config:** [`ansible.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/ansible.lua)
- **Debug adapter stack:**
  - [**ansibug**](https://github.com/jborean93/ansibug) — `python -m ansibug dap` — primary.
</details>

<details>
  <summary><strong>Apex / Visualforce</strong> — <code>apex.lua</code></summary>

- **Filetypes / runtime:** `apex`, `visualforce`
- **Diver config:** [`apex.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/apex.lua)
- **Debug adapter stack:**
  - [**Salesforce Apex Replay Debugger**](https://github.com/forcedotcom/salesforcedx-vscode) — Salesforce extension DAP — debug-log replay.
  - [**Salesforce Apex Interactive Debugger**](https://github.com/forcedotcom/salesforcedx-vscode) — Salesforce extension DAP — interactive org debugging.
</details>

<details>
  <summary><strong>Assembly</strong> — <code>lldb.lua</code></summary>

- **Filetypes / runtime:** `asm`
- **Diver config:** [`lldb.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua)
- **Debug adapter stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — alternative / GNU targets.
</details>

<details>
  <summary><strong>Bash</strong> — <code>bash.lua</code></summary>

- **Filetypes / runtime:** `bash`, `sh`; extensionless Bash/sh shebang scripts.
- **Diver config:** [`bash.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/bash.lua)
- **Debug adapter stack:**
  - [**vscode-bash-debug**](https://github.com/rogalmic/vscode-bash-debug) — Node DAP frontend.
  - [**bashdb**](https://github.com/rocky/bashdb) — debugger backend.
</details>

<details>
  <summary><strong>C</strong> — <code>lldb.lua</code></summary>

- **Filetypes / runtime:** `c`
- **Diver config:** [`lldb.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua)
- **Debug adapter stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — alternative.
</details>

<details>
  <summary><strong>C# / Razor</strong> — <code>csharp.lua</code></summary>

- **Filetypes / runtime:** `cs`, `razor`
- **Diver config:** [`csharp.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/csharp.lua)
- **Debug adapter stack:**
  - [**NetCoreDbg**](https://github.com/Samsung/netcoredbg) — `netcoredbg --interpreter=vscode` — .NET/CoreCLR DAP.
- **Scope:** ordinary .NET, ASP.NET Core, Razor, console applications, and services. Unity is intentionally kept separate.
</details>

<details>
  <summary><strong>C++</strong> — <code>lldb.lua</code></summary>

- **Filetypes / runtime:** `cpp` (`cc`, `cpp`, `cxx`, mapped C++ headers)
- **Diver config:** [`lldb.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua)
- **Debug adapter stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — alternative.
</details>

<details>
  <summary><strong>COBOL</strong> — <code>cobol.lua</code></summary>

- **Filetypes / runtime:** `cobol` (`cbl`, `cobol`, `cpy`, copybooks)
- **Diver config:** [`cobol.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/cobol.lua)
- **Debug adapter stack:**
  - [**Rech COBOL Debugger**](https://github.com/RechInformatica/rech-cobol-debugger) — general COBOL DAP bridge.
  - [**SuperBOL GnuCOBOL Debugger**](https://github.com/OCamlPro/superbol-vscode-debug) — GnuCOBOL + GDB adapter.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — native/debug-info fallback.
</details>

<details>
  <summary><strong>Crystal</strong> — <code>lldb.lua</code></summary>

- **Filetypes / runtime:** `crystal`
- **Diver config:** [`lldb.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua)
- **Debug adapter stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — alternative.
</details>

<details>
  <summary><strong>Cython</strong> — <code>python.lua</code></summary>

- **Filetypes / runtime:** `cython`
- **Diver config:** [`python.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/python.lua)
- **Debug adapter stack:**
  - [**debugpy**](https://github.com/microsoft/debugpy) — Python/runtime layer.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — generated/native extension layer.
</details>

<details>
  <summary><strong>Fortran</strong> — <code>gdb.lua</code></summary>

- **Filetypes / runtime:** `fortran`
- **Diver config:** [`gdb.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/gdb.lua)
- **Debug adapter stack:**
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — primary.
</details>

<details>
  <summary><strong>Go</strong> — <code>go.lua</code></summary>

- **Filetypes / runtime:** `go`
- **Diver config:** [`go.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/go.lua)
- **Debug adapter stack:**
  - [**Delve DAP**](https://github.com/go-delve/delve) — `dlv dap` — primary.
</details>

<details>
  <summary><strong>Haskell</strong> — <code>haskell.lua</code></summary>

- **Filetypes / runtime:** `haskell`
- **Diver config:** [`haskell.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/haskell.lua)
- **Debug adapter stack:**
  - [**haskell-debug-adapter**](https://github.com/phoityne/haskell-debug-adapter)
  - [**haskell-dap**](https://github.com/phoityne/haskell-dap)
  - [**ghci-dap**](https://github.com/phoityne/ghci-dap)
</details>

<details>
  <summary><strong>Java</strong> — <code>java.lua</code></summary>

- **Filetypes / runtime:** `java`
- **Diver config:** [`java.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/java.lua)
- **Debug adapter stack:**
  - [**Microsoft Java Debug Server**](https://github.com/microsoft/java-debug) — Eclipse JDT LS add-on implementing DAP.
  - [**Eclipse JDT LS**](https://github.com/eclipse-jdtls/eclipse.jdt.ls) — Java project model and debug-session broker.
  - **JDI/JDWP** — JVM launch/attach transport.
- **Native integration path:** `vim.lsp` asks JDTLS to execute `vscode.java.startDebugSession`; JDTLS returns an ephemeral DAP port consumed by `vim.debug`.
- **Features:** launch/attach, breakpoints, exception breakpoints, stepping, variables, call stacks, threads, classpath/module-path resolution, multi-project support, and remote JDWP attach.
</details>

<details>
  <summary><strong>JavaScript / TypeScript</strong> — <code>node.lua</code></summary>

- **Filetypes / runtime:** `javascript`, `javascriptreact`, `typescript`, `typescriptreact`, Glimmer variants.
- **Diver config:** [`node.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/node.lua)
- **Debug adapter stack:**
  - [**vscode-js-debug**](https://github.com/microsoft/vscode-js-debug) — standalone js-debug DAP server for Node.js and browser debugging.
</details>

<details>
  <summary><strong>Kotlin</strong> — <code>kotlin.lua</code></summary>

- **Filetypes / runtime:** `kotlin`
- **Diver config:** [`kotlin.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/kotlin.lua)
- **Debug adapter stack:**
  - [**kotlin-debug-adapter**](https://github.com/fwcd/kotlin-debug-adapter) — Kotlin/JVM DAP.
</details>

<details>
  <summary><strong>Lua</strong> — <code>lua.lua</code></summary>

- **Filetypes / runtime:** `lua`
- **Diver config:** [`lua.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/lua.lua)
- **Debug adapter stack:**
  - [**actboy168/lua-debug**](https://github.com/actboy168/lua-debug) — `lua-debug` — Lua/LuaJIT DAP.
</details>

<details>
  <summary><strong>Mojo</strong> — <code>mojo.lua</code></summary>

- **Filetypes / runtime:** `mojo`
- **Diver config:** [`mojo.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/mojo.lua)
- **Debug adapter stack:**
  - [**Mojo LLDB**](https://docs.modular.com/mojo/tools/debugging/) — `mojo-lldb` / `mojo debug` — CPU debugging.
  - [**Mojo CUDA-GDB**](https://docs.modular.com/mojo/cli/debug) — `mojo-cuda-gdb` / `mojo debug --cuda-gdb` — NVIDIA GPU debugging.
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — native-binary DAP path.
</details>

<details>
  <summary><strong>Nix / Nix Flakes</strong> — <code>nix.lua</code></summary>

- **Filetypes / runtime:** `nix`; `flake.nix`, `default.nix`, `shell.nix`, `configuration.nix`, `home.nix`.
- **Diver config:** [`nix.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/nix.lua)
- **Debug adapter stack:**
  - [**DAWN — Debug Adapter With Nix**](https://github.com/DieracDelta/DAWN) — Nix DAP adapter built around the Nix debugger.
  - [**Nix**](https://nix.dev/) — evaluation/build/flake inspection helpers.
- **DAP maturity:** DAWN is comparatively young, so Diver avoids undocumented configuration fields and supplements DAP with native `nix eval`, `nix flake check`, `nix flake show`, `nix build`, and `nix repl` workflows.
</details>

<details>
  <summary><strong>Objective-C / Objective-C++</strong> — <code>lldb.lua</code></summary>

- **Filetypes / runtime:** `objc`, `objcpp`
- **Diver config:** [`lldb.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua)
- **Debug adapter stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — alternative where applicable.
</details>

<details>
  <summary><strong>PHP</strong> — <code>php.lua</code></summary>

- **Filetypes / runtime:** `php`; Blade executes through PHP.
- **Diver config:** [`php.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/php.lua)
- **Debug adapter stack:**
  - [**vscode-php-debug**](https://github.com/xdebug/vscode-php-debug) — Node DAP bridge.
  - [**Xdebug**](https://github.com/xdebug/xdebug) — runtime DBGp debugger backend.
</details>

<details>
  <summary><strong>PostgreSQL / PL/pgSQL</strong> — <code>postgres.lua</code></summary>

- **Filetypes / runtime:** `pgsql`, `postgresql`; PL/pgSQL functions and procedures.
- **Diver config:** [`postgres.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/postgres.lua)
- **Debugger stack:**
  - [**pldebugger / pldbgapi**](https://github.com/EnterpriseDB/pldebugger) — PostgreSQL server-side debugger API.
  - **`pgdap` bridge contract** — standalone DAP-to-`pldbgapi` translation layer expected by Diver when available.
  - [**psql**](https://www.postgresql.org/docs/current/app-psql.html) — health, discovery, and debugger-proxy inspection.
- **Capabilities:** PL/pgSQL breakpoints, continue, step-over, step-into, stack retrieval, variables, variable mutation, direct debugging, and global/in-context debugging.
- **Security policy:** credentials remain in libpq mechanisms such as `PGSERVICE`, `.pg_service.conf`, `.pgpass`, Unix sockets, and TLS settings. Passwords are not embedded in Lua configuration.
</details>

<details>
  <summary><strong>PowerShell</strong> — <code>powershell.lua</code></summary>

- **Filetypes / runtime:** `ps1`, PowerShell modules and profile patterns.
- **Diver config:** [`powershell.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/powershell.lua)
- **Debug adapter stack:**
  - [**PowerShell Editor Services**](https://github.com/PowerShell/PowerShellEditorServices) — PSES Debugging Service — LSP + DAP.
</details>

<details>
  <summary><strong>Python</strong> — <code>python.lua</code></summary>

- **Filetypes / runtime:** `python`
- **Diver config:** [`python.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/python.lua)
- **Debug adapter stack:**
  - [**debugpy**](https://github.com/microsoft/debugpy) — `python -m debugpy.adapter` / debugpy server — primary.
</details>

<details>
  <summary><strong>Ruby</strong> — <code>ruby.lua</code></summary>

- **Filetypes / runtime:** `ruby`; ERB/Rails execute through Ruby.
- **Diver config:** [`ruby.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/ruby.lua)
- **Debug adapter stack:**
  - [**rdbg / debug.rb**](https://github.com/ruby/debug) — Ruby debugger and DAP endpoint.
  - [**vscode-rdbg**](https://github.com/ruby/vscode-rdbg) — reference frontend/integration.
</details>

<details>
  <summary><strong>Rust</strong> — <code>rust.lua</code></summary>

- **Filetypes / runtime:** `rust`
- **Diver config:** [`rust.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/rust.lua)
- **Debug adapter stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — alternative.
</details>

<details>
  <summary><strong>Scala</strong> — <code>scala.lua</code></summary>

- **Filetypes / runtime:** `scala`
- **Diver config:** [`scala.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/scala.lua)
- **Debug adapter stack:**
  - [**Metals DAP**](https://github.com/scalameta/metals) — `debug-adapter-start` — DAP endpoint/session broker.
  - [**Bloop debugger**](https://github.com/scalacenter/bloop) — JVM debugger used by Metals.
</details>

<details>
  <summary><strong>SQL — Generic Orchestration</strong> — <code>sql.lua</code></summary>

- **Filetypes / runtime:** `sql`
- **Diver config:** [`sql.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/sql.lua)
- **Role:** backend-neutral SQL debugging/inspection layer; intentionally **not** a fake universal SQL DAP adapter.
- **Backend routes:**
  - PostgreSQL → `postgres.lua` / PL/pgSQL DAP path.
  - SQLite → `sqlite.lua` query-plan/VDBE/native-debug path.
  - Generic SQL → execution and inspection helpers only.
- **Inspection features:** current-statement extraction, guarded execution, backend selection, `EXPLAIN`, profiling, and native database-shell access.
- **Statement parser:** aware of quoted strings, line comments, nested block comments, and PostgreSQL dollar-quoted bodies.
</details>

<details>
  <summary><strong>SQLite</strong> — <code>sqlite.lua</code></summary>

- **Filetypes / runtime:** `sql`, optional `sqlite`; SQLite databases and native applications embedding `libsqlite3`.
- **Diver config:** [`sqlite.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/sqlite.lua)
- **SQL inspection stack:**
  - [**EXPLAIN QUERY PLAN**](https://sqlite.org/eqp.html) — planner tree.
  - [**EXPLAIN**](https://sqlite.org/lang_explain.html) — VDBE bytecode.
  - `.eqp full` / `.eqp trace` — query-plan and virtual-machine tracing.
  - `SQLITE_ENABLE_STMT_SCANSTATUS` / `.scanstats` — profiling when compiled in.
- **Native DAP stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary native debugger for `sqlite3`, SQLite source, or an embedding application.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — alternative native debugger.
- **Important distinction:** SQLite has no stored-procedure source runtime. SQL query debugging is inspection/profiling; true DAP sessions debug SQLite or the embedding native application.
</details>

<details>
  <summary><strong>Unreal Engine</strong> — <code>unreal.lua</code></summary>

- **Filetypes / runtime:** project-gated `c`, `cpp` beneath an Unreal `.uproject`.
- **Diver config:** [`unreal.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/unreal.lua)
- **Native DAP stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary Linux native debugger.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — optional alternative.
- **Unreal runtime tooling:**
  - [**Gameplay Debugger**](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-the-gameplay-debugger-in-unreal-engine) — runtime AI, Behavior Tree, EQS, perception, and navigation inspection.
  - **Debug Camera** — complementary runtime inspection.
  - Unreal Build Tool / `Build.sh` — `DebugGame`, `Development`, and `Debug` workflows.
- **Activation policy:** activates only beneath an Unreal `.uproject`, so ordinary C/C++ projects do not inherit Unreal-specific configuration.
- **Important distinction:** Gameplay Debugger complements DAP. It is not itself a DAP implementation.
</details>

<details>
  <summary><strong>Zig</strong> — <code>zig.lua</code></summary>

- **Filetypes / runtime:** `zig`; `zon` project metadata.
- **Diver config:** [`zig.lua`](https://github.com/qompassai/Diver/blob/main/lua/dap/zig.lua)
- **Debug adapter stack:**
  - [**LLDB DAP**](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap) — primary.
  - [**GDB DAP**](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html) — alternative.
</details>

---

# Debug adapter families

The same adapter can serve several language-specific modules.

Diver keeps each language module responsible for:

- project-root detection;
- executable/build discovery;
- source mapping;
- runtime environment;
- pretty-printer/runtime integration;
- device or remote transport;
- launch and attach policy;
- adapter-specific debugging behavior.

The underlying DAP implementation is reused whenever practical.

<details>
  <summary><strong>LLDB DAP</strong></summary>

- **Executable:** `lldb-dap`
- **Source:** [llvm-project/lldb/tools/lldb-dap](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap)
- **Used or planned for:** Android native code, Assembly, C, C++, Crystal, Mojo native binaries, Objective-C, Rust, SQLite native debugging, Unreal Engine, and Zig.
</details>

<details>
  <summary><strong>GDB DAP</strong></summary>

- **Executable:** `gdb -i=dap`
- **Documentation:** [GDB DAP interpreter](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html)
- **Used or planned for:** Ada, Assembly, C, C++, COBOL native paths, Crystal, Cython native extensions, Fortran, Objective-C, Rust, SQLite native debugging, Unreal Engine, and Zig.
</details>

<details>
  <summary><strong>Runtime-specific DAPs</strong></summary>

- [ansibug](https://github.com/jborean93/ansibug) — Ansible
- [Salesforce Apex debugger extensions](https://github.com/forcedotcom/salesforcedx-vscode) — Apex
- [vscode-bash-debug](https://github.com/rogalmic/vscode-bash-debug) + [bashdb](https://github.com/rocky/bashdb) — Bash
- [NetCoreDbg](https://github.com/Samsung/netcoredbg) — C# / .NET
- [Delve DAP](https://github.com/go-delve/delve) — Go
- [haskell-debug-adapter](https://github.com/phoityne/haskell-debug-adapter) — Haskell
- [Microsoft Java Debug](https://github.com/microsoft/java-debug) + [Eclipse JDT LS](https://github.com/eclipse-jdtls/eclipse.jdt.ls) — Java
- [vscode-js-debug](https://github.com/microsoft/vscode-js-debug) — JavaScript / TypeScript
- [kotlin-debug-adapter](https://github.com/fwcd/kotlin-debug-adapter) — Kotlin
- [lua-debug](https://github.com/actboy168/lua-debug) — Lua
- [DAWN](https://github.com/DieracDelta/DAWN) — Nix
- [pldebugger / pldbgapi](https://github.com/EnterpriseDB/pldebugger) + `pgdap` bridge — PostgreSQL
- [vscode-php-debug](https://github.com/xdebug/vscode-php-debug) + [Xdebug](https://github.com/xdebug/xdebug) — PHP
- [PowerShell Editor Services](https://github.com/PowerShell/PowerShellEditorServices) — PowerShell
- [debugpy](https://github.com/microsoft/debugpy) — Python
- [rdbg/debug.rb](https://github.com/ruby/debug) — Ruby
- [Metals](https://github.com/scalameta/metals) + [Bloop](https://github.com/scalacenter/bloop) — Scala
</details>

---

# Project-aware loading

Diver's native `dap/init.lua` distinguishes **module definition loading** from
**project activation**.

```text
require module
    │
    └── once per Neovim process
          │
          ├── register adapters
          ├── register commands
          ├── register mappings
          └── merge configurations

activate module
    │
    └── once per module + project root
          │
          └── module.setup({
                bufnr = ...,
                root = ...,
                backend = vim.debug,
              })
```

This matters because several DAP modules share ordinary language filetypes.

```text
Java file
   │
   ├── ordinary project
   │      └── java.lua
   │
   └── Android project
          ├── java.lua
          └── android.lua


C++ file
   │
   ├── ordinary project
   │      └── native C/C++ debugger
   │
   └── Unreal project
          └── unreal.lua


SQL file
   │
   ├── generic
   │      └── sql.lua
   │
   ├── SQLite project
   │      ├── sql.lua
   │      └── sqlite.lua
   │
   └── PostgreSQL/PLpgSQL
          └── postgres.lua
```

Project-aware loading prevents a generic language buffer from inheriting runtime-specific
debugging behavior simply because the filetype happens to overlap.

---

# Configuration merging

Multiple applicable modules may contribute DAP configurations to the same filetype.

Diver merges configuration sets rather than allowing whichever module loads last to
replace the previous set.

For example:

```text
java.lua
    ├── Java: Main Class
    ├── Java: Current File
    └── Java: Attach JDWP

android.lua
    ├── Android: Launch
    └── Android: Attach

                │
                ▼

registry.configurations.java
    ├── Java: Main Class
    ├── Java: Current File
    ├── Java: Attach JDWP
    ├── Android: Launch
    └── Android: Attach
```

Configurations are deduplicated using their identifying DAP fields rather than blindly
appended.

---

# Native-first architecture

The intended Diver debugger stack is:

```text
                     Neovim 0.13+
                          │
                    native vim.debug
                          │
            ┌─────────────┼─────────────┐
            │             │             │
       executable       server      brokered DAP
          DAP             DAP             │
            │             │               │
            ▼             ▼               ▼
       lldb-dap       dlv/debugpy      JDTLS/Metals
       gdb DAP        js-debug             │
       NetCoreDbg                         DAP
            │                             │
            └──────────────┬──────────────┘
                           │
                           ▼
                       runtime
```

Neovim plugins are not required merely to register or operate adapters when native
`vim.debug` provides the necessary DAP functionality.

---

# Filetypes without a dedicated debugger

Configuration, markup, query, template, stylesheet, data, and documentation filetypes
should not receive a synthetic per-filetype DAP merely because Diver recognizes them.

When they participate in an executable application, debug the owning runtime instead.

Examples:

```text
Blade
  └── PHP / Xdebug

ERB / Rails templates
  └── Ruby / rdbg

Razor
  └── .NET / NetCoreDbg

Visualforce
  └── Apex debugger

JavaScript-backed templates
  └── Node / browser js-debug

generic SQL
  └── owning database/runtime
      └── sql.lua inspection when no source-level DAP exists

SQLite SQL
  ├── query-plan / VDBE inspection
  └── LLDB/GDB for SQLite or embedding application
```

---

# DAPs still to build

The following entries are documented in this README but are not yet part of the current
implemented module set.

They are alphabetized by module/language for easy tracking.

## Ansible — `ansible.lua`

- [ ] Implement Tiger-style `ansible.lua`
- **Target filetypes:** `ansible`, `yaml.ansible`
- **Primary debugger:** [ansibug](https://github.com/jborean93/ansibug)
- **DAP invocation:** `python -m ansibug dap`
- **Reference:** [github.com/jborean93/ansibug](https://github.com/jborean93/ansibug)

## COBOL — `cobol.lua`

- [ ] Implement Tiger-style `cobol.lua`
- **Target filetypes:** `cobol`
- **Primary candidates:**
  - [Rech COBOL Debugger](https://github.com/RechInformatica/rech-cobol-debugger)
  - [SuperBOL GnuCOBOL Debugger](https://github.com/OCamlPro/superbol-vscode-debug)
- **Native fallback:** [GDB DAP](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html)
- **Goal:** support GnuCOBOL/native debug-info paths without tying the module unnecessarily to a single editor extension.

## GDB — `gdb.lua`

- [ ] Implement reusable Tiger-style `gdb.lua`
- **Primary adapter:** [GDB native DAP interpreter](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html)
- **Executable:** `gdb -i=dap`
- **Primary consumers:**
  - Ada
  - Fortran
  - native fallback paths for other compiled languages
- **Goal:** centralize GDB executable discovery, launch/attach, process selection, remote targets, source mapping, architecture selection, and pretty-printer integration.

## Haskell — `haskell.lua`

- [ ] Implement Tiger-style `haskell.lua`
- **Target filetype:** `haskell`
- **Debugger stack:**
  - [haskell-debug-adapter](https://github.com/phoityne/haskell-debug-adapter)
  - [haskell-dap](https://github.com/phoityne/haskell-dap)
  - [ghci-dap](https://github.com/phoityne/ghci-dap)
- **Goal:** support Cabal/Stack project detection, GHCi debugging, executable/test target selection, and project-aware runtime discovery.

## LLDB — `lldb.lua`

- [ ] Implement reusable Tiger-style `lldb.lua`
- **Primary adapter:** [LLVM `lldb-dap`](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap)
- **Executable:** `lldb-dap`
- **Primary consumers:**
  - Assembly
  - C
  - C++
  - Crystal
  - Objective-C
  - Objective-C++
- **Secondary reuse:** Rust, Zig, SQLite native debugging, Unreal, Mojo, Android native code.
- **Goal:** centralize executable/process selection, source maps, shared-library search paths, remote debugging, target architecture, sanitizers, core dumps, and native pretty-printer support.

## PHP — `php.lua`

- [ ] Implement Tiger-style `php.lua`
- **Target filetype:** `php`
- **DAP bridge:** [vscode-php-debug](https://github.com/xdebug/vscode-php-debug)
- **Runtime debugger:** [Xdebug](https://github.com/xdebug/xdebug)
- **Goal:** CLI and web-request debugging, path mapping, Xdebug client-port management, project-root discovery, Docker/container mappings, and secure remote attach.
- **Template ownership:** Blade should delegate to PHP rather than receive a synthetic Blade DAP.

## Ruby — `ruby.lua`

- [ ] Implement Tiger-style `ruby.lua`
- **Target filetype:** `ruby`
- **Primary debugger:** [ruby/debug](https://github.com/ruby/debug)
- **Executable:** `rdbg`
- **Reference integration:** [vscode-rdbg](https://github.com/ruby/vscode-rdbg)
- **Goal:** script, Bundler, Rails, RSpec, process attach, remote/debug-port discovery, and project-aware Ruby/version-manager detection.
- **Template ownership:** ERB should delegate to Ruby.

## Zig — `zig.lua`

- [ ] Implement Tiger-style `zig.lua`
- **Target filetype:** `zig`
- **Project metadata:** `build.zig`, `build.zig.zon`, `.zon`
- **Primary debugger:** [LLDB DAP](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap)
- **Alternative debugger:** [GDB DAP](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html)
- **Goal:** Zig-version-aware toolchain discovery, `zig build` target discovery, debug/test/run artifacts, cross-target awareness, Zine projects, Ziggy/Ziggy Schema workflows where applicable, and precise binary discovery.

---

# Recommended TODO implementation order

Because several remaining languages can reuse generic native adapters, the most efficient
implementation order is:

```text
1. lldb.lua
   │
   ├── C
   ├── C++
   ├── Assembly
   ├── Crystal
   └── Objective-C
   │
   ▼
2. gdb.lua
   │
   ├── Ada
   ├── Fortran
   └── native fallback paths
   │
   ▼
3. zig.lua
4. ansible.lua
5. haskell.lua
6. php.lua
7. ruby.lua
8. cobol.lua
```

Implementing `lldb.lua` and `gdb.lua` first gives Diver two reusable native adapter
foundations instead of repeating debugger discovery and launch/attach logic across many
language modules.

---

# Current implementation matrix

| Language / Runtime | Module | Status | Primary debugger |
| --- | --- | --- | --- |
| Android | `android.lua` | ✅ Implemented | LLDB DAP + lldb-server + ADB + JDWP |
| Apex | `apex.lua` | ✅ Implemented | Salesforce Apex Debuggers |
| Bash | `bash.lua` | ✅ Implemented | vscode-bash-debug + bashdb |
| C# / Razor | `csharp.lua` | ✅ Implemented | NetCoreDbg |
| Go | `go.lua` | ✅ Implemented | Delve DAP |
| Java | `java.lua` | ✅ Implemented | Microsoft Java Debug + JDTLS |
| JavaScript / TypeScript | `node.lua` | ✅ Implemented | vscode-js-debug |
| Kotlin | `kotlin.lua` | ✅ Implemented | kotlin-debug-adapter |
| Lua | `lua.lua` | ✅ Implemented | lua-debug |
| Mojo | `mojo.lua` | ✅ Implemented | Mojo LLDB / CUDA-GDB / LLDB DAP |
| Nix / Flakes | `nix.lua` | ✅ Implemented | DAWN |
| PostgreSQL | `postgres.lua` | ✅ Neovim side implemented | pldbgapi + pgdap bridge contract |
| PowerShell | `powershell.lua` | ✅ Implemented | PowerShell Editor Services |
| Python | `python.lua` | ✅ Implemented | debugpy |
| Rust | `rust.lua` | ✅ Implemented | LLDB DAP / GDB DAP |
| Scala | `scala.lua` | ✅ Implemented | Metals + Bloop |
| SQL | `sql.lua` | ✅ Implemented | backend-neutral orchestration |
| SQLite | `sqlite.lua` | ✅ Implemented | EXPLAIN/VDBE + LLDB/GDB |
| Unreal Engine | `unreal.lua` | ✅ Implemented | LLDB/GDB + Gameplay Debugger |
| Ansible | `ansible.lua` | ⬜ TODO | ansibug |
| COBOL | `cobol.lua` | ⬜ TODO | Rech / SuperBOL / GDB |
| GDB generic | `gdb.lua` | ⬜ TODO | GDB DAP |
| Haskell | `haskell.lua` | ⬜ TODO | haskell-debug-adapter |
| LLDB generic | `lldb.lua` | ⬜ TODO | LLDB DAP |
| PHP | `php.lua` | ⬜ TODO | vscode-php-debug + Xdebug |
| Ruby | `ruby.lua` | ⬜ TODO | rdbg |
| Zig | `zig.lua` | ⬜ TODO | LLDB DAP / GDB DAP |

---

# Core native DAP commands

Diver's central `dap/init.lua` exposes runtime-independent commands such as:

```text
:DebugRun
:DebugRunLast
:DebugContinue
:DebugPause
:DebugRestart
:DebugStop
:DebugTerminate
:DebugDisconnect

:DebugBreakpoint
:DebugBreakpointCondition
:DebugBreakpointClear
:DebugLogpoint

:DebugStepBack
:DebugStepInto
:DebugStepOut
:DebugStepOver

:DebugHover
:DebugScopes
:DebugRepl

:DebugLoad
:DebugStatus
```

The central mappings are:

```text
<F5>   Run / Continue
<F6>   Pause
<F7>   Run last
<F8>   Toggle breakpoint
<F9>   Terminate
<F10>  Step over
<F11>  Step into
<F12>  Step out

<leader>dB  Conditional breakpoint
<leader>db  Toggle breakpoint
<leader>dc  Continue
<leader>dh  Hover
<leader>dl  Logpoint
<leader>dp  Pause
<leader>dr  Run
<leader>dR  Restart
<leader>ds  Scopes
<leader>dt  Terminate
```

Language-specific modules may register additional commands and mappings without requiring
the central loader to know every adapter-specific operation.

---

# Adapter design requirements

A Tiger-style Diver DAP module should generally provide:

```lua
---@class DebugModule
---@field adapter? table
---@field adapters? table<string, table>
---@field commands? table<string, DebugCommand>
---@field configurations? table<string, table[]>
---@field mappings? table<string, DebugMapping>
---@field setup? fun(opts?: table)
---@field teardown? fun()
```

The preferred module shape is:

```lua
local M = {}

M.adapter = {
  name = "example",

  type = "executable",

  command = "example-dap",
}

M.configurations = {
  example = {
    {
      name = "Example: Launch",

      type = "example",

      request = "launch",
    },
  },
}

M.commands = {}

M.mappings = {}

function M.setup(opts)
  opts = opts or {}
end

return M
```

Modules with multiple adapters may instead expose:

```lua
M.adapters = {
  ["example-lldb"] = {
    name = "example-lldb",

    type = "executable",

    command = "lldb-dap",
  },

  ["example-gdb"] = {
    name = "example-gdb",

    type = "executable",

    command = "gdb",

    args = {
      "-q",
      "-i=dap",
    },
  },
}
```

---

# Tiger-style principles

Tiger-style DAP modules should favor:

```text
native / standalone adapters
        over
editor plugin dependencies

project-aware discovery
        over
hard-coded paths

documented adapter fields
        over
invented compatibility settings

runtime/version detection
        over
single-version assumptions

secure credential handling
        over
secrets embedded in Lua

vim.system / vim.fs / vim.uv
        over
shell-string construction

module-specific tooling
        plus
shared central lifecycle
```

Debugging helpers should fail safely when an adapter is unavailable and should expose
status/discovery commands that make missing prerequisites obvious.

---

# Security requirements

Debugger adapters are privileged development tooling.

Tiger-style modules should therefore avoid:

```text
passwords embedded in Lua
tokens placed in DAP configuration tables
untrusted shell interpolation
world-accessible debugger listeners
JDWP bound publicly by default
remote adapters without authentication/tunneling
silently executing destructive database statements
```

Prefer:

```text
127.0.0.1
Unix sockets
SSH tunnels
libpq service files
environment variables for non-secret configuration
credential stores appropriate to the runtime
argument arrays passed directly to vim.system()
explicit confirmation before destructive/profiling execution
```

For remote JVM debugging, for example:

```text
127.0.0.1:5005
        │
        ▼
SSH tunnel
        │
        ▼
remote JVM
```

is preferable to exposing JDWP directly on a public interface.

---

# References

- [Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/)
- [Neovim documentation](https://neovim.io/doc/)
- [LLVM LLDB DAP](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap)
- [GDB DAP interpreter](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html)
- [Microsoft Java Debug](https://github.com/microsoft/java-debug)
- [Eclipse JDT LS](https://github.com/eclipse-jdtls/eclipse.jdt.ls)
- [DAWN](https://github.com/DieracDelta/DAWN)
- [EnterpriseDB pldebugger](https://github.com/EnterpriseDB/pldebugger)
- [SQLite EXPLAIN](https://sqlite.org/lang_explain.html)
- [SQLite EXPLAIN QUERY PLAN](https://sqlite.org/eqp.html)
- [SQLite debugging documentation](https://sqlite.org/debugging.html)
- [Unreal Engine Gameplay Debugger](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-the-gameplay-debugger-in-unreal-engine)
- [Delve](https://github.com/go-delve/delve)
- [debugpy](https://github.com/microsoft/debugpy)
- [vscode-js-debug](https://github.com/microsoft/vscode-js-debug)
- [NetCoreDbg](https://github.com/Samsung/netcoredbg)
- [PowerShell Editor Services](https://github.com/PowerShell/PowerShellEditorServices)
- [Metals](https://github.com/scalameta/metals)
- [Bloop](https://github.com/scalacenter/bloop)