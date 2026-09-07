Qompass AI Diver — Native Debug Adapter Protocol

Tiger-style, native-first debugging for Neovim 0.13+

Diver integrates Debug Adapter Protocol implementations directly through Neovim's native "vim.debug" facilities.

The filename identifies the Diver integration module rather than necessarily identifying the underlying debugger. Multiple languages may share a reusable debugger such as LLDB DAP or GDB DAP.

Diver prefers:

1. Standalone DAP servers.
2. Native debugger DAP modes.
3. Runtime-provided debug adapters.
4. LSP-brokered DAP sessions where appropriate.
5. Editor-extension assets only when no capability-equivalent standalone adapter exists.

"init.lua" is the project-aware DAP registry and loader and is not itself a debugger module.

---

Status legend

Symbol| Meaning
✅| Implemented
🚧| Planned / should be implemented next
🔗| Covered by another Diver DAP module
🧪| Specialized or experimental
⬜| Optional future implementation
❌| No dedicated DAP should be created

---

Current Diver modules

Runtime / Language| Module| Status| Primary debugger
Android| "android.lua"| ✅| LLDB + lldb-server + ADB + JDWP
Apex / Visualforce| "apex.lua"| ✅| Salesforce Apex debugger
Bash / shell| "bash.lua"| ✅| bash-debug + bashdb
C# / .NET / Razor| "csharp.lua"| ✅| NetCoreDbg
Go| "go.lua"| ✅| Delve DAP
Java| "java.lua"| ✅| Microsoft Java Debug + JDTLS
JavaScript / TypeScript| "node.lua"| ✅| vscode-js-debug
Kotlin| "kotlin.lua"| ✅| kotlin-debug-adapter
Lua / LuaJIT| "lua.lua"| ✅| lua-debug
Mojo| "mojo.lua"| ✅| Mojo LLDB / CUDA-GDB
Nix / Flakes| "nix.lua"| ✅| DAWN + native Nix inspection
PostgreSQL / PL/pgSQL| "postgres.lua"| ✅| pldebugger / pgdap bridge
PowerShell| "powershell.lua"| ✅| PowerShell Editor Services
Python| "python.lua"| ✅| debugpy
Rust| "rust.lua"| ✅| LLDB / GDB
Scala| "scala.lua"| ✅| Metals + Bloop
SQL orchestration| "sql.lua"| ✅| Runtime/backend routing
SQLite| "sqlite.lua"| ✅| VDBE + LLDB/GDB
Unreal Engine| "unreal.lua"| ✅| LLDB/GDB + Unreal inspection

Implemented language/runtime modules: 19

---

Current planned modules

These are already represented conceptually in Diver and should remain the immediate implementation queue.

Priority| Runtime / Foundation| Module| Target debugger
1| Generic LLDB| "lldb.lua"| "lldb-dap"
2| Generic GDB| "gdb.lua"| "gdb -i=dap"
3| Zig| "zig.lua"| LLDB DAP / GDB DAP
4| Ansible| "ansible.lua"| ansibug
5| Haskell| "haskell.lua"| Haskell Debug Adapter
6| PHP| "php.lua"| Xdebug DAP bridge
7| Ruby| "ruby.lua"| rdbg
8| COBOL| "cobol.lua"| Rech / SuperBOL / GDB

Why LLDB and GDB come first

"lldb.lua" and "gdb.lua" should be foundations rather than ordinary language modules.

Once implemented, they can service:

lldb.lua
├── Assembly
├── C
├── C++
├── Crystal
├── Objective-C
├── Objective-C++
├── Rust
├── Zig
├── Mojo
├── Unreal
├── Android native code
└── SQLite/native database processes

and:

gdb.lua
├── Ada
├── Assembly
├── C
├── C++
├── COBOL
├── Crystal
├── Fortran
├── Objective-C
├── Rust
├── Zig
├── Cython native extensions
├── embedded targets
└── remote targets

This avoids reimplementing executable selection, process attachment, source mapping, remote debugging, core dumps, pretty-printers, architecture handling, and shared-library configuration in every language module.

---

Next expansion from the official DAP registry

After the existing eight-module TODO queue, these are the strongest additions.

Dart / Flutter — "dart.lua"

Priority: High

Status: 🚧 Recommended

Debugger:

- Dart Debug Adapter
- Dart SDK DAP server
- Flutter debugging through the Dart tooling stack

Target filetypes:

dart

Projects:

pubspec.yaml
.dart_tool/

Recommended capabilities:

- Dart application launch
- Dart test debugging
- Flutter application launch
- Flutter device selection
- VM Service attachment
- process/device discovery
- package-root detection
- "flutter" versus "dart" runtime selection

One module should handle both Dart and Flutter rather than introducing a separate "flutter.lua" unless their orchestration eventually diverges significantly.

---

Elixir — "elixir.lua"

Priority: High

Status: 🚧 Recommended

Debugger:

- ElixirLS Debug Adapter

Target filetypes:

elixir
eelixir
heex

Project markers:

mix.exs
mix.lock

Features:

- Mix project launch
- test debugging
- Phoenix application debugging
- distributed-node attachment
- environment selection
- umbrella-project support

Templates such as HEEx should delegate to the Elixir runtime.

---

Erlang — "erlang.lua"

Priority: High

Status: 🚧 Recommended

Debugger candidates:

- Erlang EDB
- Erlang LS debugger

Target filetypes:

erlang

Project markers:

rebar.config
rebar.lock
erlang.mk

Features:

- application launch
- test debugging
- distributed Erlang attachment
- node/cookie handling
- rebar3 integration

Do not merge this into "elixir.lua": both run on BEAM, but their projects, build systems, tooling and debugging workflows differ enough to justify separate modules.

---

Godot / GDScript — "godot.lua"

Priority: High

Status: 🚧 Recommended

Debugger:

- Godot native DAP server

Target filetypes:

gdscript
gdshader

Project marker:

project.godot

Features:

- editor/runtime discovery
- project launch
- scene launch
- running-editor attachment
- breakpoint support
- project-aware port discovery
- Godot 4 detection

This is a particularly good fit for Diver because Godot exposes an actual DAP server rather than requiring a synthetic editor-specific debugging layer.

---

OCaml — "ocaml.lua"

Priority: Medium-high

Status: 🚧 Recommended

Debugger:

- Earlybird

Target filetypes:

ocaml
ocamlinterface

Project markers:

dune-project
dune
opam
*.opam

Features:

- Dune integration
- executable/test selection
- opam switch awareness
- bytecode/native target handling
- source mapping

---

R — "r.lua"

Priority: Medium-high

Status: 🚧 Recommended

Debugger:

- R Debugger DAP implementation

Target filetypes:

r
rmd
quarto

Features:

- R script launch
- testthat
- package debugging
- working-directory selection
- R executable discovery
- environment inspection

R Markdown and Quarto should delegate debugging to R/Python rather than having independent DAPs.

---

Perl — "perl.lua"

Priority: Medium

Status: 🚧 Recommended

Debugger candidates:

- Perl Debug
- Perl::LanguageServer debugging support

Target filetype:

perl

Features:

- script launch
- argument handling
- local-lib support
- process attachment where supported
- Perlbrew/plenv discovery

---

Unity — "unity.lua"

Priority: Medium-high

Status: 🚧 Recommended

Debugger:

- Unity debug adapter / managed debugger

Target filetype:

cs

Activation must be project gated:

Assets/
ProjectSettings/
Packages/manifest.json

Normal C# projects must continue to route through "csharp.lua".

Architecture:

C# file
 │
 ├── ordinary .NET project
 │      └── csharp.lua
 │
 └── Unity project
        └── unity.lua

---

Embedded debugging

Embedded targets deserve dedicated project-aware modules rather than being stuffed into the ordinary desktop "rust.lua" or "lldb.lua".

Embedded Rust — "probe.lua"

Status: 🚧 Recommended

Debugger:

- probe-rs DAP

Target languages:

rust

Project gating could include:

Embed.toml
.cargo/config.toml
memory.x
defmt.x

Features:

- probe discovery
- chip selection
- flashing
- reset/halt
- RTT
- defmt
- semihosting
- core selection
- target configuration

"rust.lua" should remain responsible for ordinary host Rust debugging.

---

ESP32 — "esp32.lua"

Status: 🚧 Recommended

Debugger:

- Espressif DAP server

Potential targets:

c
cpp
rust

Project gating:

sdkconfig
CMakeLists.txt
idf_component.yml

Features:

- ESP-IDF discovery
- OpenOCD/debug-server startup
- serial device discovery
- chip architecture detection
- firmware image discovery
- flashing
- remote GDB/DAP transport

---

Additional language DAPs

These are legitimate implementations in the DAP ecosystem but are lower priority for Diver.

Runtime| Proposed module| Status
Ballerina| "ballerina.lua"| ⬜
Haxe| "haxe.lua"| ⬜
Luau| "luau.lua"| ⬜
Puppet| "puppet.lua"| ⬜
SWI-Prolog| "prolog.lua"| ⬜
Squirrel| "squirrel.lua"| ⬜
Wolfram Language| "wolfram.lua"| ⬜
TLA+| "tla.lua"| ⬜
OpenQASM| "qasm.lua"| ⬜
OneScript| "onescript.lua"| ⬜
Harbour| "harbour.lua"| ⬜
Papyrus| "papyrus.lua"| ⬜
VDM-SL / VDM++ / VDM-RT| "vdm.lua"| ⬜
ZIL| "zil.lua"| ⬜

These should be implemented when the language itself becomes part of Diver's normal editing/toolchain support rather than simply attempting to mirror every entry in the public DAP registry.

---

Specialized debugger targets

These are real DAP implementations but generally should not result in a new language module.

Chromium / Chrome

Status: 🔗 Covered

Route through:

node.lua
└── vscode-js-debug

The modern JavaScript debugger already handles browser targets.

No "chrome.lua" is necessary.

---

Microsoft Edge

Status: 🔗 Covered

Route through:

node.lua
└── vscode-js-debug

No dedicated "edge.lua".

---

Electron

Status: 🔗 Primarily covered

Route through:

node.lua
└── vscode-js-debug

Electron-specific project detection may eventually be added to "node.lua".

---

Cordova

Status: 🔗 Runtime-owned

Prefer project-aware JavaScript/Android/iOS routing rather than a generic "cordova.lua" unless Cordova-specific adapter behavior cannot be represented cleanly by the runtime modules.

---

React Native

Status: 🔗 Runtime-owned

Prefer:

node.lua
android.lua

depending on the debug target.

A dedicated React Native module should only be added if substantial runtime orchestration is required.

---

Firefox

Status: 🧪 Potential separate integration

Firefox has separate debugger implementations and cannot always be treated exactly like Chromium.

A future:

firefox.lua

could be justified if Diver needs first-class Firefox remote debugging.

This is lower priority than language/runtime coverage.

---

Retro / specialist architecture adapters

The public DAP ecosystem also contains adapters for specialized targets.

Z80 — "z80.lua"

Status: ⬜ Optional

Debugger:

- DeZog

Useful only if Diver intends to support Z80 development and emulation workflows.

---

Emulicious — "emulicious.lua"

Status: ⬜ Optional

Relevant to retro-console and embedded development.

---

Krom — "krom.lua"

Status: ⬜ Optional

Primarily useful to Kha/Krom workflows.

---

Flash / SWF

Status: ⬜ Optional / legacy

Implement only if Diver intentionally supports ActionScript/Flash development.

---

Duktape — "duktape.lua"

Status: ⬜ Optional

Potentially useful for embedded JavaScript projects.

This should not replace ordinary JavaScript debugging in "node.lua".

---

Things that should not receive synthetic DAPs

Not every recognized Neovim filetype needs its own debugger.

Markup and styling

html
css
scss
sass
less
xml
markdown
rst

Debug the application/runtime that consumes them.

---

Templates

Blade
  └── php.lua

ERB
  └── ruby.lua

HEEx
  └── elixir.lua

Razor
  └── csharp.lua

Visualforce
  └── apex.lua

---

Data and configuration

json
jsonc
yaml
toml
ini
dotenv

No generic source-level DAP should be invented.

---

Build descriptions

cmake
meson
make
ninja
bazel
buck
gradle

Debug the process or language launched by the build system.

Build systems may participate in debug target discovery, but that does not make them source-level debuggers.

---

Recommended implementation roadmap

The updated implementation order should be:

Phase 1 — Shared native debugger foundations
│
├── 1. lldb.lua
└── 2. gdb.lua
        │
        ▼
Phase 2 — Existing README backlog
│
├── 3. zig.lua
├── 4. ansible.lua
├── 5. haskell.lua
├── 6. php.lua
├── 7. ruby.lua
└── 8. cobol.lua
        │
        ▼
Phase 3 — Major missing runtime families
│
├── 9.  dart.lua
├── 10. elixir.lua
├── 11. erlang.lua
├── 12. godot.lua
├── 13. ocaml.lua
├── 14. unity.lua
├── 15. r.lua
└── 16. perl.lua
        │
        ▼
Phase 4 — Embedded development
│
├── 17. probe.lua
└── 18. esp32.lua
        │
        ▼
Phase 5 — Additional ecosystems
│
├── haxe.lua
├── luau.lua
├── ballerina.lua
├── puppet.lua
├── prolog.lua
├── tla.lua
├── qasm.lua
└── wolfram.lua
        │
        ▼
Phase 6 — Specialist / retro adapters
    ├── z80.lua
    ├── emulicious.lua
    ├── duktape.lua
    ├── papyrus.lua
    ├── vdm.lua
    ├── harbour.lua
    └── other project-specific adapters

---

Master implementation matrix

Implemented

[✅] android.lua
[✅] apex.lua
[✅] bash.lua
[✅] csharp.lua
[✅] go.lua
[✅] java.lua
[✅] kotlin.lua
[✅] lua.lua
[✅] mojo.lua
[✅] nix.lua
[✅] node.lua
[✅] postgres.lua
[✅] powershell.lua
[✅] python.lua
[✅] rust.lua
[✅] scala.lua
[✅] sql.lua
[✅] sqlite.lua
[✅] unreal.lua

Immediate backlog

[ ] lldb.lua
[ ] gdb.lua
[ ] zig.lua
[ ] ansible.lua
[ ] haskell.lua
[ ] php.lua
[ ] ruby.lua
[ ] cobol.lua

Recommended expansion

[ ] dart.lua
[ ] elixir.lua
[ ] erlang.lua
[ ] godot.lua
[ ] ocaml.lua
[ ] unity.lua
[ ] r.lua
[ ] perl.lua
[ ] probe.lua
[ ] esp32.lua

Optional language/runtime expansion

[ ] ballerina.lua
[ ] haxe.lua
[ ] luau.lua
[ ] puppet.lua
[ ] prolog.lua
[ ] squirrel.lua
[ ] tla.lua
[ ] qasm.lua
[ ] wolfram.lua
[ ] onescript.lua
[ ] harbour.lua
[ ] papyrus.lua
[ ] vdm.lua
[ ] zil.lua

Optional specialist targets

[ ] firefox.lua
[ ] z80.lua
[ ] emulicious.lua
[ ] duktape.lua
[ ] krom.lua

---

Overall status

Current native Diver modules:

19 implemented

Already-planned backlog:

8 modules

Recommended next ecosystem expansion:

10 modules

The most important architectural work is therefore not to produce dozens of one-off DAP files immediately.

The highest-leverage sequence is:

lldb.lua
   +
gdb.lua
   │
   ▼
shared native debugger foundation
   │
   ├── compiled languages
   ├── embedded debugging
   ├── remote debugging
   └── runtime-specific wrappers

After those foundations exist, implement runtime-specific adapters only where they provide behavior that cannot cleanly be expressed through the shared debugger modules.

---

Native-first policy

Every new Diver DAP module should prefer:

standalone/native DAP
        │
        ▼
runtime-provided DAP
        │
        ▼
LSP-brokered DAP
        │
        ▼
editor-extension adapter assets

and should use Neovim 0.13+ primitives wherever practical:

vim.debug
vim.async
vim.system
vim.fs
vim.ui.select
vim.ui.input
vim.lsp

No Neovim DAP plugin should be required merely to register, launch, communicate with, or manage a standards-compliant debug adapter.

---

Sources of truth

When adding or updating an integration, compare:

1. The upstream debugger/runtime documentation.
2. The Debug Adapter Protocol implementor registry.
3. The actual adapter repository and current launch protocol.
4. Diver's existing reusable DAP foundations.
5. Neovim's current "vim.debug" API.

The public DAP implementor registry is an inventory rather than a requirement that Diver implement every listed adapter.

A new module should exist because it represents a distinct runtime or materially distinct debugging workflow—not merely because another editor ships an extension for it.