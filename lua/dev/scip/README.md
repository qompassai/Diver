<!-- /qompassai/Diver/lua/dev/scip/README.md -->
<!-- Qompass AI Diver SCIP Docs -->
<!-- Copyright (C) 2026 Qompass AI, All rights reserved -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# SCIP (Sourcegraph Code Intelligence Protocol)

> ELI5: SCIP is a file format for pre-computed code knowledge — exactly
> where every symbol is defined and used. Diver's SCIP layer runs a language
> indexer over your project and stores the result as `index.scip`, so precise
> go-to-definition, find-references, and cross-file refactor checks work
> instantly, even in codebases too big for an LSP to scan on demand.

## How it works

- The primary module is `lua/dev/scip/` (`require('dev.scip')`). `M.setup(opts)`
  in `init.lua` merges `dev.scip.config` defaults and registers the `:Scip*`
  user commands from `dev.scip.ui`; commands include `:ScipIndex`,
  `:ScipHealth`, `:ScipStatus`, `:ScipStats`, `:ScipCoverage`, `:ScipLint`,
  `:ScipSnapshot`, `:ScipPrint`, and `:ScipCancel`.
- Indexing (`dev.scip.index`, run via `:ScipIndex`) resolves the project root
  from markers (`.git`, `.hg`, overridable), picks the registered indexer for
  the buffer's language from `lua/dev/scip/indexers/`, runs its binary, and
  writes `index.scip` (configurable via `index_file`). Post-index validation
  runs by default (`lint_after_index = true`).
- The read side lives in `dev.scip.query`: it answers "is there an index, is
  it stale, and can indexing be ensured" for downstream consumers — AI
  workflows in `lua/ai/` (`retrieval/scip.lua`, `builder/scip.lua`,
  `dataaccess/scip.lua`) and cross-file refactor safety checks in
  `lua/dev/refactor/scip.lua` all build on this read side.
- `:ScipHealth` reports per-indexer binary availability (warns on missing
  executables) and checks for the `scip` CLI. Wired lazily into navigation
  via `lua/config/mappings/navmap.lua`, which calls
  `require('dev.scip').setup()`.

## Inventory (alphabetical)

| Name | Config | Binary | Filetypes | Status | Install | Upstream |
| ---- | ------ | ------ | --------- | ------ | ------- | -------- |
| apex | `lua/dev/scip/indexers/apex.lua` | `scip-apex` | apex | Active | prebuilt binary from [scip-apex releases](https://github.com/octoberswimmer/scip-apex/releases) (linux_amd64 zip + SHA256SUMS) | — |
| clang | `lua/dev/scip/indexers/clang.lua` | `scip-clang` | c, cpp, cuda, objc, objcpp | Active | `curl` prebuilt binary from [scip-clang releases](https://github.com/sourcegraph/scip-clang/releases) (x86_64 Linux; needs `compile_commands.json`) | — |
| dart | `lua/dev/scip/indexers/dart.lua` | `dart` (`pub global run scip_dart`) | dart | Active | `dart pub global activate scip_dart` | — |
| dotnet | `lua/dev/scip/indexers/dotnet.lua` | `scip-dotnet` | cs, fsharp, vb | Active | `dotnet tool install --global scip-dotnet` | — |
| go | `lua/dev/scip/indexers/go.lua` | `scip-go` | go, gomod, gosum, gowork | Active | `go install github.com/scip-code/scip-go/cmd/scip-go@latest` | — |
| java | `lua/dev/scip/indexers/java.lua` | `scip-java` | java, kotlin, scala, sbt | Active | `coursier bootstrap --standalone -o scip-java org.scip-code:scip-java:0.13.1 --main org.scip_code.scip_java.ScipJava` (JDK 17+) | — |
| latex | `lua/dev/scip/indexers/latex.lua` | `scip-latex` | bib, latex, plaintex, tex | Provisional¹ | none exists | — |
| lua | `lua/dev/scip/indexers/lua.lua` | `scip-lua` | lua | Provisional¹ | none exists | — |
| nix | `lua/dev/scip/indexers/nix.lua` | `scip-nix` | nix | Provisional¹ | none exists | — |
| php | `lua/dev/scip/indexers/php.lua` | `scip-php`² | php | Active | `composer require --dev davidrjenni/scip-php` | — |
| python | `lua/dev/scip/indexers/python.lua` | `scip-python` (`index .`) | python | Active | `npm install -g @sourcegraph/scip-python` (npm, not pip; Pyright fork) | — |
| ruby | `lua/dev/scip/indexers/ruby.lua` | `scip-ruby` | ruby | Active | prebuilt binary from [scip-ruby releases](https://github.com/sourcegraph/scip-ruby/releases) | — |
| rust | `lua/dev/scip/indexers/rust.lua` | `rust-analyzer` (`scip .`) | rust | Active | `rustup component add rust-analyzer` (SCIP is built into rust-analyzer) | — |
| typescript | `lua/dev/scip/indexers/typescript.lua` | `scip-typescript` | javascript, javascriptreact, typescript, typescriptreact | Active | `npm install -g @sourcegraph/scip-typescript` | — |
| zig | `lua/dev/scip/indexers/zig.lua` | `scip-zig` | zig | Active | `paru -S scip-zig-bin` (AUR; or build [trycog/scip-zig](https://github.com/trycog/scip-zig) from source) | — |

¹ The latex, lua, and nix indexer modules are registered but flagged by
their own module comments as provisional — no verified compatible indexer
executable exists for them yet. (Note: the comments say "disabled", but the
code currently sets `enabled = true`; treat them as provisional.)

² `scip-php` prefers a project-local executable at `<root>/vendor/bin/scip-php`
and falls back to the PATH `scip-php` when absent.

## Install notes

Install commands in the table above were verified 2026-09-29. The three
provisional indexers (latex, lua, nix) have no upstream indexer binary at
all — their modules are registered but cannot run yet. Run `:ScipHealth`
inside Neovim to see which binaries are missing for your languages. Two code-noted exceptions: the dart indexer
assumes the globally installed `scip_dart` package (invoked as
`dart pub global run scip_dart .`), and the php indexer prefers a
Composer-local `vendor/bin/scip-php` over a global one.

## Reference

- SCIP specification and schema:
  https://github.com/sourcegraph/scip
- Sourcegraph code-intelligence docs:
  https://sourcegraph.com/docs/code-search/code-navigation
