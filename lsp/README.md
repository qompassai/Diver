<!-- /qompassai/Diver/lsp/README.md -->
<!-- Qompass AI Diver LSP Docs -->
<!-- Copyright (C) 2026 Qompass AI, All rights reserved -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# LSP servers

> ELI5: this directory is a recipe book that teaches Neovim how to talk
> to one language server per programming language — which program to launch
> and which files it should handle.

## How it works

- Server configs live in `lsp/` as `*_ls.lua` files. Each returns a
  `vim.lsp.Config` table (`cmd`, `filetypes`, `root_markers`, …).
- `lsp/init.lua` holds a plain `servers` table naming the 227
  enabled servers. Uncommented entries are enabled; `--`-commented entries
  with a trailing reason (`TODO`, `deprecated`, `outdated`, `notusing`, …)
  are disabled by design.
- Nothing starts at editor launch. A one-shot `FileType` autocmd
  (augroup `diver.lsp.lazy_enable`) deletes itself on the first file opened
  and then calls `pcall(vim.lsp.enable, servers)`; Neovim starts clients
  for the filetypes that match, re-firing `FileType` for existing buffers
  so the triggering buffer is covered.
- A config error that eager enabling would raise at startup surfaces in the
  deferred call instead, reported via `vim.notify` as an error.

## Inventory (alphabetical)

| Name | Config | Binary | Filetypes | Status | Install | Upstream |
| ---- | ------ | ------ | --------- | ------ | ------- | -------- |
| ABAPLint | [abaplint_ls](abaplint_ls.lua) | `abaplint` | abap | inactive | → upstream |  |
| Ada | [ada_ls](ada_ls.lua) | `ada_language_server` | ada | active | → upstream |  |
| Agda | [agda_ls](agda_ls.lua) | `als` | agda | inactive | → upstream |  |
| AgentScript | [agentscript_ls](agentscript_ls.lua) | `agentscript-lsp` | agentscript | active | → upstream |  |
| Aiken | [aiken_ls](aiken_ls.lua) | `aiken` | aiken | active | → upstream |  |
| Air | [air_ls](air_ls.lua) | `air` | r | active | → upstream |  |
| Alloy | [alloy_ls](alloy_ls.lua) | `alloy` | alloy | active | → upstream |  |
| Angular | [angular_ls](angular_ls.lua) | `ngserver` | typescript, html, typescriptreact, typescript.tsx, htmlangular | inactive | → upstream |  |
| Ansible | [ansible_ls](ansible_ls.lua) | `ansible-language-server` | yaml.ansible, ansible | active | `pnpm add -g @ansible/ansible-language-server` |  |
| Antlers | [antlers_ls](antlers_ls.lua) | `antlersls` | antlers, html.antlers, antlers.html | inactive | → upstream |  |
| Apex | [apex_ls](apex_ls.lua) | `java (+ apex jar)` | apex | active | → upstream |  |
| Arduino | [arduino_ls](arduino_ls.lua) | `arduino-language-server` | arduino | active | → upstream |  |
| asm-lsp | [asm_ls](asm_ls.lua) | `asm-lsp` | asm, vmasm | active | `cargo install asm-lsp` |  |
| ast-grep | [astgrep_ls](astgrep_ls.lua) | `ast-grep` | bash, c, cpp, csharp, css, elixir, go, haskell, html, java, javascript, javascriptreact, javascript.jsx, json, kotlin, lua, nix, php, python, ruby, rust, scala, solidity, swift, typescript, typescriptreact, typescript.tsx, yaml | active | → upstream |  |
| Astro | [astro_ls](astro_ls.lua) | `astro-ls` | astro | active | `pnpm add -g @astrojs/language-server` | [upstream](https://github.com/withastro/astro/tree/main/packages/language-tools) |
| Atlas | [atlas_ls](atlas_ls.lua) | `atlas` | atlas-* | active | → upstream |  |
| Atopile | [atopile_ls](atopile_ls.lua) | `ato` | ato | active | → upstream |  |
| AutoHotkey | [autohotkey_ls](autohotkey_ls.lua) | `autohotkey_lsp` | autohotkey | unlisted | → upstream |  |
| Autotools | [autotoo_ls](autotoo_ls.lua) | `autotools-language-server` | automake, config, make | active | → upstream |  |
| Avalonia | [avalonia_ls](avalonia_ls.lua) | `avalonia-ls` | axaml, xml, xaml | active | → upstream |  |
| AWK | [awk_ls](awk_ls.lua) | `awk-language-server` | awk | active | `pnpm add -g awk-language-server` |  |
| Azure Pipelines | [azurepipelines_ls](azurepipelines_ls.lua) | `pnpm exec azure-pipelines-language-server` | yaml | inactive | `pnpm add -g azure-pipelines-language-server` | [upstream](https://github.com/microsoft/azure-pipelines-language-server) |
| B | [b_ls](b_ls.lua) | `tcp://127.0.0.1:55555` | b, eventb | active | [→ upstream](https://github.com/hhu-stups/b-language-server) | [upstream](https://github.com/hhu-stups/b-language-server) |
| Bacon | [bacon_ls](bacon_ls.lua) | `bacon-ls` | rust | active | → upstream |  |
| basedpyright | [basedpy_ls](basedpy_ls.lua) | `basedpyright-langserver` | python | active | `pnpm add -g basedpyright` |  |
| Bash | [bash_ls](bash_ls.lua) | `bash-language-server` | bash, sh | active | `pnpm add -g bash-language-server` |  |
| Basics | [basics_ls](basics_ls.lua) | `basics-language-server` | — | unlisted | → upstream |  |
| Bazelrc | [bazelrc_ls](bazelrc_ls.lua) | `bazelrc-lsp` | bazelrc | inactive | [→ upstream](https://github.com/salesforce-misc/bazelrc-lsp) | [upstream](https://github.com/salesforce-misc/bazelrc-lsp) |
| Beancount | [beancount_ls](beancount_ls.lua) | `beancount-language-server` | beancount | active | `cargo install beancount-language-server` |  |
| Bicep | [bicep_ls](bicep_ls.lua) | `dotnet` | bicep, bicep-params | active | → upstream |  |
| BigQuery | [bq_ls](bq_ls.lua) | `bqls` | sql | active | `go install github.com/kitagry/bqls@latest` |  |
| Biome | [biome_ls](biome_ls.lua) | `biome` | astro, cjs, css, graphql, html, javascript, javascriptreact, json, jsonc, markdown, mdx, mjs, spajson, svelte, typescript, typescriptreact, typescript.tsx, vue | active | → upstream |  |
| BitBake | [bitbake_ls](bitbake_ls.lua) | `bitbake-language-server` | bitbake | active | → upstream |  |
| Blueprint | [blueprint_ls](blueprint_ls.lua) | `blueprint-compiler` | blueprint | active | → upstream |  |
| BrighterScript | [bsc_ls](bsc_ls.lua) | `bsc` | brs | active | → upstream |  |
| Brioche | [brioche_ls](brioche_ls.lua) | `brioche` | brioche | active | → upstream |  |
| Buck2 | [buck2_ls](buck2_ls.lua) | `buck2` | bzl | active | → upstream |  |
| Buf | [buf_ls](buf_ls.lua) | `buf` | proto | active | → upstream |  |
| Bzl | [bzl_ls](bzl_ls.lua) | `bzl` | bzl | unlisted | → upstream |  |
| C# | [csharp_ls](csharp_ls.lua) | `csharp-ls` | cs | active | `dotnet tool install -g csharp-ls` |  |
| C3 | [c3_ls](c3_ls.lua) | `c3lsp` | c3, c3i | active | → upstream |  |
| Cairo | [cairo_ls](cairo_ls.lua) | `scarb` | cairo | active | → upstream |  |
| ccls | [cc_ls](cc_ls.lua) | `ccls` | c, cpp, cuda, objc, objcpp | inactive | → upstream |  |
| CDS | [cds_ls](cds_ls.lua) | `cds-lsp` | cds | active | `pnpm add -g @sap/cds-lsp` | [upstream](https://cap.cloud.sap/docs/tools/cds-editors#cds-editor) |
| Chapel | [chpl_ls](chpl_ls.lua) | `chpl-language-server` | chpl | active | [→ upstream](https://github.com/chapel-lang/chapel/tree/main/tools/chpl-language-server) | [upstream](https://github.com/chapel-lang/chapel/tree/main/tools/chpl-language-server) |
| CIR | [cir_ls](cir_ls.lua) | `cir-lsp-server` | cir | inactive (TODO) | → upstream |  |
| clangd | [clangd_ls](clangd_ls.lua) | `clangd` | c, cpp, cuda, objc, objcpp, proto, ptx | active | → upstream |  |
| Clarinet | [clarinet_ls](clarinet_ls.lua) | `clarinet` | clar, clarity | active | → upstream |  |
| clir | [clir_ls](clir_ls.lua) | `cir-lsp-server` | cir | unlisted | → upstream |  |
| Clojure | [clojure_ls](clojure_ls.lua) | `clojure-lsp` | clojure, edn | active | → upstream |  |
| CMake | [cmake_ls](cmake_ls.lua) | `cmake-language-server` | cmake | active | → upstream |  |
| COBOL | [cobol_ls](cobol_ls.lua) | `cobol-language-support` | cobol, COBOL, cpy, cpyb | active | → upstream |  |
| Codebook | [codebook_ls](codebook_ls.lua) | `codebook-lsp` | c, css, gitcommit, go, haskell, html, java, javascript, javascriptreact, lua, markdown, php, python, ruby, rust, toml, text, typescript, typescriptreact, zig | inactive (TODO validate) | → upstream |  |
| CodeQL | [codeql_ls](codeql_ls.lua) | `codeql` | ql | active | [→ upstream](https://github.com/github/codeql) | [upstream](https://github.com/github/codeql) |
| Contextive | [contextive_ls](contextive_ls.lua) | `Contextive.LanguageServer` | — | inactive (TODO add glossary then validate) | → upstream |  |
| Copilot | [copilot_ls](copilot_ls.lua) | `copilot-language-server` | — | inactive (TODO validate) | `pnpm add -g @github/copilot-language-server` |  |
| Coq | [coq_ls](coq_ls.lua) | `coq-lsp` | coq | inactive | → upstream |  |
| CQL | [cql_ls](cql_ls.lua) | `cqlls` | cql, cqlang | unlisted | → upstream |  |
| Crates | [crates_ls](crates_ls.lua) | `crates-lsp` | toml | active | → upstream |  |
| Crystalline | [crystalline_ls](crystalline_ls.lua) | `crystalline` | crystal | active | [→ upstream](https://github.com/elbywan/crystalline) | [upstream](https://github.com/elbywan/crystalline) |
| CSS | [css_ls](css_ls.lua) | `vscode-css-language-server` | css, scss, less | unlisted | `pnpm add -g vscode-langservers-extracted` |  |
| CSS Modules | [cssmodule_ls](cssmodule_ls.lua) | `cssmodules-language-server` | javascript, javascriptreact, typescript, typescriptreact | unlisted | → upstream |  |
| CSS Variables | [cssvariable_ls](cssvariable_ls.lua) | `css-variables-language-server` | css, scss, less | unlisted | → upstream |  |
| CSSKit | [csskit_ls](csskit_ls.lua) | `csskit` | css | inactive | → upstream |  |
| Ctags | [ctags_ls](ctags_ls.lua) | `ctags-lsp` | — | inactive | → upstream |  |
| Cucumber | [cucumber_ls](cucumber_ls.lua) | `cucumber-language-server` | cucumber | active | → upstream |  |
| Custom Elements | [customelements_ls](customelements_ls.lua) | `custom-elements-languageserver` | — | unlisted | → upstream |  |
| Cypher | [cypher_ls](cypher_ls.lua) | `cypher-language-server` | cypher | unlisted | → upstream |  |
| Dafny | [dafny_ls](dafny_ls.lua) | `dafny` | dfy, dafny | active | → upstream |  |
| Dart | [dart_ls](dart_ls.lua) | `dart` | dart | unlisted | → upstream |  |
| DCM | [dcm_ls](dcm_ls.lua) | `dcm` | dart | unlisted | → upstream |  |
| Debputy | [debputy_ls](debputy_ls.lua) | `debputy` | autopkgtest, debcontrol, debcopyright, debchangelog, make, yaml | inactive (TODO validate) | [→ upstream](https://salsa.debian.org/debian/debputy) | [upstream](https://salsa.debian.org/debian/debputy) |
| Deno | [deno_ls](deno_ls.lua) | `deno` | javascript, javascriptreact, jsx, tsx, typescript, typescriptreact | inactive (lsp/linter) | → upstream |  |
| Dexter | [dexter_ls](dexter_ls.lua) | `dexter` | elixir, eelixir, heex | unlisted | → upstream |  |
| diagnostic-languageserver | [diagnosticls_ls](diagnosticls_ls.lua) | `diagnostic-languageserver` | css, email, html, javascript, javascriptreact, json, markdown, python, sh, typescript, typescriptreact, yaml | unlisted | → upstream |  |
| DjLS | [dj_ls](dj_ls.lua) | `djls` | htmldjango, python | active | → upstream |  |
| djlsp | [djt_ls](djt_ls.lua) | `djlsp` | htmldjango | active | → upstream |  |
| Docker | [docker_ls](docker_ls.lua) | `docker-langserver` | dockerfile | active | `pnpm add -g dockerfile-language-server-nodejs` |  |
| Docker Compose | [dockercompose_ls](dockercompose_ls.lua) | `docker-compose-langserver` | yaml.docker-compose | active | → upstream |  |
| docker-language-server | [dockerx_ls](dockerx_ls.lua) | `docker-language-server` | dockerfile, yaml.docker-compose | active | → upstream |  |
| Dolmen | [dolmen_ls](dolmen_ls.lua) | `opam` | cnf, icnf, smt2, tptp, p, zf | active | → upstream |  |
| Dot | [dot_ls](dot_ls.lua) | `dot-language-server` | dot | active | → upstream |  |
| dprint | [dprint_ls](dprint_ls.lua) | `dprint` | javascript, javascriptreact, typescript, typescriptreact, json, jsonc, markdown, python, toml, rust, roslyn, graphql | inactive (TODO validate and finish config) | → upstream |  |
| DTS | [dts_ls](dts_ls.lua) | `dts-lsp` | dts, dtsi, overlay | active | → upstream |  |
| Earthly | [earthly_ls](earthly_ls.lua) | `earthlyls` | earthfile | active | → upstream |  |
| Eclipse JDT | [jdt_ls](jdt_ls.lua) | `jdtls` | java | active | → upstream |  |
| Ecsact | [ecsact_ls](ecsact_ls.lua) | `ecsact_lsp_server` | ecsact | unlisted | → upstream |  |
| EFM | [efm_ls](efm_ls.lua) | `efm-langserver` | alsaconf | unlisted | → upstream |  |
| Elixir | [elixir_ls](elixir_ls.lua) | `elixir-ls` | elixir, heex, elixir, surface | active | → upstream |  |
| Elm | [elm_ls](elm_ls.lua) | `elm-language-server` | elm | active | → upstream |  |
| ELP | [elp_ls](elp_ls.lua) | `elp` | erlang | active | → upstream |  |
| Ember | [ember_ls](ember_ls.lua) | `ember-language-server` | handlebars, javascript, typescript, typescript.glimmer, javascript.glimmer | inactive | → upstream |  |
| Emmet | [emmet_ls](emmet_ls.lua) | `emmet-language-server` | astro, css, eruby, html, htmlangular, htmldjango, javascriptreact, less, pug, sass, scss, svelte, templ, typescriptreact, vue | inactive | `pnpm add -g emmet-ls` |  |
| EmmyLua | [emmylua_ls](emmylua_ls.lua) | `emmylua_ls` | lua, luau | inactive | → upstream |  |
| Erg | [erg_ls](erg_ls.lua) | `erg` | erg | unlisted | → upstream |  |
| Esbonio | [esbonio_ls](esbonio_ls.lua) | `esbonio` | rst, rest, restructuredtext | active | → upstream |  |
| ESLint | [eslint_ls](eslint_ls.lua) | `vscode-eslint-language-server` | javascript, javascriptreact, javascript.jsx, typescript, typescriptreact, typescript.tsx, vue, svelte, astro, htmlangular | unlisted | → upstream |  |
| F# | [fsharp_ls](fsharp_ls.lua) | `dotnet` | fsharp | unlisted | → upstream |  |
| F* | [fstar_ls](fstar_ls.lua) | `fstar` | fstar | active | → upstream |  |
| Facility | [facility_ls](facility_ls.lua) | `dotnet` | fsd | inactive | → upstream |  |
| Fallow | [fallow_ls](fallow_ls.lua) | `fallow-lsp` | javascript, javascriptreact, typescript, typescriptreact | unlisted | → upstream |  |
| Fennel | [fennel_ls](fennel_ls.lua) | `fennel-ls` | fennel | active | → upstream |  |
| Fish | [fish_ls](fish_ls.lua) | `fish-lsp` | fish | active | → upstream |  |
| Flow | [flow_ls](flow_ls.lua) | `npx` | javascript, javascriptreact, javascript.jsx | inactive (TODO) | → upstream |  |
| Flux | [flux_ls](flux_ls.lua) | `flux-lsp` | flux | active | → upstream |  |
| FOAM | [foam_ls](foam_ls.lua) | `foam-ls` | foam, OpenFOAM | active | → upstream |  |
| Fortran | [fort_ls](fort_ls.lua) | `fortls` | fortran, fortran_fixed, fortran_free | active | → upstream |  |
| FsAutoComplete | [fsautocomplete_ls](fsautocomplete_ls.lua) | `fsautocomplete` | fsharp | active | → upstream |  |
| Futhark | [futhark_ls](futhark_ls.lua) | `futhark` | futhark, fut | inactive (TODO install/compile and validate) | → upstream |  |
| GDScript | [gdscript_ls](gdscript_ls.lua) | `tcp://127.0.0.1:6005` | gd, gdscript, gdscript3 | active | → upstream |  |
| GDShader | [gdshader_ls](gdshader_ls.lua) | `gdshader-lsp` | gdshader, gdshaderinc | active | → upstream |  |
| ghcide | [ghcide_ls](ghcide_ls.lua) | `ghcide` | haskell, lhaskell | active | → upstream |  |
| GHDL | [ghdl_ls](ghdl_ls.lua) | `ghdl-ls` | vhdl, vhd | unlisted | → upstream |  |
| Ginkgo | [ginko_ls](ginko_ls.lua) | `ginko_ls` | dts | unlisted | → upstream |  |
| GitHub Actions | [ghactions_ls](ghactions_ls.lua) | `gh-actions-language-server` | yaml | inactive | → upstream |  |
| GitLab CI | [gitlabci_ls](gitlabci_ls.lua) | `gitlab-ci-ls` | yaml.gitlab | inactive (TODO validate) | → upstream |  |
| GitLab Duo | [gitlabduo_ls](gitlabduo_ls.lua) | `npx` | c, cpp, cs, css, go, html, java, javascript, javascriptreact, json, kotlin, lua, php, python, ruby, rust, scala, scss, svelte, swift, typescript, typescriptreact, vue, yaml | inactive (TODO) | → upstream |  |
| Glasgow | [glasgow_ls](glasgow_ls.lua) | `glasgow` | wgsl | active | → upstream |  |
| Gleam | [gleam_ls](gleam_ls.lua) | `gleam` | gleam | active | → upstream |  |
| Glint | [glint_ls](glint_ls.lua) | `glint-language-server` | html.handlebars, handlebars, typescript, typescript.glimmer, javascript, javascript.glimmer | inactive (TODO validate) | → upstream |  |
| glsl_analyzer | [glslana_ls](glslana_ls.lua) | `glsl_analyzer` | comp, glsl, vert, frag, geom, tesc, tese | active | → upstream |  |
| GN | [gn_ls](gn_ls.lua) | `gn-language-server` | gn | active | → upstream |  |
| golangci-lint | [golangcilint_ls](golangcilint_ls.lua) | `golangci-lint-langserver` | go, gomod | active | → upstream |  |
| GoPlus | [gop_ls](gop_ls.lua) | `gopls` | go, gomod, gosum, gotmpl, gowork | active | → upstream |  |
| Grain | [grain_ls](grain_ls.lua) | `grain` | grain | active | [→ upstream](https://github.com/grain-lang/grain) | [upstream](https://github.com/grain-lang/grain) |
| GraphQL | [graphql_ls](graphql_ls.lua) | `graphql-lsp` | graphql, javascriptreact, typescriptreact | active | → upstream |  |
| Groovy | [groovy_ls](groovy_ls.lua) | `java` | groovy | inactive (TODO) | → upstream |  |
| Harper | [harper_ls](harper_ls.lua) | `harper-ls` | asciidoc, c, clojure, cmake, cpp, cs, dart, gitcommit, go, haskell, html, java, javascript, lua, markdown, nix, php, python, ruby, rust, sh, swift, toml, typescript, typescriptreact, typst | inactive | → upstream |  |
| Haskell | [h_ls](h_ls.lua) | `haskell-language-server-wrapper` | haskell, lhaskell, cabal | active | [→ upstream](https://haskell-language-server.readthedocs.io/en/latest/index.html) | [upstream](https://haskell-language-server.readthedocs.io/en/latest/index.html) |
| Haxe | [haxe_ls](haxe_ls.lua) | `node` | haxe | inactive (TODO validate) | → upstream |  |
| hdl-checker | [hdlchecker_ls](hdlchecker_ls.lua) | `hdl_checker` | vhdl, verilog, systemverilog | unlisted | → upstream |  |
| Helm | [helm_ls](helm_ls.lua) | `helm_ls` | helm, yaml.helm-values | active | → upstream |  |
| Herb | [herb_ls](herb_ls.lua) | `herb-language-server` | html, eruby | inactive | → upstream |  |
| HHVM | [hhvm_ls](hhvm_ls.lua) | `hh_client` | php, hack | inactive (TODO compile/install and validate) | [→ upstream](https://github.com/facebook/hhvm) | [upstream](https://github.com/facebook/hhvm) |
| HIE | [hie_ls](hie_ls.lua) | `hie-wrapper` | haskell | unlisted | → upstream |  |
| HLASM | [hlasm_ls](hlasm_ls.lua) | `hlasm_language_server` | hlasm | active | → upstream |  |
| Home Assistant | [homeassist_ls](homeassist_ls.lua) | `vscode-home-assistant` | yaml | inactive (TODO) | → upstream |  |
| Hoon | [hoon_ls](hoon_ls.lua) | `hoon-language-server` | hoon | active | → upstream |  |
| HTML | [html_ls](html_ls.lua) | `vscode-html-language-server` | html, templ | active | `pnpm add -g vscode-langservers-extracted` |  |
| HTMLHint | [htmlhint_ls](htmlhint_ls.lua) | `htmlhint` | html, htm | active | → upstream |  |
| htmx | [htmx_ls](htmx_ls.lua) | `htmx-lsp` | aspnetcorerazor, astro, astro-markdown, blade, clojure, django-html, htmldjango, edge, eelixir, elixir, ejs, erb, eruby, gohtml, gohtmltmpl, haml, handlebars, hbs, html, htmlangular, html-eex, heex, jade, js, leaf, liquid, mixed, mdx, mustache, njk, nunjucks, php, razor, slim, twig, javascript, javascriptreact, reason, rescript, typescript, typescriptreact, vue, svelte, templ | active | → upstream |  |
| Hydra | [hydra_ls](hydra_ls.lua) | `hydra-lsp` | yaml | inactive | → upstream |  |
| hyprls | [hypr_ls](hypr_ls.lua) | `hyprls` | hyprlang, hypr | inactive | → upstream |  |
| Idris 2 | [idris2_ls](idris2_ls.lua) | `idris2-lsp` | idris2, idr, lidr | active | [→ upstream](https://github.com/idris-community/idris2-lsp) | [upstream](https://github.com/idris-community/idris2-lsp) |
| Ink | [ink_ls](ink_ls.lua) | `ink-lsp-server` | rust, ink | active | [→ upstream](https://github.com/ink-analyzer/ink-analyzer/tree/master/crates/lsp-server) | [upstream](https://github.com/ink-analyzer/ink-analyzer/tree/master/crates/lsp-server) |
| Intelephense | [intelephense_ls](intelephense_ls.lua) | `intelephense` | php | active | `pnpm add -g intelephense` |  |
| Isabelle | [isabelle_ls](isabelle_ls.lua) | `isabelle-lsp` | isabelle, isabelle_thy | inactive (TODO) | [→ upstream](https://www.cl.cam.ac.uk/research/hvg/Isabelle/) | [upstream](https://www.cl.cam.ac.uk/research/hvg/Isabelle/) |
| Janet | [janet_ls](janet_ls.lua) | `janet-lsp` | janet | active | → upstream |  |
| Java | [java_ls](java_ls.lua) | `java-language-server` | java | active | → upstream |  |
| Jedi | [jedi_ls](jedi_ls.lua) | `jedi-language-server` | python | inactive (TODO validate) | [→ upstream](https://github.com/pappasam/jedi-language-server) | [upstream](https://github.com/pappasam/jedi-language-server) |
| Jimmer DTO | [jimmerdto_ls](jimmerdto_ls.lua) | `java` | jimmer_dto | active | [→ upstream](https://github.com/Enaium/jimmer-dto-lsp) | [upstream](https://github.com/Enaium/jimmer-dto-lsp) |
| Jinja | [jinja_ls](jinja_ls.lua) | `jinja-lsp` | jinja | active | → upstream |  |
| jq | [jq_ls](jq_ls.lua) | `jq-lsp` | jq | active | → upstream |  |
| JSON | [json_ls](json_ls.lua) | `vscode-json-language-server` | json, jsonc, json5 | active | `pnpm add -g vscode-langservers-extracted` |  |
| JSON-LD | [jsonld_ls](jsonld_ls.lua) | `jsonld-lsp` | jsonld | active | → upstream |  |
| Jsonnet | [jsonnet_ls](jsonnet_ls.lua) | `jsonnet-language-server` | jsonnet, libsonnet | active | → upstream |  |
| Julia | [julia_ls](julia_ls.lua) | `julia` | julia | active | → upstream |  |
| Just | [just_ls](just_ls.lua) | `just-lsp` | just | active | → upstream |  |
| KCL | [kcl_ls](kcl_ls.lua) | `kcl-language-server` | kcl | inactive | → upstream |  |
| Kconfig | [kconfig_ls](kconfig_ls.lua) | `kconfig-language-server` | kconfig | active | [→ upstream](https://github.com/anakin4747/kconfig-language-server) | [upstream](https://github.com/anakin4747/kconfig-language-server) |
| Koka | [koka_ls](koka_ls.lua) | `koka` | koka | inactive (TODO validate) | → upstream |  |
| Kotlin | [kotlin_ls](kotlin_ls.lua) | `kotlin-language-server` | kotlin | active | → upstream |  |
| Kulala | [kulala_ls](kulala_ls.lua) | `kulala-ls` | http | unlisted | → upstream |  |
| Laravel | [laravel_ls](laravel_ls.lua) | `laravel-ls` | php, blade | active | → upstream |  |
| Lark Parser | [larkparse_ls](larkparse_ls.lua) | `python` | lark | active | [→ upstream](https://github.com/dynovaio/lark-parser-language-server) | [upstream](https://github.com/dynovaio/lark-parser-language-server) |
| Lean | [lean_ls](lean_ls.lua) | `lean-language-server` | lean3 | active | → upstream |  |
| Lelwel | [lelwel_ls](lelwel_ls.lua) | `lelwel-ls` | llw | active | [→ upstream](https://github.com/0x2a-42/lelwel) | [upstream](https://github.com/0x2a-42/lelwel) |
| LemMinX | [lemminx_ls](lemminx_ls.lua) | `lemminx` | atom, csproj, rss, svg, xaml, xml, xsd, xsl, xslt | active | → upstream |  |
| lsp-ai | [ai_ls](ai_ls.lua) | `lsp-ai` | — | active | → upstream |  |
| LTeX | [ltex_ls](ltex_ls.lua) | `ltex-ls` | bib, context, gitcommit, html, lualatex, mail, markdown, rmd, org, plaintex, quarto, rnoweb, rst, text, xhtml | inactive | → upstream |  |
| LTeX+ | [ltexplus_ls](ltexplus_ls.lua) | `ltex-ls-plus` | bibtex, context, gitcommit, html, org, lualatex, markdown, plaintex, quarto, mail, mdx, rmd, rnoweb, rst, tex, text, typst, xhtml | active | → upstream |  |
| Lua | [lua_ls](lua_ls.lua) | `lua-language-server` | lua, luau | active | → upstream |  |
| Luau | [luau_ls](luau_ls.lua) | `luau-lsp` | luau | active | → upstream |  |
| LWC | [lwc_ls](lwc_ls.lua) | `lwc-language-server` | javascript, javascriptreact, typescript, typescriptreact, html, xml | active | → upstream |  |
| M68k | [m68k_ls](m68k_ls.lua) | `m68k-lsp-server` | asm68k | active | `pnpm add -g m68k-lsp-server` |  |
| Markdown Oxide | [markdownoxide_ls](markdownoxide_ls.lua) | `markdown-oxide` | markdown | inactive | → upstream |  |
| Marko | [markojs_ls](markojs_ls.lua) | `marko-language-server` | marko | active | → upstream |  |
| Marksman | [marksman_ls](marksman_ls.lua) | `marksman` | markdown, markdown.mdx, markdown.readme | inactive | → upstream |  |
| MATLAB | [matlab_ls](matlab_ls.lua) | `matlab-language-server` | matlab | active | → upstream |  |
| MDX Analyzer | [mdxana_ls](mdxana_ls.lua) | `mdx-language-server` | mdx | active | → upstream |  |
| Metals | [metals_ls](metals_ls.lua) | `metals` | scala | active | → upstream |  |
| Millet | [millet_ls](millet_ls.lua) | `millet` | sml | active | → upstream |  |
| Mint | [mint_ls](mint_ls.lua) | `mint` | mint | active | → upstream |  |
| MLIR | [mlir_ls](mlir_ls.lua) | `mlir-lsp-server` | mlir | active | → upstream |  |
| MLIR PDL | [mlirpdll_ls](mlirpdll_ls.lua) | `mlir-pdll-lsp-server` | pdll | active | → upstream |  |
| MM0 | [mm0_ls](mm0_ls.lua) | `mm0-rs` | metamath-zero | active | → upstream |  |
| Mojo | [mojo_ls](mojo_ls.lua) | `mojo-lsp-server` | mojo | active | → upstream |  |
| Motoko | [motoko_ls](motoko_ls.lua) | `motoko-lsp` | motoko | active | [→ upstream](https://github.com/dfinity/vscode-motoko) | [upstream](https://github.com/dfinity/vscode-motoko) |
| Move Analyzer | [moveana_ls](moveana_ls.lua) | `move-analyzer` | move | unlisted | → upstream |  |
| MSBuild | [msbuildptoo_ls](msbuildptoo_ls.lua) | `dotnet` | msbuild | active | → upstream |  |
| Muon | [muon_ls](muon_ls.lua) | `muon` | meson | active | → upstream |  |
| Mutt | [mutt_ls](mutt_ls.lua) | `mutt-language-server` | muttrc, neomuttrc | active | → upstream |  |
| NeoCMake | [neocmake_ls](neocmake_ls.lua) | `neocmakelsp` | cmake | active | → upstream |  |
| Next LS | [next_ls](next_ls.lua) | `nextls` | elixir, eelixir, heex, surface | inactive | → upstream |  |
| Nextflow | [nextflow_ls](nextflow_ls.lua) | `java` | nextflow | active | → upstream |  |
| NGINX | [nginx_ls](nginx_ls.lua) | `nginx-language-server` | nginx | active | → upstream |  |
| Nickel | [nickel_ls](nickel_ls.lua) | `nls` | ncl, nickel | active | → upstream |  |
| Nil | [nil_ls](nil_ls.lua) | `nil` | nix | active | → upstream |  |
| nixd | [nixd_ls](nixd_ls.lua) | `nixd` | nix | active | → upstream |  |
| Nobl9 | [nobl9_ls](nobl9_ls.lua) | `nobl9-language-server` | yaml | inactive (TODO validate) | → upstream |  |
| Nomad | [nomad_ls](nomad_ls.lua) | `nomad-lsp` | hcl.nomad, nomad | unlisted | → upstream |  |
| Nomic Solidity | [solidnomic_ls](solidnomic_ls.lua) | `nomicfoundation-solidity-language-server` | solidity | active | → upstream |  |
| ntt | [ntt_ls](ntt_ls.lua) | `ntt` | ttcn | active | → upstream |  |
| Nushell | [nu_ls](nu_ls.lua) | `nu` | nu | active | → upstream |  |
| nxls | [nx_ls](nx_ls.lua) | `nxls` | json, jsonc | inactive | → upstream |  |
| OCaml | [ocaml_ls](ocaml_ls.lua) | `ocamllsp` | ocaml, ocamlinterface, ocamllex, reason | active | → upstream |  |
| Odin (OLS) | [o_ls](o_ls.lua) | `ols` | odin | active | → upstream |  |
| OmniSharp | [omnisharp_ls](omnisharp_ls.lua) | `omnisharp` | cs, vb | inactive | → upstream |  |
| OpenCL | [opencl_ls](opencl_ls.lua) | `opencl-language-server` | opencl | active | → upstream |  |
| OpenSCAD | [openscad_ls](openscad_ls.lua) | `openscad-lsp` | openscad | active | → upstream |  |
| OpenTofu | [tofu_ls](tofu_ls.lua) | `tofu-ls` | terraform, opentofu, opentofu-vars | active | → upstream |  |
| Oxlint | [oxlint_ls](oxlint_ls.lua) | `oxlint` | javascript, javascriptreact, javascript.jsx, typescript, typescriptreact, typescript.tsx | active | → upstream |  |
| Pact | [pact_ls](pact_ls.lua) | `pact-lsp` | pact | unlisted | → upstream |  |
| Pascal | [pas_ls](pas_ls.lua) | `pasls` | pascal | active | [→ upstream](https://github.com/genericptr/pascal-language-server) | [upstream](https://github.com/genericptr/pascal-language-server) |
| pbls | [pb_ls](pb_ls.lua) | `pbls` | proto | active | [→ upstream](https://git.sr.ht/~rrc/pbls) | [upstream](https://git.sr.ht/~rrc/pbls) |
| Perl | [perl_ls](perl_ls.lua) | `perl` | perl, pl, pm | active | → upstream |  |
| Perl Navigator | [perlnav_ls](perlnav_ls.lua) | `perlnavigator` | perl, pl, %.pl$, %.pm$, pm | active | → upstream |  |
| Pest | [pest_ls](pest_ls.lua) | `pest-language-server` | pest | active | → upstream |  |
| Phan | [phan_ls](phan_ls.lua) | `phan` | php | active | → upstream |  |
| PHPActor | [phpactor_ls](phpactor_ls.lua) | `phpactor` | blade, php, phps | active | → upstream |  |
| Pico-8 | [pico8_ls](pico8_ls.lua) | `pico8-ls` | pico8, lua | active | → upstream |  |
| PL/I | [pli_ls](pli_ls.lua) | `pli_language_server` | pli | active | [→ upstream](https://github.com/zowe/zowe-pli-language-support) | [upstream](https://github.com/zowe/zowe-pli-language-support) |
| PlantUML | [platuml_ls](platuml_ls.lua) | `plantuml-lsp` | platuml | unlisted | → upstream |  |
| Please | [please_ls](please_ls.lua) | `plz` | bzl | active | → upstream |  |
| PLS | [perlp_ls](perlp_ls.lua) | `pls` | perl | active | → upstream |  |
| Poryscript | [poryscript_ls](poryscript_ls.lua) | `poryscript-pls` | pory | active | [→ upstream](https://github.com/huderlem/poryscript-pls) | [upstream](https://github.com/huderlem/poryscript-pls) |
| Postgres | [postgres_ls](postgres_ls.lua) | `postgres-language-server` | sql, psql | active | → upstream |  |
| PostgREST Tools | [postgrestoo_ls](postgrestoo_ls.lua) | `postgrestools` | sql | unlisted | → upstream |  |
| PowerShell | [pwrshelles_ls](pwrshelles_ls.lua) | `pwsh` | ps1, psm1, psd1 | inactive | → upstream |  |
| Prisma | [prisma_ls](prisma_ls.lua) | `prisma-language-server` | prisma | active | → upstream |  |
| Prolog | [prolog_ls](prolog_ls.lua) | `swipl` | prolog | active | → upstream |  |
| Protocol Buffers | [proto_ls](proto_ls.lua) | `protols` | proto | active | → upstream |  |
| Psalm | [psalm_ls](psalm_ls.lua) | `psalm` | php, phps, blade | active | → upstream |  |
| Pug | [pug_ls](pug_ls.lua) | `pug-lsp` | pug | active | → upstream |  |
| Puppet | [puppet_ls](puppet_ls.lua) | `ruby` | puppet | active | → upstream |  |
| PureScript | [purescript_ls](purescript_ls.lua) | `purescript-language-server` | purescript | unlisted | → upstream |  |
| Pyrefly | [pyrefly_ls](pyrefly_ls.lua) | `pyrefly` | python | active | → upstream |  |
| qlue-ls | [qlue_ls](qlue_ls.lua) | `qlue-ls` | sparql | active | → upstream |  |
| QML | [qml_ls](qml_ls.lua) | `qmlls6` | qml, qmljs | active | → upstream |  |
| quick-lint-js | [quicklintjs_ls](quicklintjs_ls.lua) | `quick-lint-js` | javascript, typescript | unlisted | → upstream |  |
| Racket | [racket_ls](racket_ls.lua) | `racket` | racket, scheme | active | → upstream |  |
| Rascal | [rascal_ls](rascal_ls.lua) | `rascal-lsp` | rascal, rsc | inactive (TODO validate) | → upstream |  |
| Rech | [rech_ls](rech_ls.lua) | `node` | cobol, cbl | inactive (TODO https://github.com/RechInformatica/rech-editor-cobol/tree/master/src/lsp) | → upstream |  |
| Regal | [regal_ls](regal_ls.lua) | `regal` | rego | active | → upstream |  |
| Rego | [rego_ls](rego_ls.lua) | `regols` | rego | active | → upstream |  |
| remark | [remark_ls](remark_ls.lua) | `remark-language-server` | markdown, mdx | inactive | → upstream |  |
| ReScript | [rescript_ls](rescript_ls.lua) | `rescript-language-server` | rescript | active | → upstream |  |
| rnix-lsp | [rnix_ls](rnix_ls.lua) | `rnix-lsp` | nix | unlisted | → upstream |  |
| Robot Framework | [robotframework_ls](robotframework_ls.lua) | `robotframework_ls` | robot | active | → upstream |  |
| RobotCode | [robotcode_ls](robotcode_ls.lua) | `robotcode` | robot, resource | active | → upstream |  |
| Rocq | [rocq_ls](rocq_ls.lua) | `vsrocqtop` | coq | active | [→ upstream](https://github.com/rocq-prover/vsrocq) | [upstream](https://github.com/rocq-prover/vsrocq) |
| Roslyn | [roslyn_ls](roslyn_ls.lua) | `Microsoft.CodeAnalysis.LanguageServer` | cs | active | → upstream |  |
| RPM Spec | [rpmspec_ls](rpmspec_ls.lua) | `rpm_lsp_server` | spec | active | → upstream |  |
| RuboCop | [rubocop_ls](rubocop_ls.lua) | `rubocop` | ruby | active | → upstream |  |
| Ruby | [ruby_ls](ruby_ls.lua) | `ruby-lsp` | eruby, ruby | active | → upstream |  |
| Ruff | [ruff_ls](ruff_ls.lua) | `ruff` | python | active | → upstream |  |
| rumdl | [rumdl_ls](rumdl_ls.lua) | `rumdl` | markdown | inactive (TODO validate) | → upstream |  |
| Rune | [rune_ls](rune_ls.lua) | `rune-languageserver` | rune | active | → upstream |  |
| rust-analyzer | [rustana_ls](rustana_ls.lua) | `rust-analyzer` | rust | active | `rustup component add rust-analyzer` |  |
| Salt | [salt_ls](salt_ls.lua) | `salt_lsp_server` | sls | unlisted | → upstream |  |
| Scheme | [scheme_ls](scheme_ls.lua) | `scheme-langserver` | scheme | unlisted | → upstream |  |
| selene 3P | [selene3p_ls](selene3p_ls.lua) | `selene-3p-language-server` | lua | inactive (TODO) | → upstream |  |
| serve-d | [served_ls](served_ls.lua) | `serve-d` | d, di, dpp | unlisted | → upstream |  |
| shader-language-server | [shader_ls](shader_ls.lua) | `shader-ls` | shaderlab, hlsl, cg | unlisted | → upstream |  |
| Shopify Theme | [shopifytheme_ls](shopifytheme_ls.lua) | `shopify` | liquid | active | → upstream |  |
| slangd | [slangd_ls](slangd_ls.lua) | `slangd` | hlsl, shaderslang | active | → upstream |  |
| Slint | [slint_ls](slint_ls.lua) | `slint-lsp` | slint | active | → upstream |  |
| Smarty | [smarty_ls](smarty_ls.lua) | `smarty-language-server` | smarty | unlisted | → upstream |  |
| Smithy | [smithy_ls](smithy_ls.lua) | `coursier` | smithy | active | → upstream |  |
| Snyk | [snyk_ls](snyk_ls.lua) | `snyk-ls` | apex, apexcode, c, cpp, cs, dart, dockerfile, eelixir, elixir, groovy, java, kotlin, objc, objcpp, php, ruby, rust, scala, swift | unlisted | → upstream |  |
| Solang | [solang_ls](solang_ls.lua) | `solang` | solidity | active | → upstream |  |
| Solargraph | [solargraph_ls](solargraph_ls.lua) | `solargraph` | ruby | active | `gem install solargraph` |  |
| solc | [solc_ls](solc_ls.lua) | `solc` | solidity | active | → upstream |  |
| Solidity | [solidity_ls](solidity_ls.lua) | `solidity-ls` | solidity | active | → upstream |  |
| Some Sass | [somesass_ls](somesass_ls.lua) | `some-sass-language-server` | scss, sass | active | → upstream |  |
| SOQL | [soql_ls](soql_ls.lua) | `soql-language-server` | soql, sosl | unlisted | → upstream |  |
| Sorbet | [sorbet_ls](sorbet_ls.lua) | `srb` | ruby | active | → upstream |  |
| SourceKit | [sourcekit_ls](sourcekit_ls.lua) | `sourcekit-lsp` | c, cpp, objc, objcpp, swift | active | → upstream |  |
| Spyglass | [spyglass_ls](spyglass_ls.lua) | `spyglassmc-language-server` | mcfunction | unlisted | → upstream |  |
| sql-language-server | [sq_ls](sq_ls.lua) | `sql-language-server` | mysql, pgsql, sql | active | → upstream |  |
| sqruff | [sqruff_ls](sqruff_ls.lua) | `sqruff` | sql | active | → upstream |  |
| StandardRB | [standardrb_ls](standardrb_ls.lua) | `standardrb` | ruby | active | → upstream |  |
| Starlark | [starlark_ls](starlark_ls.lua) | `starlark` | star, bzl, BUILD.bazel | active | → upstream |  |
| starpls | [starp_ls](starp_ls.lua) | `starpls` | bzl | inactive | → upstream |  |
| Statix | [statix_ls](statix_ls.lua) | `statix` | nix | active | → upstream |  |
| Steep | [steep_ls](steep_ls.lua) | `steep` | eruby, ruby | active | → upstream |  |
| Stimulus | [stimulus_ls](stimulus_ls.lua) | `stimulus-language-server` | blade, eruby, html, php, ruby | inactive (TODO validate/come back to) | → upstream |  |
| stree | [stree_ls](stree_ls.lua) | `stree` | ruby | inactive | → upstream |  |
| Stylable | [styleable_ls](styleable_ls.lua) | `stylable-ls` | css, styl, stylable | unlisted | → upstream |  |
| StyLua | [stylua_ls](stylua_ls.lua) | `stylua` | lua, luau | active | → upstream |  |
| StyLua 3P | [stylua3p_ls](stylua3p_ls.lua) | `stylua-3p-language-server` | lua | inactive | → upstream |  |
| SuperHTML | [superhtml_ls](superhtml_ls.lua) | `superhtml` | htm, html, shtml | active | → upstream |  |
| Svelte | [svelte_ls](svelte_ls.lua) | `svelteserver` | svelte | active | → upstream |  |
| svlangserver | [svlang_ls](svlang_ls.lua) | `svlangserver` | verilog, systemverilog | unlisted | → upstream |  |
| svls | [sv_ls](sv_ls.lua) | `svls` | verilog, systemverilog | active | → upstream |  |
| Sway | [sway_ls](sway_ls.lua) | `forc-lsp` | sway | inactive (TODO https://github.com/FuelLabs/sway/tree/master/sway-lsp) | → upstream |  |
| Symfony | [symfony_ls](symfony_ls.lua) | `symfony-lsp` | php, twig, yaml, json, xml, javascript, typescript, env | unlisted | → upstream |  |
| Sysl | [sysl_ls](sysl_ls.lua) | `sysl` | sysl | active | → upstream |  |
| systemd | [systemd_ls](systemd_ls.lua) | `systemd-lsp` | systemd | active | → upstream |  |
| Tailwind CSS | [tailwindcss_ls](tailwindcss_ls.lua) | `tailwindcss-language-server` | aspnetcorerazor, astro, astro-markdown, blade, clojure, css, django-html, edge, ejs, eelixir, elixir, erb, eruby, gohtml, gohtmltmpl, haml, handlebars, hbs, heex, html, html-eex, htmlangular, htmldjango, jade, js, leaf, less, liquid, markdown, javascript, javascriptreact, mdx, mixed, mustache, njk, nunjucks, php, postcss, razor, reason, rescript, sass, scss, slim, stylus, sugarss, templ, twig, typescript, typescriptreact, svelte, vue | active | `pnpm add -g @tailwindcss/language-server` |  |
| Taplo | [taplo_ls](taplo_ls.lua) | `taplo` | toml | active | `cargo install taplo-cli --locked --features lsp` |  |
| Tcl | [tcl_ls](tcl_ls.lua) | `tclsp` | tcl, sdc, xdc, upf | active | → upstream |  |
| Templ | [templ_ls](templ_ls.lua) | `templ` | templ | active | → upstream |  |
| Termux | [termux_ls](termux_ls.lua) | `termux-language-server` | ebuild, eclass, termux-build, termux-subpackage, pkgbuild, pkgbuild-install, makepkg-conf, portage-make-conf, portage-color-map, devscripts-conf, zsh-mdd | active | → upstream |  |
| Terraform | [terraform_ls](terraform_ls.lua) | `terraform-ls` | terraform, terraform-vars | unlisted | → upstream |  |
| Texlab | [texlab_ls](texlab_ls.lua) | `texlab` | bib, plaintex, tex | active | → upstream |  |
| textLSP | [text_ls](text_ls.lua) | `textlsp` | text, tex, org | active | → upstream |  |
| TFLint | [tflint_Ls](tflint_Ls.lua) | `tflint` | terraform | inactive | → upstream |  |
| Theme Check | [themecheck_ls](themecheck_ls.lua) | `theme-check-language-server` | liquid | unlisted | → upstream |  |
| Tilt | [tilt_ls](tilt_ls.lua) | `tilt` | tiltfile | active | [→ upstream](https://github.com/tilt-dev/tilt) | [upstream](https://github.com/tilt-dev/tilt) |
| Tinymist | [tinymist_ls](tinymist_ls.lua) | `tinymist` | typst | unlisted | → upstream |  |
| Tombi | [tombi_ls](tombi_ls.lua) | `tombi` | toml | active | `cargo install tombi-cli` |  |
| ts_query_ls | [tsquery_ls](tsquery_ls.lua) | `ts_query_ls` | query | active | → upstream |  |
| tsc | [tsc_ls](tsc_ls.lua) | `tsc` | javascript, javascriptreact, typescript, typescriptreact | unlisted | → upstream |  |
| tsgo | [tsgo_ls](tsgo_ls.lua) | `tsgo` | javascript, javascript.jsx, javascriptreact, typescript, typescriptreact, typescript.tsx | active | → upstream |  |
| ttags | [ttags_ls](ttags_ls.lua) | `ttags` | c, cpp, haskell, javascript, nix, ruby, rust, swift | inactive | → upstream |  |
| Turbo | [turbo_ls](turbo_ls.lua) | `turbo-language-server` | blade, eruby, html, php, ruby | inactive | → upstream |  |
| tvm-ffi-navigator | [tvmffinav_ls](tvmffinav_ls.lua) | `python` | python, cpp | inactive (validate) | → upstream |  |
| Twiggy | [twiggy_ls](twiggy_ls.lua) | `twiggy-language-server` | twig | active | → upstream |  |
| ty | [ty_ls](ty_ls.lua) | `ty` | python | active | → upstream |  |
| TypeProf | [typeprof_ls](typeprof_ls.lua) | `typeprof` | ruby, eruby | active | → upstream |  |
| TypeScript | [ts_ls](ts_ls.lua) | `typescript-language-server` | javascript, javascript.jsx, javascriptreact, typescript, typescript.tsx, typescriptreact | inactive | `pnpm add -g typescript-language-server typescript` |  |
| TypeSpec | [tsp_ls](tsp_ls.lua) | `tsp-server` | typespec | active | → upstream |  |
| typos | [typos_ls](typos_ls.lua) | `typos-lsp` | — | inactive (TODO validate) | → upstream |  |
| Uiua | [uiua_ls](uiua_ls.lua) | `uiua` | uiua | active | [→ upstream](https://github.com/uiua-lang/uiua/) | [upstream](https://github.com/uiua-lang/uiua/) |
| Ungrammar | [ungrammar_ls](ungrammar_ls.lua) | `ungrammar-languageserver` | ungrammar | unlisted | → upstream |  |
| Unison | [unison_ls](unison_ls.lua) | `nc` | unison | active | → upstream |  |
| uvls | [uv_ls](uv_ls.lua) | `uvls` | uvl | inactive ('uv_ls', --doesn't compile) | → upstream |  |
| V Analyzer | [vana_ls](vana_ls.lua) | `v-analyzer` | v, vsh, vv | inactive (TODO: install/validate) | [→ upstream](https://github.com/vlang/v-analyzer) | [upstream](https://github.com/vlang/v-analyzer) |
| Vacuum | [vacuum_ls](vacuum_ls.lua) | `vacuum` | yaml.openapi, json.openapi | active | [→ upstream](https://github.com/daveshanley/vacuum) | [upstream](https://github.com/daveshanley/vacuum) |
| Vale | [vale_ls](vale_ls.lua) | `vale-ls` | asciidoc, markdown, text, tex, rst, html, xml | inactive (TODO validate) | [→ upstream](https://github.com/errata-ai/vale-ls) | [upstream](https://github.com/errata-ai/vale-ls) |
| VectorCode | [vectorcode_ls](vectorcode_ls.lua) | `vectorcode-server` | — | inactive (TODO) | → upstream |  |
| Verible | [verible_ls](verible_ls.lua) | `verible-verilog-ls` | verilog, systemverilog | inactive (TODO: install/validate) | [→ upstream](https://github.com/chipsalliance/verible) | [upstream](https://github.com/chipsalliance/verible) |
| Veridian | [veridian_ls](veridian_ls.lua) | `veridian` | verilog, systemverilog | active | → upstream |  |
| Veryl | [veryl_ls](veryl_ls.lua) | `veryl-ls` | veryl | active | → upstream |  |
| Vespa | [vespa_ls](vespa_ls.lua) | `java` | sd, profile, yql | unlisted | → upstream |  |
| vhdl_ls | [vhdl_ls](vhdl_ls.lua) | `vhdl_ls` | vhd, vhdl | unlisted | → upstream |  |
| Vim | [vim_ls](vim_ls.lua) | `vim-language-server` | vim | active | [→ upstream](https://github.com/iamcco/vim-language-server) | [upstream](https://github.com/iamcco/vim-language-server) |
| vimdoc | [vimdoc_ls](vimdoc_ls.lua) | `vimdoc-language-server` | help | unlisted | `cargo install vimdoc-language-server` |  |
| Visualforce | [visualforce_ls](visualforce_ls.lua) | — | visualforce | inactive (TODO: install/validate) | [→ upstream](https://github.com/forcedotcom/salesforcedx-vscode) | [upstream](https://github.com/forcedotcom/salesforcedx-vscode) |
| vshtml | [vshtml_ls](vshtml_ls.lua) | — | — | unlisted | → upstream |  |
| vtsls | [vts_ls](vts_ls.lua) | `vtsls` | javascript, javascriptreact, javascript.jsx, typescript, typescriptreact, typescript.tsx | inactive (TODO dx) | → upstream |  |
| Vue | [vue_ls](vue_ls.lua) | `vue-language-server` | vue | active | `pnpm add -g @vue/language-server` | [upstream](https://github.com/vuejs/language-tools/tree/master/packages/language-server) |
| WAT | [wasmlangtoo_ls](wasmlangtoo_ls.lua) | `wat_server` | wat | active | → upstream |  |
| wc-language-server | [wc_ls](wc_ls.lua) | `wc-language-server` | astro, css, html, javascript, javascriptreact, less, markdown, mdx, scss, svelte, typescript, typescriptreact, vue | active | [→ upstream](https://github.com/wc-toolkit/wc-language-server) | [upstream](https://github.com/wc-toolkit/wc-language-server) |
| WGSL Analyzer | [wgslana_ls](wgslana_ls.lua) | `wgsl-analyzer` | wgsl | active | → upstream |  |
| YAML | [yaml_ls](yaml_ls.lua) | `yaml-language-server` | yaml, yaml.docker-compose, yaml.gitlab, yaml.helm-values, yml | active | `pnpm add -g yaml-language-server` |  |
| YANG | [yang_ls](yang_ls.lua) | `yang-language-server` | yang | unlisted | → upstream |  |
| yls | [y_ls](y_ls.lua) | `yls` | yara | inactive | → upstream |  |
| yr-ls | [yara_ls](yara_ls.lua) | `yr-ls` | yara | active | → upstream |  |
| Ziggy | [ziggy_ls](ziggy_ls.lua) | `ziggy` | ziggy | active | → upstream |  |
| Ziggy Schema | [ziggyschema_ls](ziggyschema_ls.lua) | `ziggy` | ziggy_schema | unlisted | → upstream |  |
| Zizmor | [zizmor_ls](zizmor_ls.lua) | `zizmor` | yaml | unlisted | → upstream |  |
| zk | [zk_ls](zk_ls.lua) | `zk` | markdown | inactive (TODO install/validate) | [→ upstream](https://github.com/zk-org/zk) | [upstream](https://github.com/zk-org/zk) |
| zls | [z_ls](z_ls.lua) | `zls` | zig, ziggy, zine, zon | active | → upstream |  |
| Zuban | [zuban_ls](zuban_ls.lua) | `zuban` | python | inactive (TODO validate) | [→ upstream](https://docs.zubanls.com/en/latest/usage.html#configuration) | [upstream](https://docs.zubanls.com/en/latest/usage.html#configuration) |

## Install notes

- Most servers install from npm (`pnpm add -g <pkg>`), crates.io
  (`cargo install <crate>`), Go (`go install <module>@latest`), or PyPI
  (`pip install` / `uv tool install`).
- Others ship as standalone binaries (GitHub releases), editor-built tools
  (`rustup component add`, `dotnet tool install -g`, `gem install`), or
  from source.
- Diver expects the server executable on `PATH` (see the Binary column);
  the configs never install anything themselves.
- On Arch (Matt's setup) `paru`/AUR covers several servers; otherwise follow
  the project's documented install, linked in the Upstream column.
- Where no command could be verified against the upstream docs, the Install
  cell points `→ upstream` to the project's own install instructions.

## Reference

- [nvim-lspconfig server configs](https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md)
- [Language Server Protocol spec](https://microsoft.github.io/language-server-protocol/)
- [LSP implementors list](https://microsoft.github.io/language-server-protocol/implementors/servers/)
- [langserver.org](https://langserver.org/)
- [Mason (optional installer)](https://github.com/mason-org/mason.nvim)
