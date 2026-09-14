# Native Formatter TODO

A plugin-free formatter adoption checklist curated from Conform.nvim's current formatter catalog. Each formatter below is an external CLI or language-toolchain command to invoke directly from native Neovim Lua, LSP formatting, task commands, pre-commit hooks, or CI.

## Rules

- [ ] Select one formatter of record for each file type.
- [ ] Pin every formatter version in a lockfile, toolchain file, package manifest, or CI action.
- [ ] Use formatters in write mode locally and check/diff mode in CI.
- [ ] Keep linting, security scanning, and import organization separate from full-file formatting unless the selected tool intentionally owns both.
- [ ] Do not chain competing full-file formatters on save.

## Core native formatters

### Lua and Neovim

- [ ] Install [StyLua](https://github.com/JohnnyMorganz/StyLua) for Lua, LuaJIT, and Luau.
- [ ] Add a repository `stylua.toml` or `.stylua.toml` where style must be explicit.
- [ ] Use `stylua file.lua` locally.
- [ ] Use `stylua --check .` in CI.

### Shell

- [ ] Install [shfmt](https://github.com/mvdan/sh) for Bash, POSIX shell, and mksh layout formatting.
- [ ] Choose shell dialect flags deliberately, for example `shfmt -ln bash -w script.sh`.
- [ ] Use ShellCheck separately for static analysis; do not treat it as a formatter.
- [ ] Use Shellharden only as an explicit Bash hardening rewrite, not as automatic layout formatting.

### Go

- [ ] Use [gofumpt](https://github.com/mvdan/gofumpt) as the Go formatter of record.
- [ ] Use `gofumpt -w file.go` locally.
- [ ] Use `gofumpt -d .` in CI.
- [ ] Use persistent `gopls` organize-imports code actions for import management.
- [ ] Do not automatically chain goimports and gofumpt on each save.
- [ ] Use `gofmt` instead only when the repository intentionally wants standard toolchain formatting with no gofumpt policy.

### Rust

- [ ] Use rustfmt through `cargo fmt`.
- [ ] Add `rustfmt.toml` only for supported, deliberate formatting policy.
- [ ] Use `cargo fmt` locally.
- [ ] Use `cargo fmt --check` in CI.

### Python

- [ ] Use [Ruff formatter](https://docs.astral.sh/ruff/formatter/) for new Python repositories.
- [ ] Configure Ruff in `pyproject.toml`.
- [ ] Use `ruff format .` locally.
- [ ] Use `ruff format --check .` in CI.
- [ ] Use Black instead only when the repository already standardizes on [Black](https://black.readthedocs.io/).
- [ ] Do not run Black and Ruff formatter automatically on the same files.
- [ ] Treat `blackd` as an optional persistent Black service, not as a separate formatting engine.

### JavaScript, TypeScript, JSON, and web assets

- [ ] Choose [Biome](https://biomejs.dev/formatter/) or [Prettier](https://prettier.io/) as the repository formatter of record.
- [ ] Use Biome for JS, TS, JSON, JSONC, CSS, HTML, GraphQL, and supported web assets when the project already uses `biome.json` or `biome.jsonc`.
- [ ] Use `biome format --write .` locally.
- [ ] Use `biome format .` in CI.
- [ ] Use Prettier for JSON5, Markdown, HTML, CSS, YAML, GraphQL, and plugin-supported languages.
- [ ] Use `prettier --write .` locally.
- [ ] Use `prettier --check .` in CI.
- [ ] Do not run Prettier and Biome automatically over the same files.
- [ ] Treat `prettierd` as an optional persistent Prettier service, not a distinct formatter policy.

### Nix

- [ ] Prefer [nixfmt-rfc-style](https://github.com/NixOS/nixfmt) for new Nix repositories.
- [ ] Use `nixfmt file.nix` locally.
- [ ] Use Alejandra only when the repository already standardizes on [Alejandra](https://github.com/kamadorueda/alejandra).
- [ ] Do not run nixfmt-rfc-style and Alejandra over the same Nix source automatically.

### Elixir and Erlang

- [ ] Use `mix format` for Elixir and configure formatting inputs in `.formatter.exs`.
- [ ] Use `mix format --check-formatted` in CI.
- [ ] Use [erlfmt](https://github.com/WhatsApp/erlfmt) for Erlang.
- [ ] Use `erlfmt -w src/*.erl` locally.
- [ ] Keep Dialyzer/Dialyxir analysis separate from formatting.

### C, C++, Objective-C, and CMake

- [ ] Use [clang-format](https://clang.llvm.org/docs/ClangFormat.html) for C-family source.
- [ ] Commit a `.clang-format` file before enforcing it broadly.
- [ ] Use `clang-format -i file.cpp` locally.
- [ ] Select either [gersemi](https://github.com/BlankSpruce/gersemi) or cmake-format for CMake.
- [ ] Do not run both CMake formatters automatically.

### Terraform, OpenTofu, and HCL

- [ ] Use `terraform fmt -recursive` for Terraform projects.
- [ ] Use `terraform fmt -check -recursive` in CI.
- [ ] Use `tofu fmt -recursive` for OpenTofu projects.
- [ ] Use the formatter corresponding to the tool that owns the project.
- [ ] Use `packer fmt .` for Packer HCL projects.

### Solidity

- [ ] Use `forge fmt` for Foundry-owned Solidity projects.
- [ ] Use Prettier Plugin Solidity only when the repository's formatting policy is already Prettier-based.
- [ ] Do not run forge fmt and Prettier Plugin Solidity automatically on the same contracts.
- [ ] Keep Solhint and Slither separate as lint/security-analysis tools.

### Data and documentation

- [ ] Use [Taplo](https://taplo.tamasfe.dev/) for TOML: `taplo format file.toml`.
- [ ] Use [yamlfmt](https://github.com/google/yamlfmt) or repository-owned Prettier for YAML, but not both.
- [ ] Use [mdformat](https://github.com/executablebooks/mdformat) or repository-owned Prettier for Markdown, but not both.
- [ ] Use `xmllint --format -o file.xml file.xml` for XML reformatting.
- [ ] Use [SQLFluff](https://docs.sqlfluff.com/) where dialect-aware SQL formatting and linting matter.
- [ ] Use [sql-formatter](https://github.com/sql-formatter-org/sql-formatter) only for formatting-focused SQL workflows with a supported dialect.
- [ ] Use hledger-fmt only for hledger journal layout; use `hledger check` separately for accounting validation.

## Additional language choices

- [ ] Assembly: [asmfmt](https://github.com/klauspost/asmfmt) â€” `asmfmt -w file.s`
- [ ] Bazel/Starlark: [buildifier](https://github.com/bazelbuild/buildtools) â€” `buildifier -w BUILD.bazel`
- [ ] Bicep: `bicep format file.bicep`
- [ ] Clojure/EDN: [cljfmt](https://github.com/weavejester/cljfmt) â€” `cljfmt fix`
- [ ] Crystal: `crystal tool format`
- [ ] CUE: `cue fmt ./...`
- [ ] D: [dfmt](https://github.com/dlang-community/dfmt) â€” `dfmt -i source.d`
- [ ] Dart: `dart format .`
- [ ] Elm: [elm-format](https://github.com/avh4/elm-format) â€” `elm-format --yes src/`
- [ ] F#: [Fantomas](https://fsprojects.github.io/fantomas/) â€” `fantomas .`
- [ ] Fish: `fish_indent -w script.fish`
- [ ] Fortran: [fprettify](https://github.com/fortran-lang/fprettify) â€” `fprettify -w source.f90`
- [ ] GDScript: [gdformat](https://github.com/Scony/godot-gdscript-formatter) â€” `gdformat file.gd`
- [ ] Gleam: `gleam format`
- [ ] Haskell: [Fourmolu](https://github.com/fourmolu/fourmolu) â€” `fourmolu --mode inplace file.hs`
- [ ] Java: [google-java-format](https://github.com/google/google-java-format) â€” `google-java-format -i File.java`
- [ ] Jsonnet: `jsonnetfmt -i file.jsonnet`
- [ ] Kotlin: [ktfmt](https://github.com/facebook/ktfmt) â€” `ktfmt --kotlinlang-style -w file.kt`
- [ ] LaTeX: [latexindent](https://github.com/cmhughes/latexindent.pl) â€” `latexindent -w file.tex`
- [ ] Nim: `nimpretty file.nim`
- [ ] OCaml: [ocamlformat](https://github.com/ocaml-ppx/ocamlformat) â€” `ocamlformat --inplace file.ml`
- [ ] Odin: `odinfmt file.odin`
- [ ] PHP: [PHP CS Fixer](https://github.com/PHP-CS-Fixer/PHP-CS-Fixer) â€” `php-cs-fixer fix file.php`
- [ ] Laravel PHP: [Pint](https://laravel.com/docs/pint) â€” `./vendor/bin/pint`
- [ ] Perl: [Perl::Tidy](https://perltidy.sourceforge.net/) â€” `perltidy -b file.pl`
- [ ] R: [styler](https://styler.r-lib.org/) â€” `Rscript -e 'styler::style_dir()'`
- [ ] ReScript: `rescript format -all`
- [ ] Ruby: RuboCop autocorrection or StandardRB; select one policy per repository
- [ ] Scala: [Scalafmt](https://scalameta.org/scalafmt/) â€” `scalafmt`
- [ ] Swift: [swift-format](https://github.com/swiftlang/swift-format) â€” `swift-format format -i file.swift`
- [ ] TypeSpec: `tsp format .`
- [ ] Typst: [typstyle](https://github.com/Enter-tainer/typstyle) â€” `typstyle file.typ`
- [ ] V: `v fmt -w file.v`
- [ ] Verilog/SystemVerilog: [Verible](https://github.com/chipsalliance/verible) â€” `verible-verilog-format --inplace file.sv`
- [ ] Zig: `zig fmt src`

## Native Neovim implementation

- [ ] Use native Lua and `vim.system()` rather than Conform.nvim or another formatter plugin.
- [ ] Use stdin plus captured stdout only for formatters designed to return formatted text.
- [ ] Use file-writing formatter commands only when their exit status is zero, then reload the buffer while preserving view/cursor state.
- [ ] Do not run destructive `--fix`, `--replace`, autocorrection, import organization, and full-file formatting as an unreviewed combined on-save action.
- [ ] Add a manual format command before enabling `BufWritePre` automation.
- [ ] Make each project root choose its own formatter executable and configuration file.