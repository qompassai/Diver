# tests/

Headless Neovim tests for the Diver config, organized by subject.
Each subdirectory mirrors the `lua/` source tree it exercises.

<details>
<summary>Table of Contents</summary>

- [`ai/`](ai/) — AI tooling: inference, caching, retrieval, personas, recon
- [`bidi/`](bidi/) — WebDriver BiDi protocol implementation
- [`bsp/`](bsp/) — Build Server Protocol registry and fixtures
- [`busted/`](busted/) — Busted unit/integration specs (busted framework)
- [`cdp/`](cdp/) — Chrome DevTools Protocol implementation
- [`comms/`](comms/) — Email clients and communications
- [`dap/`](dap/) — Debug Adapter Protocol configurations
- [`dev/`](dev/) — Developer tooling: apps, cargo, run, scip
- [`fixtures/`](fixtures/) — Shared test fixtures (not tests)
- [`formatters/`](formatters/) — Formatter pipeline stages
- [`games/`](games/) — Game dev tooling: Love2D, Blender, Aseprite, characters
- [`git/`](git/) — Git integration (dev.git)
- [`jj/`](jj/) — Jujutsu (jj) VCS integration
- [`lang/`](lang/) — Language configs: coverage, buffer-local commands
- [`mappings/`](mappings/) — Keymap/mapping definitions
- [`markdown/`](markdown/) — Markdown rendering
- [`mcp/`](mcp/) — Model Context Protocol server
- [`nav/`](nav/) — Navigation: finders and the directory ring
- [`proto/`](proto/) — Wire protocols (websocket)
- [`python/`](python/) — Python tooling tests
- [`research/`](research/) — Research tooling: doc headers
- [`rust/`](rust/) — Rust FFI and tooling tests
- [`scip/`](scip/) — SCIP code indexing
- [`security/`](security/) — Security: guard, masking, PQC, ownership
- [`sf/`](sf/) — Salesforce tooling: trailhead, tasks
- [`sync/`](sync/) — Sync utilities
- [`testmore/`](testmore/) — TAP test scripts (prove framework)
- [`tmux/`](tmux/) — Tmux integration
- [`tools/`](tools/) — General tools (notify)
- [`ui/`](ui/) — UI: facade, icons, calendar
- [`vulkan/`](vulkan/) — Vulkan SDK, toolchain, RenderDoc

</details>

<details>
<summary>Layout diagram</summary>

```
tests/
├── ai/
│   └── tests for: AI tooling: inference, caching, retrieval, personas, recon
├── bidi/
│   └── tests for: WebDriver BiDi protocol implementation
├── bsp/
│   └── tests for: Build Server Protocol registry and fixtures
├── busted/
│   └── tests for: Busted unit/integration specs (busted framework)
├── cdp/
│   └── tests for: Chrome DevTools Protocol implementation
├── comms/
│   └── tests for: Email clients and communications
├── dap/
│   └── tests for: Debug Adapter Protocol configurations
├── dev/
│   └── tests for: Developer tooling: apps, cargo, run, scip
├── fixtures/
│   └── tests for: Shared test fixtures (not tests)
├── formatters/
│   └── tests for: Formatter pipeline stages
├── games/
│   └── tests for: Game dev tooling: Love2D, Blender, Aseprite, characters
├── git/
│   └── tests for: Git integration (dev.git)
├── jj/
│   └── tests for: Jujutsu (jj) VCS integration
├── lang/
│   └── tests for: Language configs: coverage, buffer-local commands
├── mappings/
│   └── tests for: Keymap/mapping definitions
├── markdown/
│   └── tests for: Markdown rendering
├── mcp/
│   └── tests for: Model Context Protocol server
├── nav/
│   └── tests for: Navigation: finders and the directory ring
├── proto/
│   └── tests for: Wire protocols (websocket)
├── python/
│   └── tests for: Python tooling tests
├── research/
│   └── tests for: Research tooling: doc headers
├── rust/
│   └── tests for: Rust FFI and tooling tests
├── scip/
│   └── tests for: SCIP code indexing
├── security/
│   └── tests for: Security: guard, masking, PQC, ownership
├── sf/
│   └── tests for: Salesforce tooling: trailhead, tasks
├── sync/
│   └── tests for: Sync utilities
├── testmore/
│   └── tests for: TAP test scripts (prove framework)
├── tmux/
│   └── tests for: Tmux integration
├── tools/
│   └── tests for: General tools (notify)
├── ui/
│   └── tests for: UI: facade, icons, calendar
├── vulkan/
│   └── tests for: Vulkan SDK, toolchain, RenderDoc
```

</details>

<details>
<summary>Frameworks</summary>

- `busted/` — busted specs (`busted --run=unit`). See `skills/diver-busted-spec/`.
- `testmore/` — TAP scripts run via `prove`. Never share assertion globals with busted.
- Everything else — headless Neovim scripts: `nvim --headless -u NONE -i NONE -l <file>`.
  (Some need the full config: `-u init.lua -c "luafile <file>"` — the file header says which.)

</details>

<details>
<summary>Conventions</summary>

- One test file per behavior; headers state the run command.
- Half validation / half adversarial where the skill applies.
- Tests never touch the live tree: temp dirs, mocked notify, persistence disabled.

</details>
