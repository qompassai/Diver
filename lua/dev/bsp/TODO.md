# TODO: Build Server Protocol clients

Status of native BSP client modules for `qompassai/Diver`, modeled on
`lua/bsp/init.lua` (client) and `lua/bsp/servers/*.lua` (per-tool connection
resolvers). `lua/bsp/servers/init.lua` is the registry: `M.detect` walks it in
order and returns the first server whose root markers match.

Each module only needs to:

1. find the project root (`M.root`);
2. read/produce the `.bsp/*.json` connection file (`M.connection`);
3. hand `argv`/`bspVersion`/`languages` back to the shared client in
   `lua/bsp/init.lua` (plus `M.executable` as a launch guard).

The client itself (`build/initialize`, diagnostics, `workspace/buildTargets`,
`buildTarget/compile`, `:Bsp*` commands) is generic and reusable across every
entry below. `M.setup({ server_name = ... })` pins one registry entry;
`nil` (default) auto-detects.

Maintenance status verified 2026-09-27 via GitHub `pushed_at`.

---

## Done

- [x] **Gradle** (Java/Kotlin, incl. Android) — `lua/bsp/servers/gradle.lua`.
      Source: [microsoft/build-server-for-gradle](https://github.com/microsoft/build-server-for-gradle)
      (active, pushed 2026-09-23; needs JDK 17+ to launch). Root markers:
      `settings.gradle(.kts)`, `build.gradle(.kts)`. Wired into the Android
      dev flow: `dev.android.gradle.bsp_status()` and the `:Android`
      `bsp_status` action.
- [x] **Cargo** (Rust) — `lua/bsp/servers/cargo.lua`.
      Source: [cargo-bsp/cargo-bsp](https://github.com/cargo-bsp/cargo-bsp)
      — **stale upstream** (last push 2023-10-12, effectively unmaintained).
      The resolver still works with any `.bsp/*.json` card; BSP 2.2.0 added
      official `cargo`/`Rust` protocol extensions, so revisit when a
      maintained server appears. This is the Rust/phlow path.
- [x] **Bazel** (multi-language, via JetBrains Hirschgarten) —
      `lua/bsp/servers/bazel.lua`.
      Source: [JetBrains/hirschgarten](https://github.com/JetBrains/hirschgarten)
      (active, pushed 2026-09-26; successor to the archived
      [JetBrains/bazel-bsp](https://github.com/JetBrains/bazel-bsp)).
- [x] **sbt** (Scala) — `lua/bsp/servers/sbt.lua`. BSP support is **built
      into sbt itself** since 1.4.0 — no separate server binary, just
      `sbt bspConfig` or launching sbt with `-bsp`.
      Source: [sbt/sbt](https://github.com/sbt/sbt) (active, pushed 2026-09-26).
      Root markers: `build.sbt`, `project/build.properties`.
- [x] **Mill** (Scala / Java / Kotlin) — `lua/bsp/servers/mill.lua`. BSP has
      been **built into Mill** since 0.9.3 (previously a contrib plugin).
      Connection card is regenerated on each BSP server start.
      Source: [com-lihaoyi/mill](https://github.com/com-lihaoyi/mill)
      (active, pushed 2026-09-25). Root markers: `build.mill`, `build.sc`.
- [x] **Bloop** (Scala compile server for sbt / Gradle / Maven / Mill) —
      `lua/bsp/servers/bloop.lua`. Standalone compile server; other build
      tools export *to* Bloop, and Bloop is what actually answers the BSP
      requests. This is also the path for **Maven** — Maven has no native BSP
      implementation; Bloop's `maven-bloop` plugin is the only supported
      route.
      Source: [scalacenter/bloop](https://github.com/scalacenter/bloop)
      (active, pushed 2026-09-25). Root markers: `.bloop/` directory.
- [x] **scala-cli** (Scala / Java, single-file and small projects) —
      `lua/bsp/servers/scalacli.lua`. Acts as its own BSP server for ad hoc
      `.sc`/`.scala` scripts, and as a BSP *client* toward Bloop for larger
      setups. Connection card regenerated per start, same as Mill.
      Source: [VirtusLab/scala-cli](https://github.com/VirtusLab/scala-cli)
      (active, pushed 2026-09-24). Root markers: `project.scala`, `.bsp/`.
- [x] **Pants** (Python, Java, Scala, Go, Shell — monorepo build tool) —
      `lua/bsp/servers/pants.lua`. Experimental first-party
      `experimental-bsp` goal; writes the connection card via
      `pants experimental-bsp`. Requires a repo-level `bsp-groups.toml`
      naming target groups — the resolver fails informatively if that file
      is absent rather than guessing.
      Source: [pantsbuild/pants](https://github.com/pantsbuild/pants)
      (active, pushed 2026-09-22). Root markers: `pants.toml`.
- [x] **Swift** (SwiftPM / Xcode projects) — `lua/bsp/servers/swift.lua`.
      No single canonical server; implemented against
      [wvteijlingen/swift-bsp](https://github.com/wvteijlingen/swift-bsp)
      (wraps `swift-build`, works with Xcode projects, feeds SourceKit-LSP).
      Caveat: small community project, moves slowly (last push 2026-06-15) —
      treat failures as "check upstream". Revisit once Apple's first-party
      server ([swift-tools-protocols](https://github.com/swiftlang/swift-tools-protocols),
      tracking [swift-package-manager#8287](https://github.com/swiftlang/swift-package-manager/issues/8287))
      lands, since the connection card shape may change.
      Root markers: `Package.swift`.

---

## Explicitly not planned

- **Buck2** — no BSP implementation found upstream as of this writing (Buck2
  uses its own query/RPC interfaces, not BSP). Revisit if Meta publishes one.
- **CMake / Make / plain Clang projects** — no BSP concept applies; these
  stay on `lua/scip/indexers/clang.lua` (SCIP) and direct `compile_commands.json`
  consumption rather than a build-server connection.

---

## Reference

- Protocol spec and canonical implementations table:
  [build-server-protocol.github.io/docs/overview/implementations](https://build-server-protocol.github.io/docs/overview/implementations)
- Protocol source and issue tracker:
  [build-server-protocol/build-server-protocol](https://github.com/build-server-protocol/build-server-protocol)
