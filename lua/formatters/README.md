<!-- /qompassai/Diver/lua/formatters/README.md -->
<!-- Qompass AI Diver Formatters Docs -->
<!-- Copyright (C) 2026 Qompass AI, All rights reserved -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Formatters

> A formatter is a robot that rewrites messy code in one tidy style —
> this folder holds one tiny recipe per robot, telling Neovim how to run it.

## How it works

- Adapters live in `lua/formatters/*.lua`; each returns a `FormatterSpec`
  table (`cmd`, `args`, `mode`, `root_markers`, `exit_codes`) describing how
  to invoke one formatter binary.
- Adapters are registered by name in `M.module_sources`
  (`lua/formatters/init.lua`) and lazy-loaded on first use; a module that
  fails to load lands in `M.load_errors` and is never offered.
- `M.formatters_by_ft` maps each buffer `filetype` to an ordered list of
  formatter names (or fallback chains). The first entry whose binary is on
  `PATH` (`vim.fn.executable`) wins; missing tools are silently skipped.
- Adapters with `automatic = false` and names in `M.manual_formatters`
  (currently `shellharden`) are excluded from automatic/on-save pipelines and
  run only when named explicitly.
- Install recipes live in `lua/formatters/catalog.lua` (cargo/go/npm/pip/
  gem/composer/dotnet installers targeting
  `~/.local/share/nvim/formatter-toolchains/`, which is prepended to the
  lookup path); `lua/formatters/tools.lua` drives the status-check and
  install UI.

## Inventory (alphabetical)

| Name | Config | Binary | Filetypes | Status | Install | Upstream |
| ---- | ------ | ------ | --------- | ------ | ------- | -------- |
| aiken_fmt | [aiken_fmt](aiken_fmt.lua) | `aiken` | aiken | Registered | → upstream | [source](https://github.com/aniadev/prettier-plugin-aiken/blob/HEAD/README.md) |
| air | [air](air.lua) | `air` | r | Registered | → upstream | [source](https://posit-dev.github.io/air/cli.html) |
| alejandra | [alejandra](alejandra.lua) | `alejandra` | nix | Registered | cargo: alejandra | [source](https://github.com/kamadorueda/alejandra/releases/tag/4.0.0) |
| autopep8 | [autopep8](autopep8.lua) | `autopep8` | python | Registered | pip: autopep8 | [source](https://github.com/hhatto/autopep8/blob/main/README.rst) |
| awkfmt | — | `awkfmt` | awk | Registered (file missing) | → upstream | — |
| bean_format | [bean_format](bean_format.lua) | `bean-format` | beancount | Registered | pip: beancount | [source](https://github.com/beancount/beancount) |
| bibtex-tidy | [bibtex_tidy](bibtex_tidy.lua) | `bibtex-tidy` | bib | Registered | npm: bibtex-tidy | [source](https://github.com/flamingtempura/bibtex-tidy/blob/HEAD/README.md) |
| bibtex-tidy (unregistered duplicate) | [bibtex-tidy](bibtex-tidy.lua) | `node` | — | Not registered (file unused) | → upstream | [source](https://github.com/FlamingTempura/bibtex-tidy) |
| bicep_format | [bicep_format](bicep_format.lua) | `bicep` | bicep | Registered | → upstream | [source](https://github.com/Azure/bicep) |
| biome | [biome](biome.lua) | `biome` | javascript, javascriptreact, json, jsonc, typescript, typescriptreact | Registered | npm: @biomejs/biome | [source](https://next.biomejs.dev/reference/cli/) |
| black | [black](black.lua) | `black` | python | Registered | pip: black | [source](https://github.com/psf/black) |
| blackd | [blackd](blackd.lua) | `curl` | python | Registered | pip: black | [source](https://black.readthedocs.io/en/stable/usage_and_configuration/black_as_a_server.html) |
| brittany | [brittany](brittany.lua) | `brittany` | haskell | Registered | → upstream | [source](https://github.com/lspitzner/brittany/blob/HEAD/README.md) |
| buf_format | [buf_format](buf_format.lua) | `buf` | proto | Registered | → upstream | [source](https://buf.build/docs/format/) |
| buildifier | [buildifier](buildifier.lua) | `buildifier` | bzl, bzlmod, starlark | Registered | go: github.com/bazelbuild/buildtools/buildifier | [source](https://github.com/bazelbuild/buildtools/blob/main/buildifier/README.md) |
| cabal_fmt | [cabal_fmt](cabal_fmt.lua) | `cabal-fmt` | cabal | Registered | → upstream | [source](https://github.com/phadej/cabal-fmt/blob/HEAD/README.md) |
| cl_format | [cl_format](cl_format.lua) | `clfmt` | commonlisp | Registered | → upstream | [source](https://github.com/fosskers/clfmt) |
| clang-format | [clang_format](clang_format.lua) | `clang-format` | c, cpp, cuda, glsl, hlsl, java, objc, objcpp, opencl, proto | Registered | → upstream | [source](https://clang.llvm.org/docs/ClangFormat.html) |
| cljfmt | [cljfmt](cljfmt.lua) | `cljfmt` | clojure | Registered | → upstream | [source](https://github.com/weavejester/cljfmt/blob/HEAD/README.md) |
| cmake_format | [cmake_format](cmake_format.lua) | `cmake-format` | cmake | Registered | pip: cmake-format | [source](https://github.com/cheshirekow/cmake_format) |
| cookstyle | [cookstyle](cookstyle.lua) | `cookstyle` | ruby | Registered | gem: cookstyle | [source](https://github.com/chef/cookstyle) |
| crystal_format | [crystal_format](crystal_format.lua) | `crystal` | crystal | Registered | → upstream | [source](https://crystal-lang.org/reference/1.12/man/crystal/) |
| csharpier | [csharpier](csharpier.lua) | `csharpier` | cs | Registered | dotnet: csharpier | [source](https://csharpier.com/docs/CLI) |
| css-beautify | — | `css-beautify` | — | Registered (inline spec) | npm: js-beautify | — |
| cue_fmt | [cue_fmt](cue_fmt.lua) | `cue` | cue | Registered | go: cuelang.org/go/cmd/cue | [source](https://cuelang.org/docs/reference/command/cue-help-fmt/) |
| d2 | [d2](d2.lua) | `d2` | — | Not registered (file unused) | → upstream | [source](https://github.com/d2lang/d2) |
| dart_format | [dart_format](dart_format.lua) | `dart` | dart | Registered | → upstream | [source](https://github.com/dart-lang/site-www/blob/HEAD/src/content/tools/dart-format.md) |
| deno_fmt | [deno_fmt](deno_fmt.lua) | `deno` | javascript, javascriptreact, typescript, typescriptreact | Registered | → upstream | [source](https://docs.deno.com/runtime/reference/cli/fmt/) |
| dfmt | [dfmt](dfmt.lua) | `dfmt` | d, dlang | Registered | → upstream | [source](https://github.com/dlang-community/dfmt) |
| dhall_format | [dhall_format](dhall_format.lua) | `dhall` | dhall | Registered | → upstream | [source](https://hackage.haskell.org/package/dhall-1.42.2/docs/Dhall-Tutorial.html) |
| dioxus | [dioxus](dioxus.lua) | `dx` | — | Not registered (file unused) | cargo: dioxus-cli | [source](https://github.com/DioxusLabs/dioxus) |
| djlint | [djlint](djlint.lua) | `djlint` | htmldjango, htmljinja, jinja | Registered | pip: djlint | [source](https://github.com/djlint/djlint/blob/HEAD/docs/src/docs/getting-started.md) |
| docstrfmt | [docstrfmt](docstrfmt.lua) | `docstrfmt` | rst | Registered | pip: docstrfmt | [source](https://github.com/lilspazjoekp/docstrfmt/blob/HEAD/README.rst) |
| dprint | [dprint](dprint.lua) | `dprint` | dockerfile | Registered | → upstream | [source](https://github.com/dprint/dprint/blob/HEAD/website/src/cli.md) |
| efmt | [efmt](efmt.lua) | `efmt` | erlang | Registered | cargo: efmt | [source](https://github.com/sile/efmt/blob/HEAD/README.md) |
| elm_format | [elm_format](elm_format.lua) | `elm-format` | elm | Registered | → upstream | [source](https://github.com/avh4/elm-format/issues/560) |
| erb-formatter | [erb_formatter](erb_formatter.lua) | `erb-format` | eruby | Registered | gem: erb-formatter | [source](https://github.com/nebulab/erb-formatter) |
| erlfmt | [erlfmt](erlfmt.lua) | `erlfmt` | erlang | Registered | → upstream | [source](https://github.com/WhatsApp/erlfmt/releases/tag/v0.3.0) |
| fantomas | [fantomas](fantomas.lua) | `fantomas` | fsharp | Registered | dotnet: fantomas | [source](https://github.com/fsprojects/fantomas/blob/HEAD/docs/docs/end-users/UpgradeGuide.md) |
| findent | [findent](findent.lua) | `findent` | fortran | Registered | → upstream | [source](https://pypi.org/project/findent/4.1.3/) |
| fish_indent | [fish_indent](fish_indent.lua) | `fish_indent` | fish | Registered | → upstream | [source](https://fishshell.com/docs/current/cmds/fish_indent.html) |
| fnlfmt | [fnlfmt](fnlfmt.lua) | `fnlfmt` | fennel | Registered | → upstream | [source](https://git.sr.ht/~technomancy/fnlfmt) |
| forge_fmt | [forge_fmt](forge_fmt.lua) | `forge` | solidity | Registered | → upstream | [source](https://github.com/foundry-rs/book/blob/HEAD/src/pages/forge/formatting.mdx) |
| fourmolu | [fourmolu](fourmolu.lua) | `fourmolu` | haskell | Registered | → upstream | [source](https://github.com/fourmolu/fourmolu) |
| fprettify | [fprettify](fprettify.lua) | `fprettify` | fortran | Registered | pip: fprettify | [source](https://github.com/pseewald/fprettify) |
| gdformat | [gdformat](gdformat.lua) | `gdformat` | gdscript | Registered | pip: gdformat | [source](https://github.com/Scony/godot-gdscript-toolkit) |
| gersemi | [gersemi](gersemi.lua) | `gersemi` | — | Not registered (file unused) | → upstream | [source](https://github.com/BlankSpruce/gersemi) |
| gleam_format | [gleam_format](gleam_format.lua) | `gleam` | gleam | Registered | → upstream | [source](https://github.com/gleam-lang/gleam) |
| gofmt | [gofmt](gofmt.lua) | `gofmt` | go | Registered | → upstream | [source](https://manpages.debian.org/unstable/gccgo-go/gofmt.1.en.html) |
| gofumpt | [gofumpt](gofumpt.lua) | `gofumpt` | go | Registered | go: mvdan.cc/gofumpt | [source](https://github.com/mvdan/gofumpt) |
| goimports | [goimports](goimports.lua) | `goimports` | go | Registered | go: golang.org/x/tools/cmd/goimports | [source](https://pkg.go.dev/golang.org/x/tools/cmd/goimports) |
| google-java-format | [google_java_format](google_java_format.lua) | `java` | java | Registered | → upstream | [source](https://github.com/google/google-java-format/releases/tag/v1.36.1) |
| grain_format | [grain_format](grain_format.lua) | `grain` | grain | Registered | → upstream | [source](https://github.com/grain-lang/grain-lang.org/blob/HEAD/src_blog/_posts/Grain-Formatter.md) |
| hclfmt | [hclfmt](hclfmt.lua) | `hclfmt` | hcl | Registered | go: github.com/hashicorp/hcl/cmd/hclfmt | [source](https://pkg.go.dev/github.com/haggishunk/hclfmt) |
| hledger_fmt | [hledger_fmt](hledger_fmt.lua) | `hledger-fmt` | hledger, ledger | Registered | cargo: hledger-fmt | [source](https://github.com/mondeja/hledger-fmt/blob/HEAD/README.md) |
| htmlbeautify | [htmlbeautify](htmlbeautify.lua) | `htmlbeautifier` | eruby | Registered | gem: htmlbeautifier | [source](https://github.com/threedaymonk/htmlbeautifier/blob/HEAD/README.md) |
| janet_format | [janet_format](janet_format.lua) | `janetfmt` | janet | Registered | → upstream | [source](https://github.com/ilanpillemer/janetfmt) |
| jq | [jq](jq.lua) | `jq` | json | Registered | → upstream | [source](https://jqlang.org/manual/) |
| jsonnetfmt | [jsonnetfmt](jsonnetfmt.lua) | `jsonnetfmt` | jsonnet | Registered | go: github.com/google/go-jsonnet/cmd/jsonnetfmt | [source](https://github.com/google/jsonnet) |
| julia_formatter | [julia_formatter](julia_formatter.lua) | `jlfmt` | julia | Registered | → upstream | [source](https://github.com/juliaeditorsupport/juliaformatter.jl/blob/HEAD/docs/src/cli.md) |
| just_fmt | [just_fmt](just_fmt.lua) | `just` | just | Registered | → upstream | [source](https://github.com/casey/just) |
| kcl_fmt | [kcl_fmt](kcl_fmt.lua) | `kcl` | kcl | Registered | → upstream | [source](https://www.kcl-lang.io/docs/next/tools/cli/kcl/fmt) |
| ktfmt | [ktfmt](ktfmt.lua) | `java` | kotlin | Registered | → upstream | [source](https://github.com/facebook/ktfmt) |
| ktlint | [ktlint](ktlint.lua) | `ktlint` | kotlin | Registered | → upstream | [source](https://github.com/pinterest/ktlint/discussions/3149) |
| kulala_fmt | [kulala_fmt](kulala_fmt.lua) | `kulala-fmt` | http | Registered | npm: @mistweaverco/kulala-fmt | [source](https://github.com/mistweaverco/kulala-fmt/blob/HEAD/README.md) |
| latexindent | [latexindent](latexindent.lua) | `latexindent+` | latex, plaintex, tex | Registered | → upstream | [source](https://www.tug.org/texmf/doc/support/latexindent/latexindent.pdf) |
| mago_format | [mago_format](mago_format.lua) | `mago` | php | Registered | → upstream | [source](https://github.com/carthage-software/mago/blob/HEAD/docs/content/en/tools/formatter/command-reference.md) |
| mbake | [mbake](mbake.lua) | `mbake` | make | Registered | pip: mbake | [source](https://github.com/ebodshojaei/bake/blob/HEAD/README.md) |
| mdformat | [mdformat](mdformat.lua) | `mdformat` | markdown | Registered | pip: mdformat | [source](https://pypi.org/project/mdformat/) |
| mh_style | [mh_style](mh_style.lua) | `mh_style` | matlab | Registered | pip: miss_hit | [source](https://github.com/florianschanda/miss_hit) |
| mix_format | [mix_format](mix_format.lua) | `mix` | eelixir, elixir, heex | Registered | → upstream | [source](https://github.com/elixir-lang/elixir/issues/7411) |
| muon_fmt | [muon_fmt](muon_fmt.lua) | `muon` | meson | Registered | → upstream | [source](https://manpages.debian.org/unstable/muon-meson/muon-meson.1.en.html) |
| nginxfmt | [nginxfmt](nginxfmt.lua) | `nginxfmt` | nginx | Registered | pip: nginxfmt | [source](https://github.com/nginxfmt/nginxfmt/blob/HEAD/README.md) |
| nickel_format | [nickel_format](nickel_format.lua) | `nickel` | nickel | Registered | cargo: nickel-lang-cli | [source](https://github.com/nickel-lang/nickel) |
| nimpretty | [nimpretty](nimpretty.lua) | `nimpretty` | nim | Registered | → upstream | [source](https://manpages.debian.org/testing/nim/nimpretty.1.en.html) |
| nixfmt | [nixfmt](nixfmt.lua) | `nixfmt` | nix | Registered | → upstream | [source](https://github.com/NixOS/nixfmt/releases/tag/v1.5.0) |
| nixpkgs_fmt | — | `nixpkgs-fmt` | nix | Registered (file missing) | → upstream | — |
| nomad_fmt | [nomad_fmt](nomad_fmt.lua) | `nomad` | nomad | Registered | → upstream | [source](https://docs.hashicorp.com/nomad/commands/fmt) |
| nufmt | [nufmt](nufmt.lua) | `nufmt` | nushell | Registered | → upstream | [source](https://github.com/nushell/nufmt) |
| ocamlformat | [ocamlformat](ocamlformat.lua) | `ocamlformat` | ocaml, ocamlinterface | Registered | → upstream | [source](https://github.com/ocaml-ppx/ocamlformat) |
| opa_fmt | [opa_fmt](opa_fmt.lua) | `opa` | rego | Registered | → upstream | [source](https://v0-63-0--opa-docs.netlify.app/cli/) |
| ormolu | [ormolu](ormolu.lua) | `ormolu` | haskell | Registered | → upstream | [source](https://github.com/tweag/ormolu/blob/HEAD/README.md) |
| packer_fmt | [packer_fmt](packer_fmt.lua) | `packer` | hcl | Registered | → upstream | [source](https://developer.hashiCorp.com/packer/docs/commands/fmt) |
| panache | [panache](panache.lua) | `panache` | markdown | Registered | cargo: panache | [source](https://github.com/jolars/panache) |
| perltidy | [perltidy](perltidy.lua) | `perltidy` | perl | Registered | → upstream | [source](https://metacpan.org/dist/Perl-Tidy/view/bin/perltidy) |
| pg_format | [pg_format](pg_format.lua) | `pg_format` | sql | Registered | → upstream | [source](https://github.com/darold/pgformatter/releases/tag/v5.11) |
| phpcbf | [phpcbf](phpcbf.lua) | `phpcbf` | php | Registered | composer: squizlabs/php_codesniffer | [source](https://github.com/PHPCSStandards/PHP_CodeSniffer/wiki/Fixing-Errors-Automatically) |
| phpcsfixer | [phpcsfixer](phpcsfixer.lua) | `php-cs-fixer` | php | Registered | → upstream | [source](https://github.com/PHP-CS-Fixer/PHP-CS-Fixer) |
| pint | [pint](pint.lua) | `pint` | php | Registered | composer: laravel/pint | [source](https://github.com/laravel/pint) |
| powershell-formatter | [powershell_formatter](powershell_formatter.lua) | `psfmt` | ps1 | Registered | → upstream | [source](https://github.com/kjanat/powershell-formatter) |
| prettier | [prettier](prettier.lua) | `prettier` | astro, graphql, html, htmlangular, javascript, javascriptreact, json, json5, jsonc, less, liquid, markdown, mdx, scss, solidity, svelte, svg, twig, typescript, typescriptreact, vue, yaml | Registered | npm: prettier | [source](https://github.com/keyz/prettier/blob/HEAD/docs/cli.md) |
| prettierd | [prettierd](prettierd.lua) | `prettierd` | astro, graphql, html, htmlangular, javascript, javascriptreact, json, json5, jsonc, less, markdown, mdx, scss, svelte, svg, typescript, typescriptreact, vue, yaml | Registered | npm: @fsouza/prettierd | [source](https://github.com/fsouza/prettierd) |
| ptop | — | `ptop` | pascal | Registered (file missing) | → upstream | — |
| puppet-lint | [puppet_lint_fix](puppet_lint_fix.lua) | `puppet-lint` | puppet | Registered | gem: puppet-lint | [source](https://github.com/puppetlabs/puppet-lint) |
| purs_tidy | [purs_tidy](purs_tidy.lua) | `purs-tidy` | purescript | Registered | npm: purs-tidy | [source](https://github.com/i-am-the-slime/purescript-tidy) |
| qmlformat | [qmlformat](qmlformat.lua) | `qmlformat` | qml | Registered | → upstream | [source](https://doc.qt.io/qt-6.8/qtqml-tooling-qmlformat.html) |
| raco_fmt | [raco_fmt](raco_fmt.lua) | `raco` | racket | Registered | → upstream | [source](https://docs.racket-lang.org/fmt/index.html) |
| refmt | [refmt](refmt.lua) | `refmt` | reason | Registered | npm: rescript | [source](https://github.com/reasonml/reasonml.github.io/blob/HEAD/docs/refmt.md) |
| rescript_format | [rescript_format](rescript_format.lua) | `rescript` | rescript | Registered | npm: rescript | [source](https://github.com/rescript-lang/rescript/blob/HEAD/CHANGELOG.md) |
| robotidy | [robotidy](robotidy.lua) | `robotidy` | robot | Registered | pip: robotframework-tidy | [source](https://github.com/marketsquare/robotframework-tidy) |
| rubocop | [rubocop](rubocop.lua) | `rubocop` | ruby | Registered | gem: rubocop | [source](https://github.com/rubocop/rubocop) |
| rubyfmt | [rubyfmt](rubyfmt.lua) | `rubyfmt` | ruby | Registered | → upstream | [source](https://github.com/fables-tales/rubyfmt) |
| ruff_format | [ruff_format](ruff_format.lua) | `ruff` | python | Registered | pip: ruff | [source](https://github.com/astral-sh/ruff) |
| rumdl_fmt | [rumdl_fmt](rumdl_fmt.lua) | `rumdl` | markdown | Registered | cargo: rumdl | [source](https://github.com/rvben/rumdl) |
| rustfmt | [rustfmt](rustfmt.lua) | `rustfmt` | rust | Registered | → upstream | [source](https://github.com/rust-lang/rustfmt) |
| scalafmt | [scalafmt](scalafmt.lua) | `scalafmt` | sbt, scala | Registered | → upstream | [source](https://github.com/scalameta/scalafmt) |
| scarb_fmt | — | `scarb` | cairo | Registered (file missing) | → upstream | — |
| schemat | [schemat](schemat.lua) | `schemat` | scheme | Registered | cargo: schemat | [source](https://github.com/raviqqe/schemat) |
| shellharden | [shellharden](shellharden.lua) | `shellharden` | — | Registered (manual-only) | cargo: shellharden | [source](https://github.com/anordal/shellharden) |
| shfmt | [shfmt](shfmt.lua) | `shfmt` | bash, sh | Registered | go: mvdan.cc/sh/v3/cmd/shfmt | [source](https://github.com/mvdan/sh) |
| snakefmt | [snakefmt](snakefmt.lua) | `snakefmt` | snakemake | Registered | pip: snakefmt | [source](https://github.com/snakemake/snakefmt) |
| sql-formatter | — | `sql-formatter` | sql | Registered (inline spec) | npm: sql-formatter | — |
| SQLFluff | [sqlfluff](sqlfluff.lua) | `sqlfluff` | sql | Registered (manual-only) | pip: sqlfluff | [source](https://github.com/sqlfluff/sqlfluff) |
| sqruff | [sqruff](sqruff.lua) | `sqruff` | sql | Registered | cargo: sqruff | [source](https://github.com/quarylabs/sqruff) |
| standardrb | [standardrb](standardrb.lua) | `standardrb` | ruby | Registered | gem: standard | [source](https://github.com/standardrb/standard) |
| styler | [styler](styler.lua) | `Rscript` | r | Registered | → upstream | [source](https://github.com/r-lib/styler) |
| StyLua | [stylua](stylua.lua) | `stylua` | lua, luau | Registered | cargo: stylua | [source](https://github.com/johnnymorganz/stylua) |
| superhtml | [superhtml](superhtml.lua) | `superhtml` | html | Registered | → upstream | [source](https://github.com/kristoff-it/superhtml/blob/HEAD/README.md) |
| swift_format | [swift_format](swift_format.lua) | `swift-format` | swift | Registered | → upstream | [source](https://swiftpackageregistry.com/swiftlang/swift-format) |
| swiftformat | [swiftformat](swiftformat.lua) | `swiftformat` | swift | Registered | → upstream | [source](https://github.com/nicklockwood/swiftformat/blob/HEAD/README.md) |
| taplo | [taplo](taplo.lua) | `taplo` | toml | Registered | cargo: taplo-cli | [source](https://github.com/tamasfe/taplo/issues/704) |
| templ_fmt | [templ_fmt](templ_fmt.lua) | `templ` | templ | Registered | go: github.com/a-h/templ/cmd/templ | [source](https://github.com/a-h/templ/blob/HEAD/docs/docs/09-developer-tools/01-cli.md) |
| terraform_fmt | [terraform_fmt](terraform_fmt.lua) | `terraform` | terraform, terraform-vars | Registered | → upstream | [source](https://developer.hashicorp.com/terraform/cli/v1.10.x/commands/fmt) |
| tex_fmt | [tex_fmt](tex_fmt.lua) | `tex-fmt` | latex, plaintex, tex | Registered | cargo: tex-fmt | [source](https://github.com/wgunderwood/tex-fmt/releases/tag/v0.5.7) |
| tofu_fmt | [tofu_fmt](tofu_fmt.lua) | `tofu` | terraform, terraform-vars | Registered | → upstream | [source](https://opentofu.org/docs/cli/commands/fmt/) |
| tombi | [tombi](tombi.lua) | `tombi` | toml | Registered | cargo: tombi | [source](https://github.com/tombi-toml/tombi/pull/451) |
| twig-cs-fixer | [twig_cs_fixer](twig_cs_fixer.lua) | `twig-cs-fixer` | twig | Registered | composer: vincentlanglet/twig-cs-fixer | [source](https://github.com/vincentlanglet/twig-cs-fixer/blob/HEAD/README.md) |
| typstfmt | [typstfmt](typstfmt.lua) | `typstfmt` | typst | Registered | cargo: typstfmt | [source](https://github.com/astrale-sharp/typstfmt/issues/125) |
| typstyle | [typstyle](typstyle.lua) | `typstyle` | typst | Registered | cargo: typstyle | [source](https://github.com/Enter-tainer/typstyle) |
| uncrustify | [uncrustify](uncrustify.lua) | `uncrustify` | c, cpp | Registered | → upstream | [source](https://github.com/uncrustify/uncrustify/tree/uncrustify-0.83.0) |
| v_fmt | [v_fmt](v_fmt.lua) | `v` | v | Registered | → upstream | [source](https://github.com/vlang/v) |
| verible-verilog-format | [verible_verilog_format](verible_verilog_format.lua) | `verible-verilog-format` | systemverilog, verilog | Registered | → upstream | [source](https://github.com/chipsalliance/verible) |
| vsg | [vsg](vsg.lua) | `vsg` | vhdl | Registered | pip: vsg | [source](https://github.com/jeremiah-c-leary/vhdl-style-guide/issues/1409) |
| wgslfmt | [wgslfmt](wgslfmt.lua) | `node` | wgsl | Registered | npm: @wasm-fmt/wgslfmt | [source](https://github.com/wasm-fmt/wgslfmt) |
| xmlformat | [xmlformat](xmlformat.lua) | `xmlformat` | svg, xml | Registered | pip: xmlformatter | [source](https://github.com/pamoller/xmlformatter/blob/HEAD/README.rst) |
| xmllint | [xmllint](xmllint.lua) | `xmllint` | xml | Registered | → upstream | [source](https://manpages.debian.org/unstable/libxml2-utils/xmllint.1.en.html) |
| yamlfmt | [yamlfmt](yamlfmt.lua) | `yamlfmt` | yaml | Registered | go: github.com/google/yamlfmt/cmd/yamlfmt | [source](https://github.com/google/yamlfmt/blob/HEAD/docs/command-usage.md) |
| yapf | [yapf](yapf.lua) | `yapf` | python | Registered | pip: yapf | [source](https://github.com/google/yapf) |
| zig_fmt | [zig_fmt](zig_fmt.lua) | `zig` | zig | Registered | → upstream | [source](https://ziglang.org/documentation/master/#zig-fmt) |
| zprint | [zprint](zprint.lua) | `zprint` | clojure | Registered | → upstream | [source](https://github.com/kkinnear/zprint/blob/HEAD/doc/using/files.md) |

## Install notes

- Preferred route: diver's own catalog recipes — `cargo install <crate>`,
  `go install <pkg>@latest`, `npm install -g <pkg>`, `pip install <pkg>`,
  `gem install <gem>`, `composer global require <pkg>`,
  `dotnet tool install -g <pkg>` — all targeting
  `~/.local/share/nvim/formatter-toolchains/`.
- On Arch (the primary workstation): `paru -S <pkg>` where the tool ships
  upstream (e.g. `clang` for clang-format; `rustfmt` arrives with rustup).
- `ktfmt` needs the pinned with-dependencies JAR plus the companion
  `KtfmtStdin.java` adapter (see its catalog instructions).
- Where no recipe exists in `catalog.lua`, follow the Upstream link — every
  adapter carries its own `---@source` URL.

## Reference

- [Prettier](https://prettier.io) — opinionated JS/TS/CSS/HTML formatter
- [Biome](https://biomejs.dev) — Rust all-in-one formatter/linter for web projects
- [Black](https://black.readthedocs.io) — uncompromising Python code formatter
- [rustfmt](https://rust-lang.github.io/rustfmt) — official Rust formatter
- [StyLua](https://github.com/JohnnyMorganz/StyLua) — opinionated Lua formatter

