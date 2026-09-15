# TODO: Remaining Build Server Protocol Clients

Status of native BSP client modules for `qompassai/Diver`, modeled on
`lua/utils/bsp/init.lua` (client) and `lua/utils/bsp/cargo.lua` /
`lua/bsp/bazel.lua` (per-tool connection resolvers).

Each module only needs to:

1. find the project root (`M.root`);
2. read/produce the `.bsp/*.json` connection file (`M.connection`);
3. hand `argv`/`bspVersion`/`languages` back to the shared client in
   `lua/utils/bsp/init.lua`.

The client itself (`build/initialize`, diagnostics, `workspace/buildTargets`,
`buildTarget/compile`, `:Bsp*` commands) is already generic and reusable
across every entry below.

---

## Done

- [x] **Cargo** (Rust) â€” client-side resolver already in
      `lua/utils/bsp/cargo.lua` / `lua/bsp/cargo.lua`.
      Source: [cargo-bsp/cargo-bsp](https://github.com/cargo-bsp/cargo-bsp)
- [x] **Bazel** (multi-language, via JetBrains Hirschgarten) â€”
      `lua/bsp/bazel.lua`.
      Source: [JetBrains/hirschgarten](https://github.com/JetBrains/hirschgarten)
      (successor to the archived
      [JetBrains/bazel-bsp](https://github.com/JetBrains/bazel-bsp))

---

## To convert

### sbt (Scala)

- [ ] `lua/utils/bsp/sbt.lua`
- BSP support is **built into sbt itself** since 1.4.0 â€” no separate server
  binary to install, just `sbt bspConfig` or launching sbt with `-bsp`.
- Source: [sbt/sbt](https://github.com/sbt/sbt)
- Root markers: `build.sbt`, `project/build.properties`.
- Diver already has `lua/dap/scala.lua`; this is the natural companion.

### Mill (Scala / Java / Kotlin)

- [ ] `lua/utils/bsp/mill.lua`
- BSP has been **built into Mill** since 0.9.3 (previously a contrib plugin).
  Connection file is regenerated on each BSP server start.
- Source: [com-lihaoyi/mill](https://github.com/com-lihaoyi/mill)
- Root markers: `build.mill`, `build.sc` (legacy Mill syntax).

### Bloop (Scala compile server for sbt / Gradle / Maven / Mill)

- [ ] `lua/utils/bsp/bloop.lua`
- Standalone compile server; other build tools export *to* Bloop, and Bloop
  is what actually answers the BSP requests.
- Source: [scalacenter/bloop](https://github.com/scalacenter/bloop)
- Root markers: `.bloop/` directory (exported project JSON files).
- Note: this is the path for **Maven** too â€” Maven has no native BSP
  implementation; Bloop's `maven-bloop` plugin is the only supported route.

### scala-cli (Scala / Java, single-file and small projects)

- [ ] `lua/utils/bsp/scala_cli.lua`
- Acts as its own BSP server for ad hoc `.sc`/`.scala` scripts, and as a BSP
  *client* toward Bloop for larger setups. Connection file regenerated per
  start, same as Mill.
- Source: [VirtusLab/scala-cli](https://github.com/VirtusLab/scala-cli)
- Root markers: `project.scala`, a lone `*.sc`/`*.scala` with no other build
  file present.

### Gradle (Java, Kotlin via plugin)

- [ ] `lua/utils/bsp/gradle.lua`
- Microsoft's implementation; requires JDK 17+ to build/launch the server
  itself.
- Source: [microsoft/build-server-for-gradle](https://github.com/microsoft/build-server-for-gradle)
- Root markers: `build.gradle`, `build.gradle.kts`, `settings.gradle(.kts)`.

### Pants (Python, Java, Scala, Go, Shell â€” monorepo build tool)

- [ ] `lua/utils/bsp/pants.lua`
- Experimental, first-party `experimental-bsp` goal; writes the connection
  file via `pants experimental-bsp` rather than a background daemon.
- Source: [pantsbuild/pants](https://github.com/pantsbuild/pants)
  ([experimental-bsp goal docs](https://www.pantsbuild.org/stable/reference/goals/experimental-bsp))
- Root markers: `pants.toml`, `BUILD` files, `bsp-groups.toml`.
- Caveat: requires a repo-level `bsp-groups.toml` naming target groups before
  a connection file will even exist â€” resolver should fail informatively if
  that file is absent rather than guessing.

### Swift (SwiftPM / Xcode projects)

- [ ] `lua/utils/bsp/swift.lua`
- No single canonical server yet; two active community implementations plus
  first-party groundwork:
  - [wvteijlingen/swift-bsp](https://github.com/wvteijlingen/swift-bsp) â€”
    wraps `swift-build`, works with Xcode projects, feeds SourceKit-LSP.
  - [khlopko/xcode-bsp](https://github.com/khlopko/xcode-bsp) â€” targets
    Xcode projects specifically.
  - [swiftlang/swift-tools-protocols](https://github.com/swiftlang/swift-tools-protocols) â€”
    official LSP/BSP model types and transport Apple is building toward a
    first-party server on.
  - Tracking issue for the eventual official server:
    [swiftlang/swift-package-manager#8287](https://github.com/swiftlang/swift-package-manager/issues/8287)
- Root markers: `Package.swift`, `*.xcodeproj`, `*.xcworkspace`.
- Recommendation: implement against `wvteijlingen/swift-bsp` first since it
  is the most complete today; revisit once the official server in #8287
  lands, since the connection file shape may change.

---

## Explicitly not planned

- **Buck2** â€” no BSP implementation found upstream as of this writing (Buck2
  uses its own query/RPC interfaces, not BSP). Revisit if Meta publishes one.
- **CMake / Make / plain Clang projects** â€” no BSP concept applies; these
  stay on `lua/scip/indexers/clang.lua` (SCIP) and direct `compile_commands.json`
  consumption rather than a build-server connection.

---

## Reference

- Protocol spec and canonical implementations table:
  [build-server-protocol.github.io/docs/overview/implementations](https://build-server-protocol.github.io/docs/overview/implementations)
- Protocol source and issue tracker:
  [build-server-protocol/build-server-protocol](https://github.com/build-server-protocol/build-server-protocol)
