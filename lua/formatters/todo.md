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

## Native Neovim implementation

- [ ] Use native Lua and `vim.system()` rather than Conform.nvim or another formatter plugin.
- [ ] Use stdin plus captured stdout only for formatters designed to return formatted text.
- [ ] Use file-writing formatter commands only when their exit status is zero, then reload the buffer while preserving view/cursor state.
- [ ] Do not run destructive `--fix`, `--replace`, autocorrection, import organization, and full-file formatting as an unreviewed combined on-save action.
- [ ] Add a manual format command before enabling `BufWritePre` automation.
- [ ] Make each project root choose its own formatter executable and configuration file.

# Native Uncrustify formatter

This module uses the `FormatterSpec` interface in your supplied
`lua/formatters/init.lua`. It requires no formatter plugin and no changes to
your LSP or linter modules. Your loader already registers
`formatters.uncrustify` and lists it as the second alternative for C and C++.

The accompanying policy explicitly assigns **all 901 options in Uncrustify
0.83.0**. `ignore`, `false`, zero, and empty strings are intentional values.
The catalog is version-specific; it does not claim to cover options added by
future releases. There is no version-discovery subprocess on each format.

## Install

Install the Arch package with a full system upgrade:

```bash
sudo pacman -Syu uncrustify
uncrustify --version
uncrustify --count-options
```

Place the files at these paths, relative to `vim.fn.stdpath('config')`:

| Delivered file | Destination |
| --- | --- |
| `uncrustify.lua` | `lua/formatters/uncrustify.lua` |
| `uncrustify.cfg` | `uncrustify.cfg` |

Normally that directory is `~/.config/nvim`; `NVIM_APPNAME` and XDG settings
are respected by `stdpath`. The executable is explicitly
`/usr/bin/uncrustify`, the Arch package location. Change `COMMAND` in the
module if you deliberately use a different installation.

Your existing formatter setup must already call `require('formatters').setup()`.
If it does, keep that call. Once the module is installed, use:

```vim
:Format uncrustify
:Format! uncrustify
:FormatInfo
:FormatStop
```

The first command is asynchronous; the bang waits within the runner's deadline.
`:FormatLsp` remains available for explicit LSP formatting.

## Choose formatter precedence

Your existing C/C++ chains prefer `clang_format`. To prefer Uncrustify, add
these assignments after loading the runner:

```lua
local formatters = require('formatters')

formatters.formatters_by_ft.c = {
    { 'uncrustify', 'clang_format' },
}
formatters.formatters_by_ft.cpp = {
    { 'uncrustify', 'clang_format' },
}
```

The nested list means â€œfirst available executable.â€ A selected formatter's
failure stops the operation; it does not run the next alternative or fall back
to an LSP. Explicit `:Format uncrustify` selects Uncrustify regardless of order.
Do not use `{ 'uncrustify', 'clang_format' }` as the entire filetype value:
that would run both sequentially.

The module supports these mappings:

| Neovim filetype | Uncrustify language |
| --- | --- |
| `c` | `C` |
| `cpp` | `CPP` |
| `cs` | `CS` |
| `d`, `dlang` | `D` |
| `java` | `JAVA` |
| `objc` | `OC` |
| `objcpp` | `OC+` |
| `pawn` | `PAWN` |
| `vala` | `VALA` |

Use the same nested-list pattern to select it for those other filetypes.
CUDA, OpenCL, GLSL and arbitrary C-like filetypes are not silently mapped to C++.
Uncrustify is not a Lua formatter; the Lua integration follows your Tiger Style
guide, and the policy formats the languages above.

## Explicit execution policy

| Setting | Value or behavior |
| --- | --- |
| Input/output | Current buffer through stdin; formatted text through stdout |
| Accepted exit status | `0`, with signal checks owned by the runner |
| Working directory | Root supplied by the runner using the module's root markers |
| Configuration | Explicit `-c` path; no implicit home/environment config lookup |
| Language | Explicit `-l` from the table above, including unnamed buffers |
| Logging | `-L 1-2`: errors and warnings; no debug dumps |
| Environment overrides | `LANG=C`, `LC_ALL=C`, `TZ=UTC`; other environment inherited |
| Text protocol | LF, UTF-8 output, no output BOM, no single-byte transcoding |
| Input tab width | Current buffer's `tabstop`, explicitly passed with `--set` |
| Output indentation | Policy file controls it: four spaces by default |
| Config selection | Buffer override, then global override, then `stdpath('config')/uncrustify.cfg` |
| Config filesystem check | Nonempty regular-file target, at most 1 MiB; symlinks followed |
| Path bound | 4096 bytes; absolute paths without control characters |
| Input/output bounds | Module: 2 MiB input, 4 MiB output; runner also bounds captured streams |
| Empty output | Rejected for non-whitespace input; whitespace-only input remains unchanged |
| Automatic eligibility | `true`; actual format-on-save remains controlled by the runner |
| File writes by Uncrustify | None requested; no source filenames or output paths passed |
| Extra tooling | No shell, daemon, temporary files, runtime downloads, cache or extra autocmds |

`--replace`, `--no-backup`, `--if-changed`, `--check`, file-list processing,
fragment mode, type files, tracking and debug output are deliberately absent
from formatting argv. These are switches, not boolean settings accepting
`false`. In particular, `--if-changed` would suppress stdout for unchanged input
and violate the runner's replacement-text contract.

The runner owns process cancellation, streaming limits, deadlines, stale-buffer
checks, view preservation, and final buffer edits. Its supplied defaults are
3000 ms for manual formatting, 1500 ms on save, 128 KiB stderr capture,
`format_on_save=false`, `preserve_eol=true`, and `lsp='fallback'`.
Keep those limits in the runner's existing setup call; `FormatterSpec` has no
per-tool timeout or stderr-handler field. The module does not add unsupported
linter fields such as `stdin`, `parser`, `append_fname`, or `ignore_exitcode`.

Variable tab stops are rejected because Uncrustify has one input tab width.
Tab widths outside its supported 1â€“32 range are also rejected. `shiftwidth`
and `expandtab` do not override this policy's output indentation.

## Configuration and style

The policy selects four spaces, attached braces, ordinary operator/comma
spacing, expanded statement lines, and a 100-column wrapping target. Some
language-specific spacing rules deliberately retain the input. A 100-column
target is not a guarantee for indivisible tokens, strings, preserved macros,
or comments.

Token-rewrite options, include/import sorting, comment reflow/conversion,
generated comment templates, and brace insertion/removal are disabled.
Macro bodies and continuation lines are preserved by their explicit settings.
A formatter cannot establish bounds, add correct assertions, prove semantic
equivalence, or enforce the other engineering rules in your Tiger Style guide.

To choose another complete policy explicitly:

```lua
vim.g.uncrustify_config = '/absolute/path/to/uncrustify.cfg'
-- Or set only the current buffer:
vim.b.uncrustify_config = '/absolute/project/path/uncrustify.cfg'
```

An override replaces the policy; it is not layered over the included file.
Use a copy of the complete policy if you want every option to remain explicit.
Relative paths, `false`, and unexpanded `~` are rejected. Project configs are
not searched automatically. Any includes or templates you subsequently enable
in your own policy are interpreted by Uncrustify; the adapter is not a sandbox.

The adapter always overrides `newlines`, `utf8_bom`, `utf8_force`, `utf8_byte`
and `input_tab_size` to satisfy the buffer transport contract. Neovim retains
the buffer's fileformat and BOM metadata; with your runner's `preserve_eol=true`,
its original final-newline setting is preserved too.

## Check changes and tool upgrades

Run configuration checks in a terminal where stderr is visible:

```bash
uncrustify --version
uncrustify --count-options
uncrustify -c ~/.config/nvim/uncrustify.cfg --update-config
```

**Upstream limitation verified on 0.83.0:** an unknown option in a config file
can print a warning and still exit successfully. Your supplied runner captures
stderr but does not display it on successful exits, and its decoder receives
only stdout and context. Consequently, this adapter cannot guarantee that
every invalid user-edited config is rejected. Check stderr after editing the
policy or upgrading; the delivered policy was validated without warnings.

On an upgrade, compare the installed tool's `--show-config` catalog and the
expanded `--update-config` output against the saved policy. Review new options
before adopting their values. Do not assume matching counts alone prove that
the option names and behavior match.

## Validation performed

- Built upstream Uncrustify 0.83.0 and compared all 901 policy names against its
  live catalog; effective values exactly matched every assignment.
- Ran 41 integration checks through your unmodified supplied loader on Neovim
  `v0.13.0-dev-1638+ge7e29d9b6d`.
- Exercised all ten filetype mappings and verified unchanged output on a second
  formatting pass for each fixture.
- Checked unnamed/empty buffers, unsupported filetypes, missing/relative config
  paths, paths containing spaces, tab-width errors, stale asynchronous results,
  and fileformat/BOM/final-newline metadata preservation.
- Checked macro, include-order, comment and UTF-8 string preservation on a C
  fixture; both original and formatted C passed GCC C17 syntax checks with
  `-Wall -Wextra -Werror`.

These checks cover the supplied fixtures and integration contract, not every
construct accepted by each language. LuaLS static type checking was not run.

Sources: [Uncrustify 0.83.0 source and CLI implementation](https://github.com/uncrustify/uncrustify/tree/uncrustify-0.83.0),
[option definitions](https://github.com/uncrustify/uncrustify/blob/uncrustify-0.83.0/src/options.h),
[Arch manual](https://man.archlinux.org/man/uncrustify.1.en).