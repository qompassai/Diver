<!-- /qompassai/Diver/lua/dap/README.md -->
<!-- Qompass AI Diver DAP Docs -->
<!-- Copyright (C) 2026 Qompass AI, All rights reserved -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# DAP (Debug Adapter Protocol)

> ELI5: this folder teaches Neovim how to debug code — set breakpoints, step
> through lines, inspect variables — by talking the Debug Adapter Protocol to
> real debuggers for about forty languages and runtimes.

## How it works

- `init.lua` is the project-aware registry and loader (`require('dap').setup()`).
  Adapters run through Neovim's native `vim.debug` backend when it exists
  (Neovim 0.13+); diver does not depend on nvim-dap to register or operate adapters.
- A `MODULES` catalog in `init.lua` maps filetypes to module specs. Each spec may
  add a project `condition` and `root`, so project-specific modules (android,
  unity, unreal, sqlite) activate only inside the right project instead of
  claiming every buffer of that filetype.
- Each language module declares `M.adapter`/`M.adapters` (executable command or
  brokered server), `M.configurations` per filetype, plus `M.commands`,
  `M.mappings`, and `M.filetypes`. Applicable modules merge their configuration
  sets for a filetype rather than last-writer-wins.
- Adapter binaries are resolved at runtime — env-var overrides, well-known
  install paths, Mason bins, then `PATH` — and modules fail safely with a status
  message when the binary is missing instead of launching garbage.
- Status rule: **Active** = wired in the `MODULES` catalog; **Implemented** =
  module exists but is not yet wired to a filetype; **Foundation** = shared
  gdb/lldb descriptors reused by other modules; **Core** = registry, session,
  UI, and protocol machinery (not a debugger).

## Inventory (alphabetical)

| Name | Config | Binary | Filetypes | Status | Install | Upstream |
| ---- | ------ | ------ | --------- | ------ | ------- | -------- |
| _cmds | [_cmds](_cmds.lua) | — | — | Core | — |  |
| Android | [android](android.lua) | `lldb-dap` + `lldb-server` over `adb`; `jdb`/JDWP for JVM | java, kotlin, rust (project-gated) | Active | → upstream |  |
| Ansible | [ansible](ansible.lua) | `ansibug` (`python -m ansibug dap`) | ansible, yaml.ansible | Implemented | → upstream | https://github.com/xbglowx/ansibug |
| Apex / Visualforce | [apex](apex.lua) | node + Salesforce extension scripts (`apex`, `apex-replay`) | apex | Active | → upstream | https://github.com/forcedotcom/salesforcedx-vscode |
| async | [async](async.lua) | — | — | Core | — |  |
| backend | [backend](backend.lua) | — | — | Core | — |  |
| Bash | [bash](bash.lua) | `bash-debug-adapter` (node + bashdb) | bash, sh | Active | mason: `bash-debug-adapter` | https://github.com/rogalmic/vscode-bash-debug |
| breakpoints | [breakpoints](breakpoints.lua) | — | — | Core | — |  |
| C# / Razor | [csharp](csharp.lua) | `netcoredbg --interpreter=vscode` | cs, razor | Active | → upstream | https://github.com/Samsung/netcoredbg |
| COBOL | [cobol](cobol.lua) | `gdb -i=dap` (on `cobc -g` output) | cobol | Implemented | → upstream |  |
| Cortex-M | [cortex-debug](cortex-debug.lua) | GDB DAP via `dap.gdb`; server matrix: OpenOCD, J-Link, pyOCD, ST-Link | c, cpp, rust (firmware) | Implemented | → upstream | https://github.com/Marus/cortex-debug |
| dap | [dap](dap.lua) | — | — | Core | — |  |
| Dart / Flutter | [dart](dart.lua) | `dart debug_adapter` / `flutter debug_adapter` | dart | Implemented | ships with Dart/Flutter SDK | https://github.com/dart-code/dart-code |
| Elixir | [elixir](elixir.lua) | `elixir-ls-debugger` / `edb dap` | elixir | Implemented | → upstream | https://github.com/elixir-lsp/elixir-ls |
| entity | [entity](entity.lua) | — | — | Core | — |  |
| Erlang | [erlang](erlang.lua) | `edb dap` / `els_dap` | erlang | Implemented | → upstream | https://github.com/whatsapp/edb |
| Firefox | [firefox](firefox.lua) | `firefox-debug-adapter` | javascript, typescript (+react) | Implemented | `:MasonInstall firefox-debug-adapter` | https://github.com/firefox-devtools/vscode-firefox-debug |
| GDB | [gdb](gdb.lua) | `gdb -i=dap` | shared foundation | Foundation | → upstream (GDB toolchain) | https://github.com/bminor/binutils-gdb |
| Go | [go](go.lua) | `dlv dap` | go | Active | `go install github.com/go-delve/delve/cmd/dlv@latest` | https://github.com/go-delve/delve |
| Godot | [godot](godot.lua) | Godot editor DAP server (loopback port) | gdscript | Implemented | ships with Godot editor | https://github.com/godotengine/godot |
| Haskell | [haskell](haskell.lua) | `hdb` / `haskell-debug-adapter` | haskell | Implemented | → upstream | https://github.com/well-typed/haskell-debugger |
| init | [init](init.lua) | — | registry/loader | Core | — |  |
| Java | [java](java.lua) | JDTLS-brokered DAP server (127.0.0.1, ephemeral port) | java | Active | → upstream | https://github.com/microsoft/java-debug |
| Kotlin | [kotlin](kotlin.lua) | `kotlin-debug-adapter` | kotlin | Active | → upstream | https://github.com/fwcd/kotlin-debug-adapter |
| lifecycle | [lifecycle](lifecycle.lua) | — | — | Core | — |  |
| LLDB | [lldb](lldb.lua) | `lldb-dap` | shared foundation | Foundation | → upstream (LLVM toolchain) | https://github.com/llvm/llvm-project |
| lldb-dap | [lldb-dap](lldb-dap.lua) | `lldb-dap` | — | Foundation | → upstream (LLVM toolchain) |  |
| log | [log](log.lua) | — | — | Core | — |  |
| Lua | [lua](lua.lua) | `lua-debug` | lua | Active | → upstream | https://github.com/actboy168/lua-debug |
| Mojo | [mojo](mojo.lua) | `lldb-dap` (Mojo LLDB / CUDA-GDB) | mojo | Active | → upstream (Mojo toolchain) | https://github.com/llvm/llvm-project |
| Nix / Flakes | [nix](nix.lua) | `dawn` / `nix-debug-adapter` (DAWN) | nix | Active | → upstream | https://github.com/DieracDelta/DAWN |
| Node.js / TypeScript | [node](node.lua) | `dapDebugServer.js` (vscode-js-debug, `pwa-node`/`pwa-chrome`) | javascript, typescript (+react, glimmer) | Active | release tarball → upstream | https://github.com/microsoft/vscode-js-debug |
| OCaml | [ocaml](ocaml.lua) | `ocamlearlybird debug` | ocaml | Implemented | `opam install earlybird` | https://github.com/hackwaly/ocamlearlybird |
| Perl | [perl](perl.lua) | `perl-debug-adapter` | perl | Implemented | → upstream | https://github.com/Nihilus118/perl-debug-adapter |
| PHP | [php](php.lua) | `node phpDebug.js` (vscode-php-debug + Xdebug) | php | Implemented | mason: `php-debug-adapter` | https://github.com/xdebug/vscode-php-debug |
| PostgreSQL / PL/pgSQL | [postgres](postgres.lua) | `pgdap` (DAP→pldbgapi bridge) | sql, pgsql, postgresql | Active | → upstream | https://github.com/EnterpriseDB/pldebugger |
| PowerShell | [powershell](powershell.lua) | `pwsh` + PowerShell Editor Services | ps1, powershell | Active | → upstream | https://github.com/PowerShell/PowerShellEditorServices |
| probe-rs | [probe-rs](probe-rs.lua) | `probe-rs dap` | rust (embedded) | Implemented | → upstream | https://github.com/probe-rs/probe-rs |
| progress | [progress](progress.lua) | — | — | Core | — |  |
| protocol | [protocol](protocol.lua) | — | — | Core | — |  |
| Python | [python](python.lua) | `debugpy` (`python -m debugpy.adapter`) | python | Active | `pip install debugpy` | https://github.com/microsoft/debugpy |
| R | [r](r.lua) | R Debugger DAP server | r | Implemented | → upstream | https://github.com/ManuelHentschel/VSCode-R-Debugger |
| RenderDoc | [renderdoc](renderdoc.lua) | `renderdoccmd` (frame capture; not DAP) | glsl, hlsl | Active | → upstream | https://github.com/baldurk/renderdoc |
| repl | [repl](repl.lua) | — | — | Core | — |  |
| rpc | [rpc](rpc.lua) | — | — | Core | — |  |
| Ruby | [ruby](ruby.lua) | `rdbg --open --command` | ruby | Implemented | `gem install debug` | https://github.com/ruby/debug |
| Rust | [rust](rust.lua) | `lldb-dap` / `codelldb` | rust | Active | → upstream |  |
| Scala | [scala](scala.lua) | Metals `debug-adapter-start` | scala | Active | → upstream | https://github.com/scalameta/metals |
| session | [session](session.lua) | — | — | Core | — |  |
| SQL | [sql](sql.lua) | — (routes to postgres/sqlite backends) | sql | Active | — |  |
| SQLite | [sqlite](sqlite.lua) | `lldb-dap` / `gdb` fallback (+ EXPLAIN/VDBE inspection) | sql, sqlite, c, cpp | Active | → upstream | https://github.com/llvm/llvm-project |
| ui | [ui](ui.lua) | — | — | Core | — |  |
| Unity | [unity](unity.lua) | `netcoredbg --interpreter=vscode` | cs (project-gated) | Active | → upstream |  |
| Unreal Engine | [unreal](unreal.lua) | `lldb-dap` / `gdb` (+ Gameplay Debugger) | c, cpp (project-gated) | Active | → upstream |  |
| utils | [utils](utils.lua) | — | — | Core | — |  |
| Zig | [zig](zig.lua) | `lldb-dap` / `codelldb` | zig | Active | mason: `codelldb` |  |

Subdirectories (not files, so not in the table): `adapters/`, `ext/`,
`integrations/`, `registry/`, `store/`, `ui/` — supporting code for the
registry, persistence, and integrations such as Moonwalk.

## Install notes

Diver prefers standalone/native DAP implementations: native debugger DAP modes
(`gdb -i=dap`, `lldb-dap`) and runtime-provided adapters first; VS Code
extension assets only when no capability-equivalent standalone adapter exists.
- Toolchain debuggers (`lldb-dap`, `gdb`) ship with LLVM/GDB — no extra install.
- Language adapters usually install through the language's own package manager
  (`pip install debugpy`, `gem install debug`, `go install …/dlv@latest`,
  `opam install earlybird`).
- Where a module names a Mason package, `:MasonInstall <name>` also works
  (bash, firefox, ocaml, php, zig/codelldb).
- `→ upstream` means fetch the adapter from the linked project (releases,
  tarballs, or SDK bundles); never invent a package name.
- Dart/Flutter and Godot adapters ship inside their SDKs/editors — no separate install.

## Reference

- [Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/)
- [Neovim `vim.debug` documentation](https://neovim.io/doc/)
- [LLVM LLDB DAP](https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap)
- [GDB DAP interpreter](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html)
- [Adapter verdicts](ADAPTER_VERDICTS.md) — diver's per-adapter selection rationale
