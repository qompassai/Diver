# Native Formatter TODO

Updated: 2026-09-21

Plugin-free formatter roadmap for the native Neovim 0.13+ formatter framework.

The priorities below favor:

1. canonical language/toolchain formatters;
2. actively maintained projects;
3. tools that are already installed on this Arch system;
4. formatters with clean stdin/stdout or deterministic file-mode behavior;
5. avoiding multiple competing full-file formatters for the same filetype.

## Status legend

- [x] Native formatter adapter already exists.
- [ ] Native formatter adapter still needs to be written.
- **Installed** means the formatter appeared as installed in the supplied Arch/AUR package snapshot.
- **Canonical** means the formatter is provided by, or tightly coupled to, the language/toolchain.
- **Preferred** means it should normally be the first formatter tried for that filetype.
- **Alternative** means keep it available for repositories that explicitly standardize on it.

---

# 1. Completed native formatter framework

## Framework

- [x] `init.lua`
- [x] `catalog.lua`
- [x] `process.lua`
- [x] `tools.lua`

Keep process execution centralized here rather than duplicating `vim.system()` or
`config.core.async` orchestration in every formatter adapter.

## Completed formatter adapters

- [x] `alejandra.lua` — Nix
- [x] `bibtex-tidy.lua` — BibTeX
- [x] `clang_format.lua` — C/C++/Objective-C and related Clang-supported languages
- [x] `d2.lua` — D2 diagrams
- [x] `dioxus.lua` — Dioxus / RSX
- [x] `gofumpt.lua` — Go
- [x] `goimports.lua` — Go import-aware formatting
- [x] `google_java_format.lua` — Java (Google Java Style)
- [x] `jsonnetfmt.lua` — Jsonnet
- [x] `ktfmt.lua` — Kotlin
- [x] `nixfmt.lua` — Nix (tiger-style profile: width 100, 2-space indent, `--strict`)
- [x] `phpcsfixer.lua` — PHP
- [x] `pint.lua` — Laravel PHP
- [x] `shfmt.lua` — shell
- [x] `uncrustify.lua` — configurable C-family formatting
- [x] `wgslfmt.lua` — WGSL

**Current total: 16 formatter adapters + 4 framework modules.**

---

# 2. P0 — highest-value formatters still to implement

These should be the next adapters because they cover major languages in the
configuration and are modern, canonical, or very actively maintained.

## Lua / LuaJIT / Luau

- [ ] **`stylua.lua` — StyLua**
  - **Preferred**
  - Upstream: <https://github.com/JohnnyMorganz/StyLua>
  - Actively maintained; 2.5.x releases shipped in 2026.
  - Support stdin/stdout and explicit config discovery.
  - Prefer repository `.stylua.toml` / `stylua.toml`.
  - Keep `lua-format` only as a repository-specific alternative, not a default.
  - Do not chain StyLua and LuaFormatter.

## Python

- [ ] **`ruff_format.lua` — Ruff formatter**
  - **Preferred for new repositories**
  - Upstream: <https://github.com/astral-sh/ruff>
  - Very actively maintained through 2026.
  - Use `ruff format`.
  - Keep lint/fix actions separate from formatting.
  - Preserve Black compatibility as a policy choice rather than chaining tools.

- [ ] **`black.lua` — Black**
  - **Alternative**
  - **Installed**
  - Use only when a repository explicitly standardizes on Black.
  - Do not run Black and Ruff formatter sequentially.

## Rust

- [ ] **`rustfmt.lua` — rustfmt**
  - **Canonical**
  - Prefer `cargo fmt` for project-aware formatting.
  - Support direct `rustfmt` for isolated buffers only when appropriate.
  - Respect `rustfmt.toml`.
  - Keep import organization separate unless the toolchain owns it.

## JavaScript / TypeScript / JSON / CSS / web

- [ ] **`biome.lua` — Biome**
  - **Preferred for Biome-owned repositories**
  - **Installed**
  - Upstream: <https://github.com/biomejs/biome>
  - Very active 2.5.x release line in 2026.
  - Cover JavaScript, TypeScript, JSX/TSX, JSON/JSONC, CSS, and supported web formats.
  - Do not automatically chain with Prettier or Oxfmt.

- [ ] **`oxfmt.lua` — Oxfmt**
  - **Modern alternative**
  - Upstream: <https://github.com/oxc-project/oxc>
  - Rapidly maintained in 2026; use only for repositories choosing Oxc formatting.
  - Keep as an alternative to Biome/Prettier, not a second pass.

- [ ] **`prettier.lua` — Prettier**
  - **Alternative / broad ecosystem fallback**
  - **Installed**
  - Useful for Markdown, YAML, GraphQL, HTML and plugin-owned ecosystems.
  - Prefer project-local executable when `package.json` owns the version.
  - Do not run after Biome/Oxfmt on the same buffer.

## Nix

- [x] **`nixfmt.lua` — nixfmt**
  - **Canonical / preferred for new Nix repositories**
  - Upstream: <https://github.com/NixOS/nixfmt>
  - Official Nix formatter with active 1.x releases in 2026; adapter reviewed against 1.5.0.
  - Tiger-style nix profile: `--width 100`, two-space `--indent 2`, `--strict` for
    input-independent deterministic output. stdin via `-` with `--filename`;
    nixfmt reads no config files, so these flags are the pinned profile.
  - Keep the completed `alejandra.lua` for repositories already standardized on Alejandra.
  - Do not run nixfmt and Alejandra sequentially.

## TOML

- [ ] **`tombi.lua` — Tombi**
  - **Preferred**
  - **Installed**
  - Upstream: <https://github.com/tombi-toml/tombi>
  - Modern Rust formatter/linter/LSP with active releases.
  - Use only its formatting operation from the formatter layer.
  - Keep lint/LSP concerns outside the formatter runner.

- [ ] `taplo.lua` — Taplo
  - **Alternative**
  - Useful when a repository already owns Taplo configuration.
  - Do not chain Tombi and Taplo.

## YAML

- [ ] **`yamlfmt.lua` — yamlfmt**
  - **Preferred**
  - Upstream: <https://github.com/google/yamlfmt>
  - Actively maintained; 0.21.0 released in 2026.
  - Preserve comments and repository configuration.

- [ ] `yamlfix.lua` — yamlfix
  - **Installed**
  - Alternative for repositories that already use yamlfix.
  - Do not run both yamlfix and yamlfmt on save.

## Markdown

- [ ] **`mdformat.lua` — mdformat**
  - **Installed**
  - Upstream: <https://github.com/executablebooks/mdformat>
  - Good CommonMark-oriented formatter.
  - Support project plugin configuration explicitly.

- [ ] `rumdl.lua` — Rumdl formatter mode
  - **Installed**
  - Keep formatting separate from Rumdl diagnostics/lint execution.
  - Do not automatically run both Rumdl formatting and mdformat.

## SQL

- [ ] **`sqruff.lua` — Sqruff**
  - **Preferred modern SQL option**
  - Upstream: <https://github.com/quarylabs/sqruff>
  - Active releases in 2026.
  - Make SQL dialect an explicit formatter option/root setting.

- [x] `pg_format.lua` — pgFormatter
  - Module name is `pg_format` to match the existing `init.lua` registry
    (`['pg_format'] = 'formatters.pg_format'`) and the `sql` filetype chain.
  - Tiger-style SQL profile pinned in flags: 4-space indent, wrap-limit 100,
    `--no-rcfile` for deterministic output (pgFormatter v5.11).
  - Prefer for PostgreSQL-specific repositories.

- [ ] `sqlfluff.lua` — SQLFluff
  - Alternative when the repository already uses SQLFluff.
  - Do not combine SQLFluff fixes and another SQL full-file formatter automatically.

## SystemVerilog / Verilog

- [ ] **`verible.lua` — Verible**
  - **Preferred**
  - Upstream: <https://github.com/chipsalliance/verible>
  - Actively released in 2026.
  - Use `verible-verilog-format`.
  - Prefer the maintained stable package over stale/orphaned `-git` packaging.

## Typst

- [ ] **`typstyle.lua` — Typstyle**
  - **Preferred**
  - **Installed**
  - Use instead of the orphaned `typstfmt-bin`.
  - Avoid a second Typst formatting pass.

---

# 3. P1 — major language/toolchain formatters

## Java

- [x] **`google_java_format.lua` — google-java-format**
  - **Preferred**
  - Upstream: <https://github.com/google/google-java-format>
  - Active 1.36.x release line in 2026; adapter pins 1.36.1.
  - stdin/stdout via `-` with `--assume-filename`; no range formatting yet.
  - Requires a JDK (not JRE), version 21 or newer; `--add-exports` flags
    are passed unconditionally for JEP 396 (JDK 16+).

## Scala

- [ ] **`scalafmt.lua` — Scalafmt**
  - **Installed**
  - Upstream: <https://github.com/scalameta/scalafmt>
  - Active 3.11.x releases in 2026.
  - Respect `.scalafmt.conf`.

## Haskell

- [ ] **`fourmolu.lua` — Fourmolu**
  - **Preferred when configurability is wanted**
  - Upstream: <https://github.com/fourmolu/fourmolu>
  - Maintained fork tracking Ormolu improvements.

- [ ] `ormolu.lua` — Ormolu
  - Alternative for repositories standardizing on canonical Ormolu output.
  - Do not run Fourmolu and Ormolu sequentially.

## Swift

- [ ] **`swift_format.lua` — swift-format**
  - **Canonical**
  - Upstream: <https://github.com/swiftlang/swift-format>
  - Active release line matching modern Swift toolchains.
  - Prefer the toolchain-provided `swift format` when available.

## OCaml

- [ ] **`ocamlformat.lua` — OCamlFormat**
  - **Canonical**
  - Upstream: <https://github.com/ocaml-ppx/ocamlformat>
  - Active 0.29.x release line in 2026.
  - Respect `.ocamlformat`.

## Erlang

- [ ] **`erlfmt.lua` — erlfmt**
  - **Preferred**
  - Upstream: <https://github.com/WhatsApp/erlfmt>
  - 1.8.0 released in 2026.

## Elixir

- [ ] **`mix_format.lua` — `mix format`**
  - **Canonical**
  - Respect `.formatter.exs`.
  - Prefer project-root execution rather than formatting outside a Mix project.

## F#

- [ ] **`fantomas.lua` — Fantomas**
  - **Preferred**
  - Use the upstream .NET tool even if a particular AUR binary package is orphaned.
  - Prefer project/tool-manifest version when available.

## D

- [ ] **`dfmt.lua` — dfmt**
  - **Installed**
  - Canonical ecosystem choice for D source formatting.

## GDScript

- [ ] **`gdformat.lua` — gdformat / gdtoolkit**
  - **Preferred**
  - Upstream: <https://github.com/Scony/godot-gdscript-toolkit>
  - Active fixes and releases in 2026.
  - Keep gdlint separate from formatting.

## Fortran

- [ ] **`fprettify.lua` — fprettify**
  - Prefer for modern Fortran.
  - Do not mix with unrelated fixed-form rewriters without explicit project policy.

## Ada

- [ ] **`gnatformat.lua` — GNATformat**
  - Prefer the GNAT/Ada toolchain formatter.
  - Keep formatting version aligned with the compiler/toolchain where possible.

## C#

- [ ] **`csharpier.lua` — CSharpier**
  - Prefer the maintained upstream/source package rather than an orphaned binary package.
  - Keep `dotnet format` as a separate project-policy alternative.

## Clojure / EDN

- [ ] **`cljfmt.lua` — cljfmt**
  - Standard formatter choice for Clojure-family source.
  - Keep Joker formatting as an optional alternate workflow only.

---

# 4. P1 — build/config/document formatters

## CMake

- [ ] **`gersemi.lua` — Gersemi**
  - **Installed**
  - Modern CMake formatter; good default for new adapters.

- [ ] `cmake_format.lua` — cmake-format
  - **Installed**
  - Alternative for repositories already configured around cmakelang.
  - Do not run Gersemi and cmake-format sequentially.

## Bazel / Starlark

- [ ] **`buildifier.lua` — Buildifier**
  - **Canonical**
  - Use `buildifier` from Bazel buildtools.
  - Cover `BUILD`, `BUILD.bazel`, `.bzl`, and related Starlark files.

## Terraform / OpenTofu / HCL

- [ ] **`terraform_fmt.lua` — `terraform fmt`**
  - **Canonical for Terraform**

- [ ] **`tofu_fmt.lua` — `tofu fmt`**
  - **Canonical for OpenTofu**

- [ ] `packer_fmt.lua` — `packer fmt`
  - Only for Packer-owned HCL projects.

Do not route all HCL through one formatter without project ownership detection.

## CUE

- [ ] **`cue_fmt.lua` — `cue fmt`**
  - **Canonical**
  - Prefer project-aware execution.

## Dockerfile

- [ ] `dockerfmt.lua`
  - Add only after verifying behavior against modern Dockerfile syntax.
  - Lower priority than canonical language/toolchain formatters.

## Device Tree

- [ ] `dtsfmt.lua`
  - Useful because Device Tree parsers already exist in the Neovim configuration.
  - Keep lower priority than Verible/C-family/toolchain adapters.

## Makefiles

- [ ] `mbake.lua`
  - **Installed**
  - Formatter/linter; expose formatting only from this layer.

## XML

- [ ] `xmllint.lua`
  - Good broadly available XML formatter.

- [ ] `xmlformatter.lua`
  - **Installed**
  - Optional Python-based alternative.

Do not chain both.

## LaTeX

- [x] **`tex_fmt.lua` — tex-fmt**
  - **Installed**
  - Modern Rust implementation; high-priority LaTeX choice.
  - Tiger-style LaTeX profile pinned in flags: `--tabsize 4`, `--wraplen 100`,
    `--noconfig` for deterministic output (tex-fmt v0.5.7); stdin via `--stdin`.

- [ ] `latexindent.lua`
  - Alternative for repositories with existing `latexindent` configuration.

- [ ] `llf.lua`
  - **Installed**
  - Keep as optional specialized alternative rather than default.

## BibTeX

- [x] `bibtex-tidy.lua`
  - Already covered; no need to add another default BibTeX formatter.

---

# 5. P2 — canonical toolchain formatters worth adding

These are strong additions, but lower priority because they are narrower or
already have acceptable LSP/toolchain formatting paths.

- [x] `dart_format.lua` — `dart format`
- [x] `fish_indent.lua` — `fish_indent`
- [x] `gleam_format.lua` — `gleam format`
- [x] `zig_fmt.lua` — `zig fmt`
- [x] `crystal_format.lua` — `crystal tool format`
- [x] `rescript_format.lua` — `rescript format`
- [x] `v_fmt.lua` — `v fmt`
- [x] `nimpretty.lua` — `nimpretty`
- [x] `bicep_format.lua` — `bicep format`
- [ ] `forge_fmt.lua` — `forge fmt` for Solidity/Foundry
- [ ] `perltidy.lua` — Perl::Tidy
- [ ] `rubocop.lua` — RuboCop autocorrection for Ruby repositories choosing RuboCop
- [ ] `standardrb.lua` — StandardRB alternative for Ruby
- [ ] `styler.lua` — R `styler`
- [ ] `air.lua` — Air formatter for R repositories choosing Air
- [ ] `fnlfmt.lua` — Fennel
  - **Installed**
- [ ] `blade_formatter.lua` — Blade
  - **Installed**
- [ ] `nginxbeautifier.lua` — nginx
  - **Installed**
- [ ] `kdlfmt.lua` — KDL
  - **Installed**
- [ ] `verusfmt.lua` — Verus
  - **Installed**
- [ ] `jfmt.lua` — JSON
  - **Installed**
  - Optional only; JSON is already covered by Biome/Prettier and should not be double-formatted.
- [ ] `formatjson.lua` — JSON
  - **Installed**
  - Optional only for repositories explicitly selecting it.

---

# 6. Universal / query-driven formatter

- [ ] **`topiary.lua` — Topiary**
  - **Installed**
  - Upstream: <https://github.com/tweag/topiary>
  - Tree-sitter-query-driven universal formatter.
  - Valuable as a fallback for languages with no strong canonical formatter.
  - Do not make it the default for languages already served by a canonical formatter.
  - Particularly interesting for the native Neovim setup because both systems already
    rely heavily on Tree-sitter query semantics.

---

# 7. Tools that should not be prioritized as new defaults

These may remain installed or supported for repository-specific reasons, but
should not displace a stronger maintained/canonical formatter.

- [ ] Do **not** add `typstfmt-bin` as the default; use Typstyle.
- [ ] Do **not** add orphaned `nixpkgs-fmt` as the default; use nixfmt or the existing Alejandra adapter.
- [ ] Do **not** add `blacktex` as the primary LaTeX formatter; prefer tex-fmt or latexindent.
- [ ] Do **not** add `blackd-systemd` as a formatter target; use Ruff or Black directly.
- [ ] Do **not** add `fsqlf` as the SQL default; prefer Sqruff, SQLFluff, or pgFormatter.
- [ ] Do **not** treat `glsl_analyzer` as a formatter adapter merely because it exposes formatting through LSP.
- [ ] Do **not** prioritize `astyle` for C/C++ while clang-format and Uncrustify are already implemented.
- [ ] Do **not** prioritize `knfmt` unless a repository explicitly requires OpenBSD KNF style.
- [ ] Do **not** automatically chain `ktlint` formatting after the existing `ktfmt.lua`.
- [ ] Do **not** use StandardJS / `ts-standard` as a second formatting pass after Biome/Oxfmt/Prettier.
- [ ] Do **not** create multiple JSON formatters in the default chain.
- [ ] Do **not** automatically chain goimports and gofumpt unless import organization is intentionally part of the selected Go policy.

---

# 8. Recommended implementation order

## Wave 1 — core daily languages

- [ ] `stylua.lua`
- [ ] `ruff_format.lua`
- [ ] `rustfmt.lua`
- [ ] `biome.lua`
- [x] `nixfmt.lua`
- [ ] `tombi.lua`
- [ ] `yamlfmt.lua`
- [ ] `mdformat.lua`

## Wave 2 — data, HDL, JVM, documentation

- [ ] `sqruff.lua`
- [ ] `verible.lua`
- [ ] `typstyle.lua`
- [ ] `google_java_format.lua`
- [ ] `scalafmt.lua`
- [x] `tex_fmt.lua`
- [ ] `gersemi.lua`
- [ ] `buildifier.lua`

## Wave 3 — language coverage

- [ ] `fourmolu.lua`
- [ ] `swift_format.lua`
- [ ] `ocamlformat.lua`
- [ ] `erlfmt.lua`
- [ ] `fantomas.lua`
- [ ] `dfmt.lua`
- [ ] `gdformat.lua`
- [ ] `gnatformat.lua`
- [ ] `csharpier.lua`
- [ ] `cljfmt.lua`

## Wave 4 — toolchain and specialist coverage

- [ ] `terraform_fmt.lua`
- [ ] `tofu_fmt.lua`
- [ ] `cue_fmt.lua`
- [x] `dart_format.lua`
- [x] `fish_indent.lua`
- [x] `gleam_format.lua`
- [x] `zig_fmt.lua`
- [x] `crystal_format.lua`
- [ ] `forge_fmt.lua`
- [ ] `perltidy.lua`
- [ ] `styler.lua`
- [ ] `topiary.lua`

---

# 9. Native formatter runner work still worth doing

These are framework improvements rather than new formatter adapters.

## Async/process execution

- [ ] Route asynchronous formatter execution through the corrected `config.core.async`
      abstraction rather than requiring each adapter to understand `vim.async`.
- [ ] Keep `require('config.core.async')` passive at startup.
- [ ] Centralize cancellation in `process.lua`.
- [ ] Cancel the previous formatter task for a buffer when a newer generation supersedes it.
- [ ] Keep generation IDs so stale async output can never overwrite newer buffer contents.
- [ ] Bound captured stdout and stderr.
- [ ] Bound formatter execution time.
- [ ] Kill timed-out child processes cleanly.
- [ ] Never block LSP initialization on formatter/async availability.

## Buffer safety

- [ ] Snapshot `changedtick` before formatting.
- [ ] Reject stale formatter output when the buffer changed during execution.
- [ ] Preserve cursor/view.
- [ ] Preserve fileformat.
- [ ] Preserve final newline.
- [ ] Preserve BOM metadata where relevant.
- [ ] Reject unexpectedly empty output for non-empty source.
- [ ] Apply edits only after successful process exit and validation.
- [ ] Prefer atomic whole-buffer replacement or validated minimal edits.
- [ ] Never silently overwrite a modified unloaded/reloaded buffer.

## Root/config discovery

- [ ] Centralize root-marker discovery in `tools.lua`.
- [ ] Prefer project-local executables where ecosystems expect them.
- [ ] Allow a formatter to declare configuration/root markers declaratively.
- [ ] Cache executable discovery without permanently caching missing commands.
- [ ] Invalidate executable/version caches when `$PATH` or project root changes.
- [ ] Make workspace trust a prerequisite for project-local executable execution.

## Formatter specification

- [ ] Keep formatter modules declarative whenever possible.
- [ ] Add explicit `stdin` / file-mode capability.
- [ ] Add accepted exit-code policy.
- [ ] Add output-empty policy.
- [ ] Add supported filetypes.
- [ ] Add root markers.
- [ ] Add config markers.
- [ ] Add environment overrides only when required.
- [ ] Add executable/version probe metadata without running a probe on every format.
- [ ] Add optional range-format capability.
- [ ] Add explicit mutually-exclusive formatter groups.

## User commands and introspection

- [ ] `:Format`
- [ ] `:Format!`
- [ ] `:FormatInfo`
- [ ] `:FormatStop`
- [ ] `:FormatLsp`
- [ ] Show selected formatter, executable, root, config file, stdin/file mode, and running state.
- [ ] Show why a formatter was skipped or unavailable.
- [ ] Show active fallback chain without executing it.

## Save formatting

- [ ] Keep format-on-save disabled by default.
- [ ] Permit per-project or per-buffer opt-in.
- [ ] Use strict save-time deadlines.
- [ ] Never cascade through multiple competing formatters after a selected formatter fails.
- [ ] Do not silently fall back to LSP after an explicitly selected external formatter fails.
- [ ] Make LSP fallback policy explicit: `never`, `fallback`, or `prefer`.

---

# 10. Formatter policy by filetype

The final goal is one formatter of record per repository/filetype, with
alternatives selected only when repository policy requires them.

| Filetype | Preferred | Existing / alternative |
| --- | --- | --- |
| Lua | StyLua | LuaFormatter only if repo-owned |
| Shell | shfmt | **done** |
| Go | gofumpt | goimports for import policy; both adapters done |
| Rust | rustfmt | — |
| Python | Ruff formatter | Black |
| JS/TS | Biome or Oxfmt | Prettier |
| JSON | Biome | Prettier / jfmt / formatjson |
| Nix | nixfmt **done** | Alejandra **done** |
| TOML | Tombi | Taplo |
| YAML | yamlfmt | yamlfix |
| Markdown | mdformat | Prettier / Rumdl |
| C/C++ | clang-format | Uncrustify; both done |
| Kotlin | ktfmt | **done** |
| PHP | PHP CS Fixer | **done** |
| Laravel | Pint | **done** |
| Java | google-java-format | — |
| Scala | Scalafmt | — |
| Haskell | Fourmolu | Ormolu |
| Swift | swift-format | — |
| OCaml | OCamlFormat | — |
| Erlang | erlfmt | — |
| Elixir | mix format | — |
| F# | Fantomas | — |
| D | dfmt | — |
| GDScript | gdformat | — |
| Ada | GNATformat | — |
| C# | CSharpier | dotnet format |
| SystemVerilog | Verible | — |
| WGSL | wgslfmt | **done** |
| Typst | Typstyle | — |
| CMake | Gersemi | cmake-format |
| Bazel/Starlark | Buildifier | — |
| Terraform | terraform fmt | — |
| OpenTofu | tofu fmt | — |
| CUE | cue fmt | — |
| LaTeX | tex-fmt | latexindent / llf |
| BibTeX | bibtex-tidy | **done** |
| Jsonnet | jsonnetfmt | **done** |
| D2 | d2 | **done** |
| Dioxus/RSX | dioxus | **done** |
| Odin | odinfmt | — |
| Zig | zig fmt | — |
| Fish | fish_indent | — |
| Gleam | gleam format | — |
| Dart | dart format | — |
| Clojure | cljfmt | — |

---

# 11. Maintenance notes from the 2026 review

The following projects showed clear current maintenance signals during the
2026-09 review and are therefore good candidates for the native formatter
roadmap:

- StyLua — active 2.5.x releases in 2026.
- Ruff — active 0.16.x releases in 2026.
- Biome — active 2.5.x release line.
- Oxfmt/Oxc — frequent releases through September 2026.
- nixfmt — active 1.x releases in 2026.
- Tombi — active 1.x releases in 2026.
- yamlfmt — 0.21.0 released in January 2026.
- Sqruff — active 0.39.x release line in 2026.
- Verible — active release builds in 2026.
- Scalafmt — 3.11.5 released in July 2026.
- google-java-format — 1.36.0 released in July 2026.
- swift-format — 603.0.0 released in June 2026.
- OCamlFormat — 0.29.0 released in March 2026.
- erlfmt — 1.8.0 released in February 2026.
- GDScript Toolkit / gdformat — active fixes/releases in 2026.
- Fourmolu — continues tracking upstream Ormolu improvements.
- Topiary — maintained Tree-sitter-query-based universal formatter and useful fallback.

---

# 12. Definition of done for each new formatter adapter

A formatter should not be marked complete merely because the executable runs.

For every new `lua/formatters/<name>.lua` adapter:

- [ ] Explicit command/executable.
- [ ] Explicit supported filetypes.
- [ ] Explicit stdin versus file-mode behavior.
- [ ] Explicit arguments.
- [ ] Explicit accepted exit codes.
- [ ] Explicit root markers.
- [ ] Explicit config markers where applicable.
- [ ] No shell interpolation.
- [ ] No unbounded output capture.
- [ ] No implicit network/download behavior.
- [ ] No plugin dependency.
- [ ] No direct LSP dependency.
- [ ] Compatible with the centralized native process runner.
- [ ] Compatible with cancellation/stale-buffer protection.
- [ ] Idempotence checked on representative fixtures.
- [ ] Empty/unnamed-buffer behavior checked.
- [ ] Missing executable behavior checked.
- [ ] Nonzero exit behavior checked.
- [ ] Unicode input checked.
- [ ] CRLF/final-newline preservation checked where relevant.
- [ ] Adapter documented in this TODO and formatter catalog.
