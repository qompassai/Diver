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


  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/gleam_ls.lua">gleam_ls</a>
      </li>
       <p>
      <a href="https://github.com/gleam-lang/gleam">Gleam LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
mkdir -p "$XDG_DATA_HOME" "$XDG_BIN_HOME"
cd "$XDG_DATA_HOME"
git clone https://github.com/gleam-lang/gleam.git --branch "$THE_LATEST_VERSION"
cd gleam
export CARGO_HOME="${XDG_DATA_HOME}/cargo"
mkdir -p "$CARGO_HOME"
make install PREFIX="$HOME/.local"
```

</div>
    </ul>
  </blockquote>
</details>
   <details>
    <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/opengl/opengl.svg"
           alt="GLSL" width="60" height="60" title="GLSL" />
    </div>
    <strong>GLSL</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/glslana_ls.lua">glslana_ls</a>
      </li>
            <p>
      <a href="https://github.com/nolanderc/glsl_analyzer">GLSL Analyzer LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
mkdir -p "$XDG_DATA_HOME" "$XDG_BIN_HOME"
export ZVM_INSTALL="$XDG_DATA_HOME/zvm"
export PATH="$ZVM_INSTALL/bin:$PATH"
zvm upgrade
zvm install 0.14.0
cd "$XDG_DATA_HOME"
git clone https://github.com/nolanderc/glsl_analyzer.git --recursive
cd glsl_analyzer
zvm run 0.14.0 build install -Doptimize=ReleaseSafe --prefix "$HOME/.local"
```

</div>
    </ul>
  </blockquote>
</details>
<details>
     <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/go/go.svg"
           alt="go" width="60" height="60" title="Go" />
    </div>
    <strong>Go</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/golangcilint_ls.lua">golangcilint_ls</a>
      </li>
            <p>
      <a href="https://github.com/nametake/golangci-lint-langserver">Golang CI Lint LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && go install github.com/nametake/golangci-lint-langserver@latest
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/gop_ls.lua">gop_ls</a>
      </li>
       <p>
      <a href="https://github.com/golang/tools/tree/master/gopls">GoPls LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install golang.org/x/tools/gopls@latest
```

</div>
    </ul>
  </blockquote>
</details>
<details>
   <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/godot/godot.svg"
           alt="godot" width="60" height="60" title="Godot" />
    </div>
    <strong>Godot</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/gdscript_ls.lua">gdscript_ls</a>
      </li>
            <p>
      <a href=" https://github.com/godotengine/godot">Gdscript LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
mkdir -p "$XDG_DATA_HOME/godot" "$XDG_BIN_HOME"
cd "$XDG_DATA_HOME/godot"
curl -L "https://downloads.godotengine.org/?version=4.5.1&flavor=stable&slug=linux.x86_64.zip&platform=linux.64" \
  -o godot-4.5.1-linux.x86_64.zip
unzip godot-4.5.1-linux.x86_64.zip
rm godot-4.5.1-linux.x86_64.zip
chmod +x Godot_v4.5.1-stable_linux.x86_64
mv Godot_v4.5.1-stable_linux.x86_64 godot
cat > "$XDG_BIN_HOME/godot" <<'EOF'
#!/usr/bin/env bash
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
exec "$XDG_DATA_HOME/godot/godot" --single-window "$@"
EOF
chmod +x "$XDG_BIN_HOME/godot"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/godot.desktop" <<EOF
[Desktop Entry]
Name=Godot
Exec=$XDG_BIN_HOME/godot
Terminal=false
Type=Application
Icon=$XDG_DATA_HOME/godot/icon.png
Categories=Development;Game;
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/gdshader_ls.lua">gdshader_ls</a>
      </li>
        <p>
      <a href="https://github.com/GodOfAvacyn/gdshader-lsp">Gdscript LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/GodOfAvacyn/gdshader-lsp && luarocks --lua-version=5.1 install tree-sitter-gdshader
```

</div>
    </ul>
  </blockquote>
</details>
<details>
   <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/graphql/graphql.svg"
           alt="graphql" width="60" height="60" title="GraphQL" />
    </div>
    <strong>GraphQL</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/graphql_ls.lua">graphql_ls</a>
      </li>
        <p>
      <a href="https://github.com/graphql/graphiql/tree/main/packages/graphql-language-service-cli">Graphql LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g graphql-language-service-cli@latest graphql@latest
```

</div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/groovy/groovy.svg"
           alt="groovy" width="60" height="60" title="Groovy" />
    </div>
    <strong>Groovy</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/groovy_ls.lua">groovy_ls</a>
      </li>
          <p>
      <a href="https://github.com/prominic/groovy-language-server.git">Groovy LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/GroovyLanguageServer/groovy-language-server.git --recursive
cd groovy-language-server
./gradlew build
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
mkdir -p "$XDG_DATA_HOME/groovy-language-server" "$XDG_BIN_HOME"
cp build/libs/groovy-language-server-all.jar \
   "$XDG_DATA_HOME/groovy-language-server/groovy-language-server-all.jar"
```

</div>
    </ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/helm/helm.svg"
           alt="helm" width="60" height="60" title="Helm" />
    </div>
    <strong>Helm</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/helm_ls.lua">helm_ls</a>
      </li>
           <p>
      <a href="https://pkg.go.dev/github.com/mrjosh/helm-ls">Helm LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
OS=linux
ARCH=amd64
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
mkdir -p "$XDG_BIN_HOME"
curl -L "https://github.com/mrjosh/helm-ls/releases/download/master/helm_ls_${OS}_${ARCH}" \
  --output "${XDG_BIN_HOME}/helm_ls"
chmod +x "${XDG_BIN_HOME}/helm_ls"
```

</div>
    </ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/html/html.svg"
           alt="html width="60" height="60" title="HTML" />
    </div>
    <strong>HTML</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <ul>
    <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/html_ls.lua">html_ls</a>
     </li>
           <p>
      <a href="https://github.com/hrsh7th/vscode-langservers-extracted">HTML LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g vscode-langservers-extracted
```

</div>
  <li>
          <a href="https://github.com/qompassai/diver/blob/main/lsp/vshtml_ls.lua">vshtml_ls</a>
      </li>
                   <p>
      <a href="https://github.com/microsoft/vscode-html-languageservice">HTML Language Service LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add g vscode-html-languageservice
```

</div>
 <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/superhtml_ls.lua">superhtml_ls</a>
     </li>
           <p>
      <a href=" https://github.com/kristoff-it/superhtml">SuperHTML LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/kristoff-it/superhtml.git --recursive \
cd superhtml \
zig build -Doptimize=ReleaseSafe \
cp zig-out/bin/superhtml ~/.local/bin/
```

</div>
    </ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/herb/herb.svg"
           alt="herb" width="60" height="60" title="Herb" />
    </div>
    <strong>Html&EmbeddedRuby(Herb)</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/herb_ls.lua">herb_ls</a>
      </li>
        <p>
      <a href="https://github.com/urbit/hoon-language-server">Herb LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g @herb-tools/language-server@latest
```

</div>
</ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/hoon/hoon.svg"
           alt="herb" width="60" height="60" title="Hoon" />
    </div>
    <strong>Hoon</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/hoon_ls.lua">hoon_ls</a>
      </li>
      <p>
      <a href="https://github.com/urbit/hoon-language-server">Hoon LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g @urbit/hoon-language-server@latest
```

</div>
</ul>
  </blockquote>
</details>
    <details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/hydra/hydra.svg"
           alt="hydra" width="60" height="60" title="Hydra" />
    </div>
    <strong>Hydra</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/hydra_ls.lua">hydra_ls</a>
      </li>
    </ul>
               <p>
      <a href="https://github.com/Retsediv/hydra-lsp">Hydra LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pip install hydra-lsp
```

</div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/hyprland/hyprland.svg"
           alt="hyprland" width="60" height="60" title="Hyprland" />
    </div>
    <strong>Hyprland</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/hypr_ls.lua">hypr_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://en.gwen.works/hyprls/">Hypr LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/hyprland-community/hyprls/cmd/hyprls@latest
```

</div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/idris2/idris2.svg"
           alt="idris2" width="60" height="60" title="Idris2" />
    </div>
    <strong>Idris2</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/idris2_ls.lua">idris2_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://github.com/idris-community/idris2-lsp">Idris2 LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
set -euo pipefail
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export IDRIS2_PREFIX="${IDRIS2_PREFIX:-$XDG_DATA_HOME/idris2}"
REPO_DIR="${REPO_DIR:-$HOME/.GH/idris2-lsp-src}"
mkdir -p "$IDRIS2_PREFIX" "$REPO_DIR"
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone https://github.com/idris-community/idris2-lsp.git "$REPO_DIR"
else
  git -C "$REPO_DIR" pull --ff-only
fi
cd "$REPO_DIR"
git config protocol.https.allow always
git submodule update --init Idris2
cd Idris2
export SCHEME=chez
export IDRIS2_VERSION=0.8.0
make all \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"
make install \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"
make install-with-src-libs \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"
make install-with-src-api  \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"
cd "$REPO_DIR"
case ":$PATH:" in
  *":$IDRIS2_PREFIX/bin:"*) ;;
  *) export PATH="$IDRIS2_PREFIX/bin:$PATH" ;;
esac
git submodule update --init LSP-lib
cd LSP-lib
idris2 --install-with-src
cd "$REPO_DIR"
make install PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"
echo "idris2 & idris2-lsp installed to $IDRIS2_PREFIX/bin"
echo "Add this to your shell config (e.g. ~/.bashrc, ~/.zshrc):"
echo "    export XDG_DATA_HOME=\"\${XDG_DATA_HOME:-\$HOME/.local/share}\""
echo "    export IDRIS2_PREFIX=\"\${IDRIS2_PREFIX:-\$XDG_DATA_HOME/idris2}\""
echo "    export PATH=\"\$IDRIS2_PREFIX/bin:\$PATH\""
```

</div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/ink/ink.svg"
           alt="ink!" width="60" height="60" title="Ink!" />
    </div>
    <strong>Ink!</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/ink_ls.lua">ink_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://github.com/ink-analyzer/ink-analyzer/tree/master/crates/lsp-server
">Ink! LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/ink-analyzer/ink-analyzer.git
```

</div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/isabelle/isabelle.svg"
           alt="isabelle" width="60" height="60" title="Isabelle" />
    </div>
    <strong>Isabelle</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/isabelle_ls.lua">isabelle_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://github.com/ThreeFx/isabelle-lsp">Isabelle LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/ThreeFx/isabelle-lsp@latest
```

</div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/janet/janet.svg"
           alt="janet" width="60" height="60" title="Janet" />
    </div>
    <strong>Janet</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/janet_ls.lua">janet_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://github.com/CFiggers/janet-lsp">Janet LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
# Having janet and jpm already installed
git clone https://github.com/CFiggers/janet-lsp --recursive \
cd janet-lsp \
sudo jpm deps \
sudo jpm build \
sudo jpm install
```

</div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://skillicons.dev/icons?i=java" alt="java" width="60" height="60" title="Java" />
    </div>
    <strong>Java</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/java_ls.lua">java_ls</a>
      </li>
        <p>
      <a href="https://github.com/georgewfraser/java-language-server">Java LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
JLS_DIR="${XDG_DATA_HOME}/java-language-server"
BIN_DIR="${XDG_BIN_HOME}"
REPO_URL="https://github.com/georgewfraser/java-language-server.git"
mkdir -p "${JLS_DIR}" "${BIN_DIR}"
if [ ! -d "${JLS_DIR}/.git" ]; then
  git clone "${REPO_URL}" --recursive "${JLS_DIR}"
else
  cd "${JLS_DIR}"
  git pull --ff-only
fi
cd "${JLS_DIR}"
./scripts/download_linux.sh
./scripts/link_linux.sh
mvn package -DskipTests
WRAPPER="${BIN_DIR}/java-language-server"
cat > "${WRAPPER}" <<EOF
#!/usr/bin/env sh
exec "${JLS_DIR}/dist/lang_server_linux.sh" "\$@"
EOF
chmod +x "${WRAPPER}"
if [ -f "${HOME}/.bashrc" ]; then
  if ! grep -q 'XDG_BIN_HOME' "${HOME}/.bashrc"; then
    {
      printf '\n# Add XDG_BIN_HOME to PATH (java-language-server installer)\n'
      printf 'export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"\n'
      printf 'export PATH="$XDG_BIN_HOME:$PATH"\n'
    } >> "${HOME}/.bashrc"
    echo "Updated ~/.bashrc to include XDG_BIN_HOME on PATH."
  fi
fi
FISH_CONFIG_DIR="${HOME}/.config/fish"
mkdir -p "${FISH_CONFIG_DIR}"
FISH_CONFIG="${FISH_CONFIG_DIR}/config.fish"
if [ -f "${FISH_CONFIG}" ]; then
  if ! grep -q 'XDG_BIN_HOME' "${FISH_CONFIG}"; then
    {
      printf '\n# Add XDG_BIN_HOME to PATH (java-language-server installer)\n'
      printf 'set -q XDG_BIN_HOME; or set -Ux XDG_BIN_HOME $HOME/.local/bin\n'
      printf 'set -U fish_user_paths $XDG_BIN_HOME $fish_user_paths\n'
    } >> "${FISH_CONFIG}"
    echo "Updated ${FISH_CONFIG} to include XDG_BIN_HOME on PATH."
  fi
else
  {
    printf '# Add XDG_BIN_HOME to PATH (java-language-server installer)\n'
    printf 'set -q XDG_BIN_HOME; or set -Ux XDG_BIN_HOME $HOME/.local/bin\n'
    printf 'set -U fish_user_paths $XDG_BIN_HOME $fish_user_paths\n'
  } > "${FISH_CONFIG}"
fi
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/jdt_ls.lua">jdt_ls</a>
      </li>
             <p>
      <a href=" https://github.com/uros-5/jinja-lsp">JDT LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
JDTLS_DIR="${XDG_DATA_HOME}/jdtls"
BIN_DIR="${XDG_BIN_HOME}"
JDTLS_URL="http://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz"  # [1][web:48][web:51]
mkdir -p "${JDTLS_DIR}" "${BIN_DIR}"
TMP_TAR="$(mktemp /tmp/jdtls.XXXXXX.tar.gz)"
curl -sSfL "${JDTLS_URL}" -o "${TMP_TAR}"
rm -rf "${JDTLS_DIR:?}"/*
tar -xzf "${TMP_TAR}" -C "${JDTLS_DIR}"
rm -f "${TMP_TAR}"
LAUNCHER_JAR="$(printf '%s\n' "${JDTLS_DIR}"/plugins/org.eclipse.equinox.launcher_*.jar | head -n1)"
if [ ! -f "${LAUNCHER_JAR}" ]; then
  echo "Could not find Equinox launcher jar in ${JDTLS_DIR}/plugins" >&2
  exit 1
fi
JDTLS_DATA_DIR="${XDG_DATA_HOME}/jdtls-workspaces"
mkdir -p "${JDTLS_DATA_DIR}"
WRAPPER="${BIN_DIR}/jdtls"
cat > "${WRAPPER}" <<EOF
#!/usr/bin/env sh
XDG_DATA_HOME="\${XDG_DATA_HOME:-"\$HOME/.local/share"}"
JDTLS_DIR="${JDTLS_DIR}"
LAUNCHER_JAR="${LAUNCHER_JAR}"
JDTLS_DATA_DIR="\${JDTLS_DATA_DIR:-"${JDTLS_DATA_DIR}"}"
JAVA_BIN="\${JAVA_BIN:-java}"
exec "\$JAVA_BIN" \\
  -Declipse.application=org.eclipse.jdt.ls.core.id1 \\
  -Dosgi.bundles.defaultStartLevel=4 \\
  -Declipse.product=org.eclipse.jdt.ls.core.product \\
  -Dlog.protocol=true \\
  -Dlog.level=ALL \\
  -Xms1G \\
  -Xmx2G \\
  --add-modules=ALL-SYSTEM \\
  --add-opens java.base/java.util=ALL-UNNAMED \\
  --add-opens java.base/java.lang=ALL-UNNAMED \\
  -jar "\$LAUNCHER_JAR" \\
  -configuration "\$JDTLS_DIR/config_linux" \\
  -data "\$JDTLS_DATA_DIR/\${PWD##*/}"
EOF
chmod +x "${WRAPPER}"
if [ -f "${HOME}/.bashrc" ]; then
  if ! grep -q 'XDG_BIN_HOME' "${HOME}/.bashrc"; then
    {
      printf '\n# Add XDG_BIN_HOME to PATH (Eclipse JDT LS installer)\n'
      printf 'export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"\n'
      printf 'export PATH="$XDG_BIN_HOME:$PATH"\n'
    } >> "${HOME}/.bashrc"
  fi
fi
FISH_CONFIG_DIR="${HOME}/.config/fish"
mkdir -p "${FISH_CONFIG_DIR}"
FISH_CONFIG="${FISH_CONFIG_DIR}/config.fish"
if [ -f "${FISH_CONFIG}" ]; then
  if ! grep -q 'XDG_BIN_HOME' "${FISH_CONFIG}"; then
    {
      printf '\n# Add XDG_BIN_HOME to PATH (Eclipse JDT LS installer)\n'
      printf 'set -q XDG_BIN_HOME; or set -Ux XDG_BIN_HOME $HOME/.local/bin\n'
      printf 'set -U fish_user_paths $XDG_BIN_HOME $fish_user_paths\n'
    } >> "${FISH_CONFIG}"
  fi
else
  {
    printf '# Add XDG_BIN_HOME to PATH (Eclipse JDT LS installer)\n'
    printf 'set -q XDG_BIN_HOME; or set -Ux XDG_BIN_HOME $HOME/.local/bin\n'
    printf 'set -U fish_user_paths $XDG_BIN_HOME $fish_user_paths\n'
  } > "${FISH_CONFIG}"
fi
```

</div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://skillicons.dev/icons?i=js" alt="JavaScript" width="60" height="60" title="JavaScript" />
    </div>
    <strong>JavaScript</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/eslint_ls.lua">biome_ls</a>
      </li>
      <p>
      <a href="https://luals.github.io/">Biome LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -D -E @biomejs/biome@latest
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/eslint_ls.lua">eslint_ls</a>
      </li>
           <p>
      <a href="https://github.com/danielpza/eslint-lsp">Eslint LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -D -E eslint@latest
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/quicklint_js.lua">quicklint_js</a>
      </li>
        <p>
      <a href="https://quick-lint-js.com/">QuickLintJS LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -D -E quick-lint-js@latest
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/markojs_ls.lua">markojs_ls</a>
      </li>
    </ul>
          <p>
      <a href="https://github.com/marko-js/language-server">MarkoJS LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -D -E @marko/language-server@latest
```

</div>
     <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/olint_js.lua">oxlint_ls</a>
      </li>
        <p>
      <a href="https://www.npmjs.com/package/oxlint">Oxlint LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g oxlint@latest
```

</div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/jimmer/jimmer.svg"
           alt="jimmer" width="60" height="60" title="Jimmer" />
    </div>
    <strong>Jimmer DTO</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/jimmerdto_ls.lua">jimmerdto_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://github.com/Enaium/jimmer-dto-lsp">Jimmer DTO Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
mkdir -p $XDG_DATA_HOME/jimmer-dto-lsp && \
curl -L https://github.com/Enaium/jimmer-dto-lsp/releases/latest/download/server.jar \
  -o ~/.local/share/jimmer-dto-lsp/server.jar
```

</div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/jinja/jinja.svg"
           alt="jinja" width="60" height="60" title="Jinja" />
    </div>
    <strong>Jinja</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/jinja_ls.lua">jinja_ls</a>
      </li>
       <p>
      <a href=" https://github.com/uros-5/jinja-lsp">Jinja LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install jinja --git https://github.com/uros-5/jinja-lsp jinja-lsp
```

</div>
    </ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/jq/jq.svg"
           alt="jq" width="60" height="60" title="JQ" />
    </div>
    <strong>JQ</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/jq_ls.lua">jq_ls</a>
      </li>
        <p>
      <a href="https://github.com/wader/jq-lsp">JQ LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/wader/jq-lsp@latest
```

</div>
    </ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/json/json.svg"
           alt="json" width="60" height="60" title="JSON" />
    </div>
    <strong>JSON*</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/json_ls.lua">json_ls</a>
      </li>
                 <p>
      <a href="https://www.npmjs.com/package/vscode-json-languageserver">JSON LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g vscode-json-languageserver@latest
```

\#OR

```bash
npm i vscode-json-languageserver@latest
```

</div>
     <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/jsonld_ls.lua">jsonld_ls</a>
      </li>
           <p>
      <a href="https://github.com/digitalbazaar/jsonld.js">Jsonnet LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g jsonld@latest
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/jsonnet_ls.lua">jsonnet_ls</a>
      </li>
           <p>
      <a href="https://github.com/carlverge/jsonnet-lsp">Jsonnet LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/carlverge/jsonnet-lsp@latest
```

</div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/julia/julia.svg"
           alt="julia" width="60" height="60" title="Julia" />
    </div>
    <strong>Julia</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/julia_ls.lua">julia_ls</a>
      </li>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/just/just.svg"
           alt="just" width="60" height="60" title="Just" />
    </div>
    <strong>Just</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/just_ls.lua">just_ls</a>
      </li>
         <p>
      <a href="https://github.com/terror/just-lsp">Just LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/terror/just-lsp just-lsp
```

</div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/kotlin/kotlin.svg"
           alt="kotlin" width="60" height="60" title="Kotlin" />
    </div>
    <strong>Kotlin</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/kotlin_ls.lua">kotlin_ls</a>
      </li>
       <p>
      <a href=" https://github.com/fwcd/kotlin-language-server">Kotlin LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
git clone https://github.com/fwcd/kotlin-language-server.git --recursive
cd kotlin-language-server
./gradlew :server:installDist
KLS_DEST="$XDG_DATA_HOME/kotlin/kotlin-language-server"
mkdir -p "$KLS_DEST"
cp -a server/build/install/server/* "$KLS_DEST/"
```

</div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://skillicons.dev/icons?i=latex" alt="LaTeX" width="60" height="60" title="LaTeX" />
    </div>
    <strong>LaTeX</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
       <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/ltex_plus_ls.lua">ltex_plus_ls</a>
      </li>
      <p>
      <a href="https://github.com/ltex-plus/ltex-ls-plus">Ltex+ LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
LSP_DATA_DIR="${XDG_DATA_HOME}/lsp-ltex-plus"
BIN_DIR="${XDG_BIN_HOME}"
REPO="ltex-plus/ltex-ls-plus"
LATEST_TAG="$(curl -sSfL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -Eo '"tag_name":\s*"[^"]+"' \
  | sed -E 's/.*"([^"]+)".*/\1/')"
OS="linux"
ARCH="x64"
ARCHIVE_NAME="ltex-ls-plus-${LATEST_TAG}-${OS}-${ARCH}.tar.gz"
INSTALL_DIR="${LSP_DATA_DIR}/${LATEST_TAG}"
mkdir -p "${LSP_DATA_DIR}" "${BIN_DIR}"
curl -sSfL "https://github.com/${REPO}/releases/download/${LATEST_TAG}/${ARCHIVE_NAME}" \
  -o "/tmp/${ARCHIVE_NAME}"
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -xzf "/tmp/${ARCHIVE_NAME}" -C "${INSTALL_DIR}"
if [ -x "${INSTALL_DIR}/bin/ltex-ls-plus" ]; then
  TARGET="${INSTALL_DIR}/bin/ltex-ls-plus"
elif [ -x "${INSTALL_DIR}/ltex-ls-plus" ]; then
  TARGET="${INSTALL_DIR}/ltex-ls-plus"
else
  echo "Could not find ltex-ls-plus binary in ${INSTALL_DIR}" >&2
  exit 1
fi
WRAPPER="${BIN_DIR}/ltex-ls-plus"
cat > "${WRAPPER}" <<EOF
#!/usr/bin/env sh
exec "${TARGET}" "\$@"
EOF
chmod +x "${WRAPPER}"
if [ -f "${HOME}/.bashrc" ]; then
  if ! grep -q 'XDG_BIN_HOME' "${HOME}/.bashrc"; then
    {
      printf '\n# Add XDG_BIN_HOME to PATH (Qompass lsp-ltex-plus installer)\n'
      printf 'export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"\n'
      printf 'export PATH="$XDG_BIN_HOME:$PATH"\n'
    } >> "${HOME}/.bashrc"
  fi
fi
FISH_CONFIG_DIR="${HOME}/.config/fish"
mkdir -p "${FISH_CONFIG_DIR}"
FISH_CONFIG="${FISH_CONFIG_DIR}/config.fish"

if [ -f "${FISH_CONFIG}" ]; then
  if ! grep -q 'XDG_BIN_HOME' "${FISH_CONFIG}"; then
    {
      printf '\n# Add XDG_BIN_HOME to PATH (Qompass lsp-ltex-plus installer)\n'
      printf 'set -q XDG_BIN_HOME; or set -Ux XDG_BIN_HOME $HOME/.local/bin\n'
      printf 'set -U fish_user_paths $XDG_BIN_HOME $fish_user_paths\n'
    } >> "${FISH_CONFIG}"
  fi
else
  {
    printf '# Add XDG_BIN_HOME to PATH (Qompass lsp-ltex-plus installer)\n'
    printf 'set -q XDG_BIN_HOME; or set -Ux XDG_BIN_HOME $HOME/.local/bin\n'
    printf 'set -U fish_user_paths $XDG_BIN_HOME $fish_user_paths\n'
  } > "${FISH_CONFIG}"
fi

echo "ltex-ls-plus installed. Restart your shell to pick up PATH changes."
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/texlab_ls.lua">texlab_ls</a>
      </li>
            <p>
      <a href="https://github.com/latex-lsp/texlab">Texlab LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
XDG_BIN_HOME="${XDG_BIN_HOME:-"$HOME/.local/bin"}"
TEXLAB_DATA_DIR="${XDG_DATA_HOME}/lsp-texlab"
BIN_DIR="${XDG_BIN_HOME}"
REPO="latex-lsp/texlab"
LATEST_TAG="$(curl -sSfL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -Eo '"tag_name":\s*"[^"]+"' \
  | sed -E 's/.*"([^"]+)".*/\1/')"
OS="linux"
ARCH="x86_64"
ARCHIVE_NAME="texlab-${OS}-${ARCH}.tar.gz"
INSTALL_DIR="${TEXLAB_DATA_DIR}/${LATEST_TAG}"
echo "Installing texlab ${LATEST_TAG} to ${INSTALL_DIR}"
mkdir -p "${TEXLAB_DATA_DIR}" "${BIN_DIR}"
curl -sSfL "https://github.com/${REPO}/releases/download/${LATEST_TAG}/${ARCHIVE_NAME}" \
  -o "/tmp/${ARCHIVE_NAME}"
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -xzf "/tmp/${ARCHIVE_NAME}" -C "${INSTALL_DIR}"
if [ ! -x "${INSTALL_DIR}/texlab" ]; then
  echo "Could not find texlab binary in ${INSTALL_DIR}" >&2
  exit 1
fi
WRAPPER="${BIN_DIR}/texlab"
cat > "${WRAPPER}" <<EOF
#!/usr/bin/env sh
exec "${INSTALL_DIR}/texlab" "\$@"
EOF
chmod +x "${WRAPPER}"
if [ -f "${HOME}/.bashrc" ]; then
  if ! grep -q 'XDG_BIN_HOME' "${HOME}/.bashrc"; then
    {
      printf '\n# Add XDG_BIN_HOME to PATH (Texlab installer)\n'
      printf 'export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"\n'
      printf 'export PATH="$XDG_BIN_HOME:$PATH"\n'
    } >> "${HOME}/.bashrc"
  fi
fi
FISH_CONFIG_DIR="${HOME}/.config/fish}"
mkdir -p "${FISH_CONFIG_DIR}"
FISH_CONFIG="${FISH_CONFIG_DIR}/config.fish"
if [ -f "${FISH_CONFIG}" ]; then
  if ! grep -q 'XDG_BIN_HOME' "${FISH_CONFIG}"; then
    {
      printf '\n# Add XDG_BIN_HOME to PATH (Texlab installer)\n'
      printf 'set -q XDG_BIN_HOME; or set -Ux XDG_BIN_HOME $HOME/.local/bin\n'
      printf 'set -U fish_user_paths $XDG_BIN_HOME $fish_user_paths\n'
    } >> "${FISH_CONFIG}"
  fi
else
  {
    printf '# Add XDG_BIN_HOME to PATH (Texlab installer)\n'
    printf 'set -q XDG_BIN_HOME; or set -Ux XDG_BIN_HOME $HOME/.local/bin\n'
    printf 'set -U fish_user_paths $XDG_BIN_HOME $fish_user_paths\n'
  } > "${FISH_CONFIG}"
fi
echo "texlab installed. Restart your shell to pick up PATH changes."
```

</div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/llvm/llvm.svg"
           alt="llvm" width="60" height="60" title="llvm" />
    </div>
    <strong>LLVM</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/mlir_ls.lua">mlir_ls</a>
      </li>
      <p>
      <a href="https://mlir.llvm.org/docs/Tools/MLIRLSP/#mlir-lsp-language-server--mlir-lsp-server=
">MLIR LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/llvm/llvm-project.git --recursive \
cd llvm-project
mkdir build && cd build
cmake -G Ninja ../llvm \
  -DLLVM_ENABLE_PROJECTS="mlir" \
  -DCMAKE_BUILD_TYPE=Release \
 -DCMAKE_INSTALL_PREFIX=$HOME/.local \
ninja mlir-lsp-server mlir-pdll-lsp-server \
ninja install
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/mlirpdll_ls.lua">mlirpdll_ls</a>
      </li>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/tblgen_ls.lua">tblgen_ls</a>
      </li>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/logic/logic.svg"
           alt="logic" width="60" height="60" title="Logic" />
    </div>
    <strong>Logic</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/dolmen_ls.lua">dolmen_ls</a>
      </li>
      <p>
      <a href="https://github.com/Gbury/dolmen/blob/master/doc/lsp.md">Dolmen LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
opam pin add https://github.com/Gbury/dolmen.git
```

</div>
  </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/lua/lua.svg"
           alt="lua" width="60" height="60" title="lua" />
    </div>
    <strong>Lua</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/lua_ls.lua">Lua_ls</a>
            <p>
      <a href="https://luals.github.io/">Lua LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
luarocks --lua-version=5.1 install lua-language-server
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/emmylua_ls.lua">emmylua_ls</a>
      </li>
             <p>
      <a href="https://github.com/EmmyLuaLs/emmylua-analyzer-rust">Emmylua_ls LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
 cargo install --git https://github.com/EmmyLuaLs/emmylua-analyzer-rust schema_json_gen emmylua_ls emmylua_check emmylua_code_style emmylua_doc_cli
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/stylua_ls.lua">stylua_ls</a>
      </li>
    </ul>
              <p>
      <a href="https://github.com/JohnnyMorganz/StyLua">Stylua LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/JohnnyMorganz/StyLua stylua --features luajit
```

</div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/luau/luau.svg"
           alt="lua" width="60" height="60" title="lua" />
    </div>
    <strong>Luau</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/lua_ls.lua">Luau_ls</a>
      </li>
            <p>
      <a href="https://luals.github.io/">luau_ls LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/JohnnyMorganz/luau-lsp.git --recurse-submodules \
cd luau-lsp && mkdir -p build && cd build \
cmake -S .. -B . \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_CXX_FLAGS="-Wno-deprecated-literal-operator" \
-DCMAKE_INSTALL_PREFIX="$HOME/.local" && ninja \
cp luau-lsp ~/.local/bin
```

</div>
</blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/lwc/lwc.svg"
           alt="lwc" width="60" height="60" title="LWC" />
    </div>
    <strong>LWC</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/lwc_ls.lua">lwc_ls</a>
      </li>
       <p>
      <a href="https://github.com/forcedotcom/lightning-language-server/">LWC LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g @salesforce/lwc-language-server@latest
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/make/make.svg"
           alt="make" width="60" height="60" title="Make" />
    </div>
    <strong>Make</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
          <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/autotoo_ls.lua">autotoo_ls</a>
      </li>
         <p>
      <a href="https://autotools-language-server.readthedocs.io/en/latest/">AutoTools LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
 pip install autotools-language-server
```

## OR

```bash
uv tool install autotools-language-server
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/markdown/markdown.svg"
           alt="lua" width="60" height="60" title="Markdown" />
    </div>
    <strong>Markdown</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
        <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/moxide_ls.lua">moxide_ls</a>
      </li>
          <p>
      <a href="https://github.com/Feel-ix-343/markdown-oxide">Moxide LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/Feel-ix-343/markdown-oxide
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/marksman_ls.lua">marksman_ls</a>
      </li>
          <p>
      <a href="https://github.com/artempyanykh/marksman">Marksman LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/artempyanykh/marksman.git --recursive && cd marksman
git fetch --all && git submodule update --init --recursive \
make install PREFIX="$HOME/.local"
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/mdxana_ls.lua">mdxana_ls</a>
      </li>
        <p>
      <a href="https://github.com/mdx-js/mdx-analyzer">Mdx Analyzer LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g @mdx-js/typescript-plugin@latest
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/remark_ls.lua">remark_ls</a>
      </li>
          <p>
      <a href="https://github.com/remarkjs/remark-language-server">Remark LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g remark-language-server@latest

```

   </div>
      <p>
      <a href="https://github.com/rvben/rumdl">Rumdl LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/rvben/rumdl
```

   </div>
         </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/matlab/matlab.svg"
           alt="matlab" width="60" height="60" title="Matlab" />
    </div>
    <strong>Matlab</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/matlab_ls.lua">matlab_ls</a>
      </li>
              <p>
      <a href="https://github.com/mathworks/MATLAB-language-server">Matlab LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/mathworks/MATLAB-language-server.git && \
cd MATLAB-language-server && \
npm install && \
cd src/licensing/gui && npm install && cd ../../.. && \
npm run compile && \
mkdir -p ~/.local/share/matlab-language-server && \
cp -r out/* ~/.local/share/matlab-language-server/ && \
mkdir -p ~/.local/bin && \
cat > ~/.local/bin/matlab-language-server << 'EOF'
#!/bin/bash
exec node ~/.local/share/matlab-language-server/index.js "$@"
EOF
chmod +x ~/.local/bin/matlab-language-server && \
echo "MATLAB Language Server installed to ~/.local/bin/matlab-language-server"
```

   </div>
      <p>
      <a href="https://github.com/rvben/rumdl">Rumdl LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/rvben/rumdl
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/mojo/mojo.svg"
           alt="mojo" width="60" height="60" title="Mojo" />
    </div>
    <strong>Mojo</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/mojo_ls.lua">mojo_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://github.com/modular/modular">Mojo Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
set -euo pipefail
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
install_pixi() {
  if command -v pixi >/dev/null 2>&1; then
    echo "pixi already installed at: $(command -v pixi)"
    return
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    echo "Error: cargo not found in PATH. Please install Rust/cargo first." >&2
    exit 1
  fi
  cargo install pixi
}
configure_pixi() {
  local pixi_config_dir="$XDG_CONFIG_HOME/pixi"
  local pixi_config_file="$pixi_config_dir/config.toml"

  mkdir -p "$pixi_config_dir"

  if [ ! -f "$pixi_config_file" ]; then
    cat > "$pixi_config_file" <<'EOF'
# Reference: https://prefix-dev.github.io/pixi/
default-channels = ["conda-forge"]
change-ps1 = true
tls-no-verify = false

[pypi-config]
index-url = "https://pypi.org/simple"
extra-index-urls = []
keyring-provider = "subprocess"
EOF
    echo "Created pixi config: $pixi_config_file"
  else
    echo "pixi config already exists: $pixi_config_file"
  fi
  local pixi_manifest_dir="$XDG_CONFIG_HOME/pixi/manifests"
  mkdir -p "$pixi_manifest_dir"
}
link_mojo_tools() {
  local mojo_env_dir="$XDG_DATA_HOME/mojo/.pixi/envs/default"
  local mojo_bin_dir="$mojo_env_dir/bin"
  local user_bin_dir="$HOME/.local/bin"
  mkdir -p "$user_bin_dir"
  if [ ! -x "$mojo_bin_dir/mojo-lsp-server" ]; then
    echo "Warning: $mojo_bin_dir/mojo-lsp-server not found or not executable." >&2
  else
    ln -sf "$mojo_bin_dir/mojo-lsp-server" "$user_bin_dir/mojo-lsp-server"
    echo "Linked mojo-lsp-server -> $user_bin_dir/mojo-lsp-server"
  fi
  if [ ! -x "$mojo_bin_dir/mojo-lldb-dap" ]; then
    echo "Warning: $mojo_bin_dir/mojo-lldb-dap not found or not executable." >&2
  else
    ln -sf "$mojo_bin_dir/mojo-lldb-dap" "$user_bin_dir/mojo-lldb-dap"
    echo "Linked mojo-lldb-dap -> $user_bin_dir/mojo-lldb-dap"
  fi
}
main() {
  install_pixi
  configure_pixi
  link_mojo_tools
}

main "$@"
```

</div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/muon/muon.svg"
           alt="muon" width="60" height="60" title="Muon" />
    </div>
    <strong>Muon</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/muon_ls.lua">muon_ls</a>
      </li>
             <p>
      <a href="https://muon.build">Muon Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/muon-build/muon.git && cd muon && ./bootstrap.sh build \
&& build/muon-bootstrap setup build && build/muon-bootstrap -C build samu \
&& build/muon-bootstrap -C build test && sudo build/muon-bootstrap -C build install
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/nginx/nginx.svg"
           alt="nginx" width="60" height="60" title="Nginx" />
    </div>
    <strong>Nginx</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/nginx_ls.lua">nginx_ls</a>
      </li>
             <p>
      <a href="https://github.com/pappasam/nginx-language-server">Nginx LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
 pip install -U nginx-language-server
```

   </div>
        </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/nickel/nickel.svg"
           alt="nickel" width="60" height="60" title="Nickel" />
    </div>
    <strong>Nickel</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/nickel_ls.lua">nickel_ls</a>
      </li>
        <p>
      <a href="https://github.com/tweag/nickel">Nickel LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/tweag/nickel nickel-language-server
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/nix/nix.svg"
           alt="nix" width="60" height="60" title="Nix" />
    </div>
    <strong>Nix</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/nil_ls.lua">nil_ls</a>
      </li>
             <p>
      <a href="https://github.com/oxalica/nil">Nil LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/oxalica/nil nil
```

\#OR

```bash
nix profile install nixpkgs#nil
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/nixd_ls.lua">nixd_ls</a>
      </li>
        <p>
      <a href="https://github.com/nix-community/nixd">Nixd LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
nix profile install github:nix-community/nixd
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/statix_ls.lua">statix_ls</a>
      </li>
    </ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/nobl9/nobl9.svg"
           alt="racket" width="60" height="60" title="Racket" />
    </div>
    <strong>Nobl9</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/nobl9_ls.lua">nobl9_ls</a>
      </li>
    </ul>
        <p>
      <a href="https://github.com/nobl9/nobl9-language-server">Nobl9 LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/nobl9/nobl9-language-server/cmd/nobl9-language-server@latest
```

   </div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/ocaml/ocaml.svg"
           alt="ocaml" width="60" height="60" title="Ocaml" />
    </div>
    <strong>Ocaml</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/ocaml_ls.lua">ocaml_ls</a>
      </li>
    </ul>
  </blockquote>
</details>
  <details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/odin/odin.svg"
           alt="odin" width="60" height="60" title="Odin" />
    </div>
    <strong>Odin</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/o_ls.lua">o_ls</a>
      </li>
        <p>
      <a href="https://github.com/DanielGavin/ols">Odin LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/DanielGavin/ols.git --recursive \
cd ols && git fetch --all && git checkout dev-2025-11 \
./build.sh && ./odinfmt.sh \
mv ols ~/.local/bin \
mv odinfmt ~/.local/bin
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/openfoam/openfoam.svg"
           alt="openfoam" width="60" height="60" title="OpenFOAM" />
    </div>
    <strong>OpenFOAM</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/foam_ls.lua">foam_ls</a>
      </li>
                         <p>
      <a href="https://github.com/FoamScience/foam-language-server">Foam LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g foam-language-server@latest
```

   </div>
</ul>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/opa/opa.svg"
           alt="openpolicyagent" width="60" height="60" title="OpenPolicyAgent" />
    </div>
    <strong>OpenPolicyAgent</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/regal_ls.lua">regal_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://github.com/StyraInc/regal">OPA Regal LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
curl -L -o ~/.local/bin/regal \
  "https://github.com/open-policy-agent/regal/releases/latest/download/regal_Linux_x86_64"

chmod +x ~/.local/bin/regal
```

</div>
 <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/rego_ls.lua">rego_ls</a>
      </li>
         </ul>
        <p>
      <a href="https://github.com/kitagry/regols">OPA Rego LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/kitagry/regols@latest
```

</div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/openscad/openscad.svg"
           alt="openscad" width="60" height="60" title="OpenSCAD" />
    </div>
    <strong>OpenSCAD</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/openscad_ls.lua">openscad_ls</a>
      </li>
    </ul>
     <p>
      <a href="https://github.com/Leathong/openscad-LSP">OpenSCAD LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/Leathong/openscad-LSP
```

</div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/perl/perl.svg"
           alt="perl" width="60" height="60" title="Perl" />
    </div>
    <strong>Perl</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/perl_ls.lua">perl_ls</a>
      </li>
       <p>
      <a href="https://github.com/richterger/Perl-LanguageServer/tree/master/clients/vscode/perl"> Perl LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cpanm Perl::LanguageServer
```

# OR

```bash
cpan Perl::LanguageServer
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/perlp_ls.lua">perlp_ls</a>
      </li>
       <p>
      <a href="https://github.com/FractalBoy/perl-language-server "> PerlP LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cpan PLS
```

# OR

```bash
cpanm PLS
```

</div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/perlnav_ls.lua">perlnav_ls</a>
      </li>
            <p>
      <a href="https://github.com/bscan/PerlNavigator/tree/main"> Perl Navigator Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
mkdir -p "$HOME/.local/bin"
cd "$(mktemp -d)"
curl -L -o perlnavigator.zip \
  "https://github.com/bscan/PerlNavigator/releases/latest/download/perlnavigator-linux-x86_64.zip"
unzip perlnavigator.zip
cd perlnavigator-linux-x86_64
chmod +x perlnavigator
mv perlnavigator "$HOME/.local/bin/"
```

</div>
         </ul>
  </blockquote>
</details>
 <details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/php/php.svg"
           alt="php" width="60" height="60" title="PHP" />
    </div>
    <strong>PHP</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/intelephense_ls.lua">intelephense_ls</a>
      </li>
       <p>
      <a href="https://intelephense.com/docs">Intelephense LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g intelephense@latest
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/phpactor_ls.lua">phpactor_ls</a>
      </li>
         <p>
      <a href="https://phpactor.readthedocs.io/en/master/reference/configuration.html">PHPActor LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
PHP_BIN="${PHP_BIN:-php}"
INSTALL_DIR="${HOME}/.local/bin"
PHAR_URL="https://github.com/phpactor/phpactor/releases/latest/download/phpactor.phar"
TMP_PHAR="$(mktemp)"
if ! command -v "$PHP_BIN" >/dev/null 2>&1; then
  echo "php not found in PATH" >&2
  exit 1
fi
mkdir -p "${INSTALL_DIR}"
curl -fL "${PHAR_URL}" -o "${TMP_PHAR}"
chmod +x "${TMP_PHAR}"
mv "${TMP_PHAR}" "${INSTALL_DIR}/phpactor"
phpactor status || {
  echo "phpactor status failed; ensure ${INSTALL_DIR} is in PATH and PHP deps are OK." >&2
}
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/laravel_ls.lua">laravel_ls</a>
      </li>
       <p>
      <a href=" https://github.com/laravel-ls/laravel-ls">Laravel LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/laravel-ls/laravel-ls/cmd/laravel-ls@latest
```

```
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/psalm_ls.lua">psalm_ls</a>
      </li>
       <p>
      <a href="https://github.com/vimeo/psalm">Psalm LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
composer global require vimeo/psalm
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/phan_ls.lua">phan_ls</a>
      </li>
         <p>
      <a href="https://github.com/phan/phan">Phan LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
composer require phan/phan
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/plantuml/plantuml.svg"
           alt="plantuml" width="60" height="60" title="PlantUML" />
    </div>
    <strong>PlantUML</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/plantuml_ls.lua">plantuml_ls</a>
      </li>
    </ul>
     <p>
      <a href="https://github.com/ptdewey/plantuml-lsp">PlantUML LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/ptdewey/plantuml-lsp@latest
```

</div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/postgresql/postgresql.svg"
           alt="postgresql" width="60" height="60" title="Postgresql" />
    </div>
    <strong>Postgresql</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/postgres_ls.lua">postgres_ls</a>
           </li>
             <p>
              <a href="https://github.com/phan/phan">PostGres LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
mkdir -p ~/.local/bin && cd ~/.local/bin
curl -L \
  https://github.com/supabase-community/postgres-language-server/releases/latest/download/postgres-language-server_x86_64-unknown-linux-gnu --recursive \
  -o postgres-language-server
chmod +x postgres-language-server
```

 </div>
<li>
<a href="https://github.com/qompassai/diver/blob/main/lsp/postgrestoo_ls.lua">postgrestoo_ls</a>
</li>
 <p>
      <a href="https://pg-language-server.com/latest/">PostgresTools LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
export REPO="supabase-community/postgres-language-server"
export INSTALL_DIR="$HOME/.local/bin"
export NAME="postgres-language-server"
arch=$(uname -m)
case "$arch" in
  x86_64|amd64)   arch="x86_64" ;;
  aarch64|arm64)  arch="aarch64" ;;
  *) echo "Unsupported arch: $arch" >&2; exit 1 ;;
esac
os=$(uname -s)
case "$os" in
  Linux)  os="unknown-linux-gnu" ;;
  *) echo "This script is for Linux only."; exit 1 ;;
esac
bin="${NAME}_${arch}-${os}"
url="https://github.com/$REPO/releases/latest/download/$bin"
mkdir -p "$INSTALL_DIR"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
if command -v curl >/dev/null 2>&1; then
  curl -L "$url" -o "$tmp"
else
  wget -O "$tmp" "$url"
fi
mv "$tmp" "$INSTALL_DIR/$NAME"
chmod +x "$INSTALL_DIR/$NAME"
echo "Installed to $INSTALL_DIR/$NAME"
echo "Ensure $INSTALL_DIR is in your PATH, then run:"
echo "  $NAME --help"

```

  </div>
</ul>
</blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/powershell/powershell.svg"
           alt="powershell" width="60" height="60" title="Powershell" />
    </div>
    <strong>Powershell</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/pwrshelles_ls.lua">pwershelles_ls</a>
      </li>
        <p>
      <a href="https://github.com/PowerShell/PowerShellEditorServices">Powershell LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
mkdir -p ~/.local/share/powershell-editor-services && \
cd ~/.local/share/powershell-editor-services && \
curl -s https://api.github.com/repos/PowerShell/PowerShellEditorServices/releases/latest | \
grep "browser_download_url.*PowerShellEditorServices.zip" | \
cut -d '"' -f 4 | \
xargs curl -L -o pses.zip && \
unzip -q pses.zip && \
rm pses.zip
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/prisma/prisma.svg"
           alt="prisma" width="60" height="60" title="Prisma" />
    </div>
    <strong>Prisma</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/prisma_ls.lua">prisma_ls</a>
      </li>
           <p>
      <a href="https://www.npmjs.com/package/@prisma/language-server">Prisma LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g @prisma/language-server@latest
```

   </div>
    </ul>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/protobuf/protobuf.svg"
           alt="protobuf" width="60" height="60" title="Protobuf" />
    </div>
    <strong>Protobuf</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/proto_ls.lua">proto_ls</a>
      </li>
        <p>
      <a href="https://buf.build/docs/">Protobuf LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
cargo install --git https://github.com/coder3101/protols
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/buf_ls.lua">buf_ls</a>
      </li>
    </ul>
           <p>
      <a href="https://buf.build/docs/">Buf LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
go install github.com/bufbuild/buf/cmd/buf@latest
```

   </div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/puppet/puppet.svg"
           alt="puppet" width="60" height="60" title="Puppet" />
    </div>
    <strong>Puppet</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/puppet_ls.lua">puppet_ls</a>
      </li>
    </ul>
        <p>
      <a href="https://github.com/puppetlabs/puppet-editor-services">Puppet LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
export GEM_HOME="$HOME/.gem"
export GEM_PATH="$GEM_HOME"
export PATH="$HOME/.local/bin:$GEM_HOME/bin:$PATH"
git clone https://github.com/puppetlabs/puppet-editor-services.git && cd puppet-editor-services && bundle install  \
bundle exec rake gem_revendor
```

   </div>
  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/python/python.svg"
           alt="python" width="60" height="60" title="Python" />
    </div>
    <strong>Python</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/basedpy_ls.lua">basepy_ls</a>
      </li>
      <p>
      <a href="https://posit-dev.github.io/air/integration-github-actions.html">BasedPyright LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pip install basedpyright
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/pyrefly_ls.lua">pyrefly_ls</a>
      </li>
             <p>
      <a href="https://pyrefly.org/">Pyrefly LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pip install pyrefly
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/ruff_ls.lua">ruff_ls</a>
      </li>
             <p>
      <a href="https://docs.astral.sh/ruff/">Ruff LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
curl -LsSf https://astral.sh/ruff/install.sh | sh
```

   </div>
         <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/ty_ls.lua">ty_ls</a>
      </li>
    </ul>
       <p>
      <a href="https://posit-dev.github.io/air/integration-github-actions.html">Ty LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
uv tool install ty
```

# OR

```bash
pip install ty
```

   </div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/redhat/redhat.svg"
           alt="redhat" width="60" height="60" title="redhat" />
    </div>
    <strong>Redhat Package Manager (RPM)</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/rpmspec_ls.lua">rpmspec_ls</a>
      </li>
    </ul>
        <p>
      <a href="https://github.com/dcermak/rpm-spec-language-server">RPMSPec LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pip install rpm-spec-language-server
```

   </div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/ruby/ruby.svg"
           alt="ruby" width="60" height="60" title="Ruby" />
    </div>
    <strong>Ruby</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/rubocop_ls.lua">rubocop_ls</a>
      </li>
                    <p>
      <a href="https://docs.rubocop.org/rubocop/1.81/index.html">Rubocop LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
gem install rubocop
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/ruby_ls.lua">ruby_ls</a>
      </li>
                    <p>
      <a href="https://shopify.github.io/ruby-lsp/">Ruby LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
gem install ruby-lsp
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/sorbet_ls.lua">sorbet_ls</a>
      </li>
                    <p>
      <a href="https://sorbet.org/docs/lsp">Sorbet LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
gem install sorbet sorbet-runtime
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/steep_ls.lua">steep_ls</a>
      </li>
                    <p>
      <a href="https://github.com/soutaro/steep?tab=readme-ov-file">Steep LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
gem install steep
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/standardrb_ls.lua">standardrb_ls</a>
      </li>
                    <p>
      <a href="https://github.com/standardrb/standard">StandardRB LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
gem install standard
```

   </div>
       <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/stimulus_ls.lua">stimulus_ls</a>
      </li>
                    <p>
      <a href="https://github.com/marcoroth/stimulus-lsp">Stimulus LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
pnpm add -g stimulus-language-server@latest
```

   </div>
     <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/stree_ls.lua">stree_ls</a>
      </li>
                    <p>
      <a href="https://ruby-syntax-tree.github.io/syntax_tree/">SyntaxTree LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
gem install syntax_tree
```

   </div>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/typeprof_ls.lua">typeprof_ls</a>
      </li>
    </ul>
                  <p>
      <a href="https://github.com/ruby/typeprof">TypeProf LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
gem install typeprof
```

   </div>
  </blockquote>
</details>

<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/scala/scala.svg"
           alt="scala" width="60" height="60" title="Scala" />
    </div>
    <strong>Scala</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/metals_ls.lua">metals_ls</a>
      </li>
    </ul>
         <p>
      <a href="https://scalameta.org/metals/docs/editors/user-configuration">Metals LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash

```

</div>
  </blockquote>
</details>
<details>
 <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/bash/bash.svg"
           alt="shell" width="60" height="60" title="Shell" />
    </div>
    <strong>Shell</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/bash_ls.lua">bash_ls</a>
      </li>
                  <p>
      <a href="https://github.com/bash-lsp/bash-language-server">Bash LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
```

  </blockquote>
</details>
<details>
  <summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/zig/zig.svg"
           alt="zig" width="60" height="60" title="Zig" />
    </div>
    <strong>Zig</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/ziggy_ls.lua">ziggy_ls</a>
       <p>
      <a href="https://ziggy-lang.io/documentation/ziggy-lsp/">Ziggy LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/kristoff-it/ziggy.git && cd ziggy && zig build -Doptimize=ReleaseSafe install
```

</div>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/ziggy_schema_ls.lua">ziggy_schema_ls</a>
       <p>
      <a href="https://ziggy-lang.io/documentation/ziggy-lsp/">Ziggy LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/kristoff-it/ziggy.git && cd ziggy && zig build -Doptimize=ReleaseSafe installation
```

</div>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/z_ls.lua">z_ls</a>
    </ul>
       <p>
      <a href="https://zigtools.org/zls/install">Zig LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
git clone https://github.com/zigtools/zls && cd zls && zig build -Doptimize=ReleaseSafe
```

</div>
  </blockquote>
</details>