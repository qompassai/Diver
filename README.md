<!----------/qompassai/Diver/README.md ------------------->
<!-- ----------Qompass AI Diver -------------------------->
<!--
Copyright (c) 2026  Qompass AI

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->
<!-------------------------------------------------------->

<h2>Qompass AI Diver</h2>

<h3>Your Blazingly Fast Everything Editor</h3>

![Repository Views](https://komarev.com/ghpvc/?username=qompassai-diver)
![GitHub all releases](https://img.shields.io/github/downloads/qompassai/diver/total?style=flat-square)

<p align="center">
  <a href="https://neovim.io/">
    <img src="https://img.shields.io/badge/Neovim-0.13+-57A143?style=for-the-badge&logo=neovim&logoColor=white" alt="Neovim">
  </a>
  <br>
  <a href="https://www.lua.org/">
    <img src="https://img.shields.io/badge/Lua-5.1%2BLuaJIT-blue?style=flat-square" alt="Lua">
  </a>
  <a href="https://github.com/neovim/neovim/wiki/FAQ">
    <img src="https://img.shields.io/badge/Neovim_Lua_Config-Docs-blue?style=flat-square" alt="Neovim Lua Config Docs">
  </a>
  <a href="https://github.com/topics/neovim-config">
    <img src="https://img.shields.io/badge/Neovim_Configs-Green?style=flat-square" alt="Neovim Config Tutorials">
  </a>
  <br>
  <a href="https://doi.org/10.5281/zenodo.16171391">
    <img src="https://zenodo.org/badge/DOI/10.5281/zenodo.16171391.svg" alt="DOI">
  </a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0"></a>
</p>

<details>
<summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0;"><strong>🧭 Diver Map</strong></summary>
<blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">

```lua
~/.config/nvim
################
├── after
│   ├── ftplugin
│   │   ├── ansible.lua
│   │   ├── bash.lua
│   │   ├── julia.lua
│   │   ├── md.lua
│   │   ├── mojo.lua
│   │   ├── python.lua
│   │   ├── verilog.lua
│   │   └── w3m.lua
│   ├── plugin
│   └── syntax
│       ├── md.lua
│       └── qf.lua
├── ansi
│   ├── apple.sh
│   └── gopher.sh
├── bindings
│   └── go
│       ├── binding.go
│       └── binding_test.go
├── citation.bib
├── CITATION.cff
├── dbx.lua
├── diverflake.nix
├── docs
│   ├── _build
│   ├── conf.py
│   ├── howto.tex
│   ├── index.rst
│   ├── learn-lua
│   │   ├── build
│   │   │   ├── index.html
│   │   │   ├── ldoc.css
│   │   │   ├── modules
│   │   │   │   ├── learn_lua.html
│   │   │   │   ├── learn_tables.html
│   │   │   │   └── learn_vim_api.html
│   │   │   └── topics
│   │   │       ├── 00-introduction.md.html
│   │   │       ├── 01-values-and-types.md.html
│   │   │       ├── 02-variables-and-scope.md.html
│   │   │       ├── 03-tables.md.html
│   │   │       ├── 04-functions.md.html
│   │   │       ├── 05-control-flow.md.html
│   │   │       ├── 06-strings-and-patterns.md.html
│   │   │       ├── 07-modules-and-require.md.html
│   │   │       ├── 08-error-handling.md.html
│   │   │       ├── 09-the-vim-api.md.html
│   │   │       ├── 10-luacats-annotations.md.html
│   │   │       ├── 11-neovim-013-native.md.html
│   │   │       └── 12-putting-it-together.md.html
│   │   ├── config.ld
│   │   ├── guide
│   │   │   ├── 00-introduction.md
│   │   │   ├── 01-values-and-types.md
│   │   │   ├── 02-variables-and-scope.md
│   │   │   ├── 03-tables.md
│   │   │   ├── 04-functions.md
│   │   │   ├── 05-control-flow.md
│   │   │   ├── 06-strings-and-patterns.md
│   │   │   ├── 07-modules-and-require.md
│   │   │   ├── 08-error-handling.md
│   │   │   ├── 09-the-vim-api.md
│   │   │   ├── 10-luacats-annotations.md
│   │   │   ├── 11-neovim-013-native.md
│   │   │   └── 12-putting-it-together.md
│   │   ├── Makefile
│   │   ├── modules
│   │   │   ├── learn_lua.lua
│   │   │   ├── learn_tables.lua
│   │   │   └── learn_vim_api.lua
│   │   └── README.md
│   ├── make.bat
│   ├── Makefile
│   ├── _static
│   └── _templates
├── dsdt.dat
├── fixers
│   ├── alejandra.lua
│   ├── blackd.lua
│   ├── cookstyle.lua
│   ├── css-beautify.lua
│   ├── gofumpt.lua
│   ├── goimports.lua
│   ├── htmlbeautify.lua
│   ├── phpcsfixer.lua
│   ├── shellharden.lua
│   └── sql-formatter.lua
├── flake.lock
├── flake.nix
├── go.mod
├── hyprlua.rockspec
├── ignore.rg
├── init.lua
├── lazy-lock.json
├── LICENSE
├── lsp
│   ├── abaplint_ls.lua
│   ├── ada_ls.lua
│   ├── agda_ls.lua
│   ├── agentscript_ls.lua
│   ├── aiken_ls.lua
│   ├── ai_ls.lua
│   ├── air_ls.lua
│   ├── alloy_ls.lua
│   ├── angular_ls.lua
│   ├── ansible_ls.lua
│   ├── antlers_ls.lua
│   ├── apex_ls.lua
│   ├── arduino_ls.lua
│   ├── asm_ls.lua
│   ├── astgrep_ls.lua
│   ├── astro_ls.lua
│   ├── atlas_ls.lua
│   ├── atopile_ls.lua
│   ├── autohotkey_ls.lua
│   ├── autotoo_ls.lua
│   ├── avalonia_ls.lua
│   ├── awk_ls.lua
│   ├── azurepipelines_ls.lua
│   ├── bacon_ls.lua
│   ├── basedpy_ls.lua
│   ├── bash_ls.lua
│   ├── basics_ls.lua
│   ├── bazelrc_ls.lua
│   ├── beancount_ls.lua
│   ├── bicep_ls.lua
│   ├── biome_ls.lua
│   ├── bitbake_ls.lua
│   ├── b_ls.lua
│   ├── blueprint_ls.lua
│   ├── bq_ls.lua
│   ├── brioche_ls.lua
│   ├── bsc_ls.lua
│   ├── buck2_ls.lua
│   ├── buf_ls.lua
│   ├── bzl_ls.lua
│   ├── c3_ls.lua
│   ├── cairo_ls.lua
│   ├── cds_ls.lua
│   ├── chpl_ls.lua
│   ├── cir_ls.lua
│   ├── clangd_ls.lua
│   ├── clarinet_ls.lua
│   ├── clir_ls.lua
│   ├── clojure_ls.lua
│   ├── cmake_ls.lua
│   ├── cobol_ls.lua
│   ├── codebook_ls.lua
│   ├── codeql_ls.lua
│   ├── contextive_ls.lua
│   ├── copilot_ls.lua
│   ├── coq_ls.lua
│   ├── cql_ls.lua
│   ├── crystalline_ls.lua
│   ├── csharp_ls.lua
│   ├── csskit_ls.lua
│   ├── css_ls.lua
│   ├── cssmodule_ls.lua
│   ├── cssvariable_ls.lua
│   ├── ctags_ls.lua
│   ├── cucumber_ls.lua
│   ├── customelements_ls.lua
│   ├── cypher_ls.lua
│   ├── dafny_ls.lua
│   ├── dart_ls.lua
│   ├── dcm_ls.lua
│   ├── debputy_ls.lua
│   ├── deno_ls.lua
│   ├── dexter_ls.lua
│   ├── dj_ls.lua
│   ├── djt_ls.lua
│   ├── dockercompose_ls.lua
│   ├── docker_ls.lua
│   ├── dockerx_ls.lua
│   ├── dolmen_ls.lua
│   ├── dot_ls.lua
│   ├── dprint_ls.lua
│   ├── dts_ls.lua
│   ├── earthly_ls.lua
│   ├── ecsact_ls.lua
│   ├── efm_ls.lua
│   ├── elixir_ls.lua
│   ├── elm_ls.lua
│   ├── elp_ls.lua
│   ├── ember_ls.lua
│   ├── emmet_ls.lua
│   ├── emmylua_ls.lua
│   ├── erg_ls.lua
│   ├── esbonio_ls.lua
│   ├── eslint_ls.lua
│   ├── facility_ls.lua
│   ├── fennel_ls.lua
│   ├── fish_ls.lua
│   ├── flow_ls.lua
│   ├── flux_ls.lua
│   ├── foam_ls.lua
│   ├── fort_ls.lua
│   ├── fsautocomplete_ls.lua
│   ├── fsharp_ls.lua
│   ├── fstar_ls.lua
│   ├── futhark_ls.lua
│   ├── gdscript_ls.lua
│   ├── gdshader_ls.lua
│   ├── ghactions_ls.lua
│   ├── ghcide_ls.lua
│   ├── ghdl_ls.lua
│   ├── ginko_ls.lua
│   ├── gitlabci_ls.lua
│   ├── gitlabduo_ls.lua
│   ├── glasgow_ls.lua
│   ├── gleam_ls.lua
│   ├── glint_ls.lua
│   ├── glslana_ls.lua
│   ├── gn_ls.lua
│   ├── golangcilint_ls.lua
│   ├── gop_ls.lua
│   ├── grain_ls.lua
│   ├── graphql_ls.lua
│   ├── groovy_ls.lua
│   ├── harper_ls.lua
│   ├── haxe_ls.lua
│   ├── hdlchecker_ls.lua
│   ├── helm_ls.lua
│   ├── herb_ls.lua
│   ├── hhvm_ls.lua
│   ├── hie_ls.lua
│   ├── hlasm_ls.lua
│   ├── h_ls.lua
│   ├── homeassist_ls.lua
│   ├── hoon_ls.lua
│   ├── htmlhint_ls.lua
│   ├── html_ls.lua
│   ├── htmx_ls.lua
│   ├── hydra_ls.lua
│   ├── hypr_ls.lua
│   ├── idris2_ls.lua
│   ├── init.lua
│   ├── ink_ls.lua
│   ├── intelephense_ls.lua
│   ├── isabelle_ls.lua
│   ├── janet_ls.lua
│   ├── java_ls.lua
│   ├── jdt_ls.lua
│   ├── jedi_ls.lua
│   ├── jimmerdto_ls.lua
│   ├── jinja_ls.lua
│   ├── jq_ls.lua
│   ├── jsonld_ls.lua
│   ├── json_ls.lua
│   ├── jsonnet_ls.lua
│   ├── julia_ls.lua
│   ├── just_ls.lua
│   ├── kcl_ls.lua
│   ├── kconfig_ls.lua
│   ├── koka_ls.lua
│   ├── kotlin_ls.lua
│   ├── kulala_ls.lua
│   ├── laravel_ls.lua
│   ├── larkparse_ls.lua
│   ├── lean_ls.lua
│   ├── lelwel_ls.lua
│   ├── lemminx_ls.lua
│   ├── ltex_ls.lua
│   ├── ltexplus_ls.lua
│   ├── lua_ls.lua
│   ├── luau_ls.lua
│   ├── lwc_ls.lua
│   ├── m68k_ls.lua
│   ├── markdownoxide_ls.lua
│   ├── markojs_ls.lua
│   ├── marksman_ls.lua
│   ├── matlab_ls.lua
│   ├── mdxana_ls.lua
│   ├── metals_ls.lua
│   ├── millet_ls.lua
│   ├── mint_ls.lua
│   ├── mlir_ls.lua
│   ├── mlirpdll_ls.lua
│   ├── mm0_ls.lua
│   ├── mojo_ls.lua
│   ├── motoko_ls.lua
│   ├── moveana_ls.lua
│   ├── msbuildptoo_ls.lua
│   ├── muon_ls.lua
│   ├── mutt_ls.lua
│   ├── neocmake_ls.lua
│   ├── nextflow_ls.lua
│   ├── next_ls.lua
│   ├── nginx_ls.lua
│   ├── nickel_ls.lua
│   ├── nil_ls.lua
│   ├── nixd_ls.lua
│   ├── nobl9_ls.lua
│   ├── nomad_ls.lua
│   ├── ntt_ls.lua
│   ├── nu_ls.lua
│   ├── nvim2vsc.sh
│   ├── nx_ls.lua
│   ├── ocaml_ls.lua
│   ├── o_ls.lua
│   ├── omnisharp_ls.lua
│   ├── opencl_ls.lua
│   ├── openscad_ls.lua
│   ├── outdated
│   │   ├── cbfmt_ls.lua
│   │   ├── cc_ls.lua
│   │   ├── cds_ls.lua
│   │   ├── coffeesense_ls.lua
│   │   ├── devsense_ls.lua
│   │   ├── diagnostic_ls.lua
│   │   ├── editorcc_ls.lua
│   │   ├── expert_ls.lua
│   │   ├── gdshader-lsp
│   │   ├── meson_ls.lua
│   │   ├── nginxfmt_ls.lua
│   │   ├── prosemd_ls.lua
│   │   ├── snakeskin_ls.lua
│   │   ├── stylua3p_ls.lua
│   │   ├── turtle_ls.lua
│   │   └── unocss_ls.lua
│   ├── oxlint_ls.lua
│   ├── pact_ls.lua
│   ├── pas_ls.lua
│   ├── pb_ls.lua
│   ├── perl_ls.lua
│   ├── perlnav_ls.lua
│   ├── perlp_ls.lua
│   ├── pest_ls.lua
│   ├── phan_ls.lua
│   ├── phpactor_ls.lua
│   ├── pico8_ls.lua
│   ├── platuml_ls.lua
│   ├── please_ls.lua
│   ├── pli_ls.lua
│   ├── poryscript_ls.lua
│   ├── postgres_ls.lua
│   ├── postgrestoo_ls.lua
│   ├── prisma_ls.lua
│   ├── prolog_ls.lua
│   ├── proto_ls.lua
│   ├── psalm_ls.lua
│   ├── pug_ls.lua
│   ├── puppet_ls.lua
│   ├── purescript_ls.lua
│   ├── pwrshelles_ls.lua
│   ├── pyrefly_ls.lua
│   ├── qlue_ls.lua
│   ├── qml_ls.lua
│   ├── quicklintjs_ls.lua
│   ├── racket_ls.lua
│   ├── rascal_ls.lua
│   ├── README.md
│   ├── rech_ls.lua
│   ├── regal_ls.lua
│   ├── rego_ls.lua
│   ├── remark_ls.lua
│   ├── rescript_ls.lua
│   ├── rnix_ls.lua
│   ├── robotcode_ls.lua
│   ├── robotframework_ls.lua
│   ├── rocq_ls.lua
│   ├── roslyn_ls.lua
│   ├── rpmspec_ls.lua
│   ├── rubocop_ls.lua
│   ├── ruby_ls.lua
│   ├── ruff_ls.lua
│   ├── rumdl_ls.lua
│   ├── rune_ls.lua
│   ├── rustana_ls.lua
│   ├── salt_ls.lua
│   ├── scheme_ls.lua
│   ├── selene3p_ls.lua
│   ├── served_ls.lua
│   ├── shader_ls.lua
│   ├── shopifytheme_ls.lua
│   ├── slangd_ls.lua
│   ├── slint_ls.lua
│   ├── smarty_ls.lua
│   ├── smithy_ls.lua
│   ├── solang_ls.lua
│   ├── solargraph_ls.lua
│   ├── solc_ls.lua
│   ├── solidity_ls.lua
│   ├── solidnomic_ls.lua
│   ├── somesass_ls.lua
│   ├── soql_ls.lua
│   ├── sorbet_ls.lua
│   ├── spyglass_ls.lua
│   ├── sq_ls.lua
│   ├── sqruff_ls.lua
│   ├── standardrb_ls.lua
│   ├── starlark_ls.lua
│   ├── statix_ls.lua
│   ├── steep_ls.lua
│   ├── stimulus_ls.lua
│   ├── stree_ls.lua
│   ├── styleable_ls.lua
│   ├── stylua3p_ls.lua
│   ├── stylua_ls.lua
│   ├── superhtml_ls.lua
│   ├── svelte_ls.lua
│   ├── svlang_ls.lua
│   ├── sv_ls.lua
│   ├── sway_ls.lua
│   ├── sysl_ls.lua
│   ├── systemd_ls.lua
│   ├── tailwindcss_ls.lua
│   ├── taplo_ls.lua
│   ├── tcl_ls.lua
│   ├── templ_ls.lua
│   ├── termux_ls.lua
│   ├── terraform_ls.lua
│   ├── texlab_ls.lua
│   ├── text_ls.lua
│   ├── tflint_Ls.lua
│   ├── themecheck_ls.lua
│   ├── tilt_ls.lua
│   ├── tinymist_ls.lua
│   ├── tofu_ls.lua
│   ├── tombi_ls.lua
│   ├── tsgo_ls.lua
│   ├── ts_ls.lua
│   ├── tsp_ls.lua
│   ├── tsquery_ls.lua
│   ├── ttags_ls.lua
│   ├── turbo_ls.lua
│   ├── tvmffinav_ls.lua
│   ├── twiggy_ls.lua
│   ├── ty_ls.lua
│   ├── typeprof_ls.lua
│   ├── typos_ls.lua
│   ├── uiua_ls.lua
│   ├── ungrammar_ls.lua
│   ├── unison_ls.lua
│   ├── uv_ls.lua
│   ├── vacuum_ls.lua
│   ├── vale_ls.lua
│   ├── vana_ls.lua
│   ├── vectorcode_ls.lua
│   ├── verible_ls.lua
│   ├── veryl_ls.lua
│   ├── vespa_ls.lua
│   ├── vhdl_ls.lua
│   ├── vimdoc_ls.lua
│   ├── vim_ls.lua
│   ├── visualforce_ls.lua
│   ├── vscode
│   │   ├── lsp-export
│   │   │   ├── manifest.source.json
│   │   │   ├── manifest.vscode.json
│   │   │   ├── settings.source.json
│   │   │   └── settings.vscode.json
│   │   └── manifest.json
│   ├── vshtml_ls.lua
│   ├── vts_ls.lua
│   ├── vue_ls.lua
│   ├── wasmlangtoo_ls.lua
│   ├── wc_ls.lua
│   ├── wgslana_ls.lua
│   ├── yaml_ls.lua
│   ├── yang_ls.lua
│   ├── y_ls.lua
│   ├── ziggy_ls.lua
│   ├── ziggyschema_ls.lua
│   ├── zizmor_ls.lua
│   ├── zk_ls.lua
│   ├── z_ls.lua
│   └── zuban_ls.lua
├── lua
│   ├── config
│   │   ├── cicd
│   │   │   ├── ansible.lua
│   │   │   ├── container.lua
│   │   │   ├── json.lua
│   │   │   ├── shell.lua
│   │   │   └── sops.lua
│   │   ├── cloud
│   │   │   ├── containers.lua
│   │   │   └── sshfs.lua
│   │   ├── core
│   │   │   ├── filetype.lua
│   │   │   ├── fixer.lua
│   │   │   ├── flash.lua
│   │   │   ├── init.lua
│   │   │   ├── lint.lua
│   │   │   ├── lsp.lua
│   │   │   ├── parser.lua
│   │   │   ├── qf.lua
│   │   │   ├── schema.lua
│   │   │   ├── tree.lua
│   │   │   └── whichkey.lua
│   │   ├── data
│   │   │   ├── common.lua
│   │   │   ├── csv.lua
│   │   │   ├── mysql.lua
│   │   │   ├── psql.lua
│   │   │   ├── sqlite.lua
│   │   │   └── sql.lua
│   │   ├── edu
│   │   │   └── zotcite.lua
│   │   ├── init.lua
│   │   ├── keymaps.lua
│   │   ├── lang
│   │   │   ├── ada.lua
│   │   │   ├── agda.lua
│   │   │   ├── arduino.lua
│   │   │   ├── bash.lua
│   │   │   ├── c.lua
│   │   │   ├── cmp.lua
│   │   │   ├── cpp.lua
│   │   │   ├── css.lua
│   │   │   ├── d.lua
│   │   │   ├── elixir.lua
│   │   │   ├── go.lua
│   │   │   ├── init.lua
│   │   │   ├── js.lua
│   │   │   ├── julia.lua
│   │   │   ├── kotlin.lua
│   │   │   ├── latex.lua
│   │   │   ├── lua.lua
│   │   │   ├── md.lua
│   │   │   ├── mojo.lua
│   │   │   ├── nix.lua
│   │   │   ├── odin.lua
│   │   │   ├── php.lua
│   │   │   ├── python.lua
│   │   │   ├── ruby.lua
│   │   │   ├── rust.lua
│   │   │   ├── scala.lua
│   │   │   ├── sf.lua
│   │   │   ├── toml.lua
│   │   │   ├── ts.lua
│   │   │   ├── xml.lua
│   │   │   └── zig.lua
│   │   ├── lazy.lua
│   │   ├── nav
│   │   │   ├── align.lua
│   │   │   ├── fzf.lua
│   │   │   ├── neotree.lua
│   │   │   └── nt.lua
│   │   └── ui
│   │       ├── colors.lua
│   │       ├── decor.lua
│   │       ├── float.lua
│   │       ├── icons.lua
│   │       ├── illuminate.lua
│   │       ├── image.lua
│   │       ├── init.lua
│   │       ├── line.lua
│   │       ├── nerd.lua
│   │       ├── padding.lua
│   │       ├── render.lua
│   │       └── themes.lua
│   ├── dap
│   │   └── init.lua
│   ├── linters
│   │   ├── actionlint.lua
│   │   ├── ameba.lua
│   │   ├── ansible_lint.lua
│   │   ├── apkbuild-lint.lua
│   │   ├── bandit.lua
│   │   ├── bashate.lua
│   │   ├── bashlint.lua
│   │   ├── bibclean.lua
│   │   ├── buildifier.lua
│   │   ├── clj-kondo.lua
│   │   ├── cmake-lint.lua
│   │   ├── cookstyle.lua
│   │   ├── cypher-lint.lua
│   │   ├── cython-lint.lua
│   │   ├── deadnix.lua
│   │   ├── desktopval.lua
│   │   ├── eslint_d.lua
│   │   ├── golangcilint.lua
│   │   ├── htmlhint.lua
│   │   ├── init.lua
│   │   ├── joker.lua
│   │   ├── lint-openapi.lua
│   │   ├── llvm-mc.lua
│   │   ├── luac.lua
│   │   ├── mado.lua
│   │   ├── naga.lua
│   │   ├── nvcc.lua
│   │   ├── README.md
│   │   ├── revive.lua
│   │   ├── scarb.lua
│   │   ├── secfixes-check.lua
│   │   ├── shellcheck.lua
│   │   ├── sphinx-lint.lua
│   │   ├── statix.lua
│   │   ├── tflint.lua
│   │   ├── vulture.lua
│   │   ├── yara.lua
│   │   └── zlint.lua
│   ├── mappings
│   │   ├── aimap.lua
│   │   ├── cicdmap.lua
│   │   ├── datamap.lua
│   │   ├── ddxmap.lua
│   │   ├── disable.lua
│   │   ├── genmap.lua
│   │   ├── init.lua
│   │   ├── langmap.lua
│   │   ├── lintmap.lua
│   │   ├── lspmap.lua
│   │   ├── navmap.lua
│   │   └── utilmap.lua
│   ├── plugins
│   │   ├── ai
│   │   ├── cicd
│   │   │   ├── git.lua
│   │   │   └── init.lua
│   │   ├── cloud
│   │   │   ├── distant.lua
│   │   │   ├── fire.lua
│   │   │   ├── init.lua
│   │   │   ├── remote.lua
│   │   │   ├── sshfs.lua
│   │   │   └── websocket.lua
│   │   ├── cloud.lua
│   │   ├── core
│   │   │   └── init.lua
│   │   ├── data
│   │   │   ├── csv.lua
│   │   │   ├── dadbod.lua
│   │   │   ├── init.lua
│   │   │   ├── sqlite.lua
│   │   │   └── toggle.lua
│   │   ├── data.lua
│   │   ├── edu.lua
│   │   ├── init.lua
│   │   ├── lang
│   │   │   └── init.lua
│   │   ├── nav.lua
│   │   └── ui
│   │       ├── bufferline.lua
│   │       ├── css.lua
│   │       ├── icons.lua
│   │       ├── illum.lua
│   │       ├── init.lua
│   │       ├── md.lua
│   │       ├── noice.lua
│   │       └── themes.lua
│   ├── types
│   │   ├── core
│   │   │   ├── autocmds.lua
│   │   │   ├── cmp.lua
│   │   │   ├── fixer.lua
│   │   │   ├── init.lua
│   │   │   ├── lazy.lua
│   │   │   ├── lint.lua
│   │   │   ├── lsp.lua
│   │   │   ├── plugins.lua
│   │   │   ├── quickfix.lua
│   │   │   ├── schema.lua
│   │   │   ├── tree.lua
│   │   │   └── trouble.lua
│   │   ├── init.lua
│   │   ├── lang
│   │   │   ├── c.lua
│   │   │   ├── cmp.lua
│   │   │   ├── cpp.lua
│   │   │   ├── go.lua
│   │   │   ├── init.lua
│   │   │   ├── lua.lua
│   │   │   ├── nix.lua
│   │   │   ├── python.lua
│   │   │   ├── ts.lua
│   │   │   └── zig.lua
│   │   ├── nvim.lua
│   │   ├── ui
│   │   │   ├── colors.lua
│   │   │   ├── html.lua
│   │   │   ├── icons.lua
│   │   │   ├── init.lua
│   │   │   ├── line.lua
│   │   │   └── md.lua
│   │   └── utils
│   │       ├── blue
│   │       │   ├── dap.lua
│   │       │   ├── gpg.lua
│   │       │   └── init.lua
│   │       ├── init.lua
│   │       ├── media
│   │       │   ├── encoder.lua
│   │       │   ├── init.lua
│   │       │   ├── rpc.lua
│   │       │   └── video.lua
│   │       ├── red
│   │       │   ├── init.lua
│   │       │   └── red.lua
│   │       ├── unreal.lua
│   │       ├── vulkan.lua
│   │       └── wp.lua
│   └── utils
│       ├── blue
│       │   ├── base64.lua
│       │   ├── dap.lua
│       │   ├── gpg.lua
│       │   ├── init.lua
│       │   ├── sops.lua
│       │   └── ssh.lua
│       ├── bsp
│       │   ├── cargo.lua
│       │   ├── commands.lua
│       │   └── init.lua
│       ├── ddx.lua
│       ├── dev
│       │   ├── android
│       │   │   ├── actions.lua
│       │   │   ├── commands.lua
│       │   │   ├── config.lua
│       │   │   ├── devices.lua
│       │   │   ├── gradle.lua
│       │   │   ├── init.lua
│       │   │   ├── output.lua
│       │   │   ├── recent.lua
│       │   │   ├── ui.lua
│       │   │   └── util.lua
│       │   ├── init.lua
│       │   └── sf
│       │       ├── agent.lua
│       │       ├── analyzer.lua
│       │       ├── apex.lua
│       │       ├── auth.lua
│       │       ├── autocmds.lua
│       │       ├── cmdutil.lua
│       │       ├── commands.lua
│       │       ├── community.lua
│       │       ├── data.lua
│       │       ├── files.lua
│       │       ├── flow.lua
│       │       ├── init.lua
│       │       ├── limits.lua
│       │       ├── mappings.lua
│       │       ├── org.lua
│       │       ├── package.lua
│       │       ├── picker.lua
│       │       ├── query.lua
│       │       ├── README.md
│       │       ├── schema.lua
│       │       ├── tests.lua
│       │       ├── user.lua
│       │       └── util.lua
│       ├── docs
│       │   ├── bounty.lua
│       │   ├── clipboard.lua
│       │   ├── dictionary
│       │   │   └── words.txt
│       │   ├── docs.lua
│       │   ├── init.lua
│       │   ├── license.lua
│       │   ├── mail.lua
│       │   └── mime.lua
│       ├── init.lua
│       ├── media
│       │   ├── audio.lua
│       │   ├── audio.md
│       │   ├── encoder.lua
│       │   ├── init.lua
│       │   ├── rpc.lua
│       │   └── vulkan.lua
│       ├── options
│       │   ├── buffer.lua
│       │   ├── global.lua
│       │   └── init.lua
│       ├── red
│       │   ├── init.lua
│       │   ├── red.lua
│       │   ├── shark.lua
│       │   └── tomcat.lua
│       └── ux
│           ├── init.lua
│           ├── nb.lua
│           ├── server.lua
│           ├── ui.lua
│           ├── w3m.lua
│           └── websocket.lua
├── manifest
├── markdown.css
├── nvim-pack-lock.json
├── pixi.toml
├── qonfig.yaml
├── queries
│   ├── c
│   │   └── context.scm
│   ├── cpp
│   │   ├── context.scm
│   │   ├── fn-call.scm
│   │   ├── function.scm
│   │   ├── imports.scm
│   │   └── scope.scm
│   ├── elixir
│   │   └── 99-function.scm
│   ├── go
│   │   ├── function.scm
│   │   ├── imports.scm
│   │   └── scope.scm
│   ├── java
│   │   ├── function.scm
│   │   └── imports.scm
│   ├── lua
│   │   ├── fn-call.scm
│   │   └── function.scm
│   ├── mojo
│   │   ├── highlights.scm
│   │   ├── indents.scm
│   │   ├── outline.scm
│   │   └── overrides.scm
│   ├── ruby
│   │   └── function.scm
│   └── tsx
│       └── context.scm
├── README.md
├── renovate.jsonc
├── resources
│   └── head.tex
├── scripts
│   ├── lsp
│   │   ├── cargo.sh
│   │   ├── clir_ls.sh
│   │   ├── go.sh
│   │   ├── idris2.sh
│   │   ├── install_tilt.sh
│   │   ├── jimmer.sh
│   │   ├── js.sh
│   │   ├── mojo.sh
│   │   ├── motoko.sh
│   │   ├── ocaml.sh
│   │   ├── pascal.sh
│   │   ├── py.sh
│   │   ├── ruby.sh
│   │   └── vs.sh
│   ├── lua
│   │   ├── luarocks
│   │   └── schemagen.lua
│   ├── media
│   │   └── render_cs.sh
│   ├── msft
│   │   ├── pwsh.ps1
│   │   └── wcargo.ps1
│   ├── python
│   │   ├── ansible.py
│   │   ├── host.py
│   │   ├── nerd2.py
│   │   ├── nerd.py
│   │   └── stt.py
│   ├── quickstart.sh
│   ├── README.md
│   └── shell
│       ├── api.sh
│       ├── generate
│       └── sf.sh
├── snippets
├── spell
│   └── en.utf-8.add
├── tests
│   ├── lua
│   │   └── websocket.lua
│   └── rust
│       └── rust-ffi.lua
├── undo
├── vim.toml
└── vim.yml

88 directories, 779 files
```

</details>

<details>
<summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0;"><strong>🧭 About Qompass AI</strong></summary>
<blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">

<div align="center">
  <p>Owner<br>
  Former Intelligence Officer<br>
  Educator & Learner<br>
  DeepTech Founder & CEO</p>
</div>

<h3>Publications</h3>
  <p>
    <a href="https://orcid.org/0000-0002-0302-4812">
      <img src="https://img.shields.io/badge/ORCID-0000--0002--0302--4812-green?style=flat-square&logo=orcid" alt="ORCID">
    </a>
    <a href="https://www.researchgate.net/profile/Matt-Porter-7">
      <img src="https://img.shields.io/badge/ResearchGate-Open--Research-blue?style=flat-square&logo=researchgate" alt="ResearchGate">
    </a>
    <a href="https://zenodo.org/communities/qompassai">
      <img src="https://img.shields.io/badge/Zenodo-Publications-blue?style=flat-square&logo=zenodo" alt="Zenodo">
    </a>
  </p>

<h3>Developer Programs</h3>

[![NVIDIA Developer](https://img.shields.io/badge/NVIDIA-Developer_Program-76B900?style=for-the-badge\&logo=nvidia\&logoColor=white)](https://developer.nvidia.com/)
[![Meta Developer](https://img.shields.io/badge/Meta-Developer_Program-0668E1?style=for-the-badge\&logo=meta\&logoColor=white)](https://developers.facebook.com/)
[![HackerOne](https://img.shields.io/badge/-HackerOne-%23494649?style=for-the-badge\&logo=hackerone\&logoColor=white)](https://hackerone.com/phaedrusflow)
[![HuggingFace](https://img.shields.io/badge/HuggingFace-qompass-yellow?style=flat-square\&logo=huggingface)](https://huggingface.co/qompass)
[![Epic Games Developer](https://img.shields.io/badge/Epic_Games-Developer_Program-313131?style=for-the-badge\&logo=epic-games\&logoColor=white)](https://dev.epicgames.com/)

<h3>Professional Profiles</h3>
  <p>
    <a href="https://www.linkedin.com/in/matt-a-porter-103535224/">
      <img src="https://img.shields.io/badge/LinkedIn-Owner-blue?style=flat-square&logo=linkedin" alt="Personal LinkedIn">
    </a>
    <a href="https://www.linkedin.com/company/95058568/">
      <img src="https://img.shields.io/badge/LinkedIn-Qompass--AI-blue?style=flat-square&logo=linkedin" alt="Startup LinkedIn">
    </a>
  </p>

<h3>Social Media</h3>
  <p>
    <a href="https://twitter.com/PhaedrusFlow">
      <img src="https://img.shields.io/badge/Twitter-@PhaedrusFlow-blue?style=flat-square&logo=twitter" alt="X/Twitter">
    </a>
    <a href="https://www.instagram.com/phaedrusflow">
      <img src="https://img.shields.io/badge/Instagram-phaedrusflow-purple?style=flat-square&logo=instagram" alt="Instagram">
    </a>
    <a href="https://www.youtube.com/@qompassai">
      <img src="https://img.shields.io/badge/YouTube-QompassAI-red?style=flat-square&logo=youtube" alt="Qompass AI YouTube">
    </a>
  </p>

</blockquote>
</details>

<details>
<summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #ff6b6b; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0;"><strong>🔥 How Do I Support</strong></summary>
<blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #fff5f5; border-left: 6px solid #ff6b6b; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">

<div align="center">

<table>
<tr>
<th align="center">🏛️ Qompass AI Pre-Seed Funding 2023-2025</th>
<th align="center">🏆 Amount</th>
<th align="center">📅 Date</th>
</tr>
<tr>
<td><a href="https://github.com/qompassai/r4r" title="RJOS/Zimmer Biomet Research Grant Repository">RJOS/Zimmer Biomet Research Grant</a></td>
<td align="center">$30,000</td>
<td align="center">March 2024</td>
</tr>
<tr>
<td><a href="https://github.com/qompassai/PathFinders" title="GitHub Repository">Pathfinders Intern Program</a><br>
<small><a href="https://www.linkedin.com/posts/evergreenbio_bioscience-internships-workforcedevelopment-activity-7253166461416812544-uWUM/" target="_blank">View on LinkedIn</a></small></td>
<td align="center">$2,000</td>
<td align="center">October 2024</td>
</tr>
</table>

<br>
<h4>🤝 How To Support Our Mission</h4>

[![GitHub Sponsors](https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?style=for-the-badge\&logo=github-sponsors\&logoColor=white)](https://github.com/sponsors/phaedrusflow)
[![Patreon](https://img.shields.io/badge/Patreon-Support-F96854?style=for-the-badge\&logo=patreon\&logoColor=white)](https://patreon.com/qompassai)
[![Liberapay](https://img.shields.io/badge/Liberapay-Donate-F6C915?style=for-the-badge\&logo=liberapay\&logoColor=black)](https://liberapay.com/qompassai)
[![Open Collective](https://img.shields.io/badge/Open%20Collective-Support-7FADF2?style=for-the-badge\&logo=opencollective\&logoColor=white)](https://opencollective.com/qompassai)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?style=for-the-badge\&logo=buy-me-a-coffee\&logoColor=black)](https://www.buymeacoffee.com/phaedrusflow)

<details markdown="1">
<summary><strong>🔐 Cryptocurrency Donations</strong></summary>

**Monero (XMR):**

<div align="center">
  <img src="https://raw.githubusercontent.com/qompassai/svg/main/assets/monero-qr.svg" alt="Monero QR Code" width="180">
</div>

<div style="margin: 10px 0;">
    <code>42HGspSFJQ4MjM5ZusAiKZj9JZWhfNgVraKb1eGCsHoC6QJqpo2ERCBZDhhKfByVjECernQ6KeZwFcnq8hVwTTnD8v4PzyH</code>
  </div>

<button onclick="navigator.clipboard.writeText('42HGspSFJQ4MjM5ZusAiKZj9JZWhfNgVraKb1eGCsHoC6QJqpo2ERCBZDhhKfByVjECernQ6KeZwFcnq8hVwTTnD8v4PzyH')" style="padding: 6px 12px; background: #FF6600; color: white; border: none; border-radius: 4px; cursor: pointer;">
    📋 Copy Address
  </button>
<p><i>Funding helps us continue our research at the intersection of AI, healthcare, and education</i></p>

</blockquote>
</details>
</details>

<details id="FAQ">
  <summary><strong>Frequently Asked Questions</strong></summary>

### Q: How do you mitigate against bias?

**TLDR - we do math to make AI ethically useful**

### A: We delineate between mathematical bias (MB) - a fundamental parameter in neural network equations - and algorithmic/social bias (ASB). While MB is optimized during model training through backpropagation, ASB requires careful consideration of data sources, model architecture, and deployment strategies. We implement attention mechanisms for improved input processing and use legal open-source data and secure web-search APIs to help mitigate ASB.

[AAMC AI Guidelines | One way to align AI against ASB](https://www.aamc.org/about-us/mission-areas/medical-education/principles-ai-use)

### AI Math at a glance

## Forward Propagation Algorithm

$$
y = w\_1x\_1 + w\_2x\_2 + ... + w\_nx\_n + b
$$

Where:

* $y$ represents the model output
* $(x\_1, x\_2, ..., x\_n)$ are input features
* $(w\_1, w\_2, ..., w\_n)$ are feature weights
* $b$ is the bias term

### Neural Network Activation

For neural networks, the bias term is incorporated before activation:

$$
z = \sum\_{i=1}^{n} w\_ix\_i + b
$$
$$
a = \sigma(z)
$$

Where:

* $z$ is the weighted sum plus bias
* $a$ is the activation output
* $\sigma$ is the activation function

### Attention Mechanism- aka what makes the Transformer (The "T" in ChatGPT) powerful

* [Attention High level overview video](https://www.youtube.com/watch?v=fjJOgb-E41w)

* [Attention Is All You Need Arxiv Paper](https://arxiv.org/abs/1706.03762)

The Attention mechanism equation is:

$$
Attention(Q, K, V) = softmax(\frac{QK^T}{\sqrt{d\_k}})V
$$

Where:

* $Q$ represents the Query matrix
* $K$ represents the Key matrix
* $V$ represents the Value matrix
* $d\_k$ is the dimension of the key vectors
* $\text{softmax}(\cdot)$ normalizes scores to sum to 1

### Q: Do I have to buy a Linux computer to use this? I don't have time for that!

### A: No. You can run Linux and/or the tools we share alongside your existing operating system:

* Windows users can use Windows Subsystem for Linux [WSL](https://learn.microsoft.com/en-us/windows/wsl/install)
* Mac users can use [Homebrew](https://brew.sh/)
* The code-base instructions were developed with both beginners and advanced users in mind.

### Q: Do you have to get a masters in AI?

### A: Not if you don't want to. To get competent enough to get past ChatGPT dependence at least, you just need a computer and a beginning's mindset. Huggingface is a good place to start.

* [Huggingface](https://docs.google.com/presentation/d/1IkzESdOwdmwvPxIELYJi8--K3EZ98_cL6c5ZcLKSyVg/edit#slide=id.p)

### Q: What makes a "small" AI model?

### A: AI models ~=10 billion(10B) parameters and below. For comparison, OpenAI's GPT4o contains approximately 200B parameters.

</details>


## License

This project is licensed under the [Apache License, Version 2.0](./LICENSE).
