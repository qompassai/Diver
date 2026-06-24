<!----------/qompassai/Diver/README.md ------------------->
<!-- ----------Qompass AI Diver -------------------------->
<!--
Copyright (c) 2026 Matt Qompass AI

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

<h2> Qompass AI Diver </h3>

  <h3> Your Blazingly Fast Everything Editor </h3>

![Repository Views](https://komarev.com/ghpvc/?username=qompassai-diver)
![GitHub all releases](https://img.shields.io/github/downloads/qompassai/diver/total?style=flat-square)

<!-------------------------------------------------------->

<h2>Qompass AI Diver</h2>

<h3>Your Blazingly Fast Everything Editor</h3>

![Repository Views](https://komarev.com/ghpvc/?username=qompassai-diver)
![GitHub all releases](https://img.shields.io/github/downloads/qompassai/diver/total?style=flat-square)

<p align="center">
  <a href="https://neovim.io/">
    <img src="https://img.shields.io/badge/Neovim-0.12+-57A143?style=for-the-badge&logo=neovim&logoColor=white" alt="Neovim">
  </a>
  <br>
  <a href="https://www.lua.org/">
    <img src="https://img.shields.io/badge/Lua-5.1+LuaJIT-blue?style=flat-square" alt="Lua">
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
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0">
  </a>
</p> src="https://zenodo.org/badge/DOI/10.5281/zenodo.16171391.svg" alt="DOI">
  </a>
  <a href="https://www.gnu.org/licenses/agpl-3.0">
    <img src="https://img.shields.io/badge/License-AGPL%20v3-blue.svg" alt="License: AGPL v3">
  </a>
  <a href="./LICENSE-QCDA">
    <img src="https://img.shields.io/badge/license-Q--CDA-lightgrey.svg" alt="License: Q-CDA">
  </a>
</p>

<details>
<summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0;"><strong>🧭 Qompass Diver Map</strong></summary>
<blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">

```lua
~/.config/nvim
################
├── after
├── ansi
│   ├── apple.sh
│   └── gopher.sh
├── citation.bib
├── CITATION.cff
├── dbx.lua
├── diverflake.nix
├── docs
│   ├── _build
│   ├── conf.py
│   ├── howto.tex
│   ├── index.rst
│   ├── make.bat
│   ├── Makefile
│   ├── README.md
│   ├── _static
│   └── _templates
├── dsdt.dat
├── fixers
│   ├── alejandra.lua
│   ├── blackd.lua
│   ├── cookstyle.lua
│   ├── css-beautify.lua
│   ├── cssbeautify.lua
│   ├── gofumpt.lua
│   ├── goimports.lua
│   ├── htmlbeautify.lua
│   ├── phpcsfixer.lua
│   ├── shellharden.lua
│   └── sql-formatter.lua
├── flake.lock
├── flake.nix
├── ftdetect
│   ├── alloy.lua
│   ├── cypher.lua
│   ├── filetype.lua
│   ├── git.lua
│   ├── handlebar.lua
│   ├── schelp.lua
│   ├── supercollider.lua
│   └── tsx.lua
├── ftplugin
│   ├── gleam.lua
│   └── markdown.lua
├── ignore.rg
├── init.lua
├── lazy-lock.json
├── LICENSE-AGPL
├── LICENSE-QCDA
├── linters
│   ├── actionlint.lua
│   ├── alex.lua
│   ├── ameba.lua
│   ├── ansible_lint.lua
│   ├── apkbuild-lint.lua
│   ├── bandit.lua
│   ├── bashate.lua
│   ├── bashlint.lua
│   ├── bash.lua
│   ├── bibclean.lua
│   ├── buildifier.lua
│   ├── clangtidy.lua
│   ├── clj-kondo.lua
│   ├── cmake-lint.lua
│   ├── cookstyle.lua
│   ├── cypher-lint.lua
│   ├── cython-lint.lua
│   ├── deadnix.lua
│   ├── desktopval.lua
│   ├── eslint_d.lua
│   ├── fish.lua
│   ├── golangcilint.lua
│   ├── htmlhint.lua
│   ├── init.lua
│   ├── joker.lua
│   ├── lint-openapi.lua
│   ├── llvm-mc.lua
│   ├── luacheck.lua
│   ├── luac.lua
│   ├── naga.lua
│   ├── nvcc.lua
│   ├── revive.lua
│   ├── scarb.lua
│   ├── secfixes-check.lua
│   ├── shellcheck.lua
│   ├── sphinx-lint.lua
│   ├── statix.lua
│   ├── tflint.lua
│   ├── vulture.lua
│   ├── writegood.lua
│   ├── yara.lua
│   └── zlint.lua
├── lsp
│   ├── ada_ls.lua
│   ├── agda_ls.lua
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
│   ├── clangd_ls.lua
│   ├── clarinet_ls.lua
│   ├── clojure_ls.lua
│   ├── cmake_ls.lua
│   ├── codebook_ls.lua
│   ├── contextive_ls.lua
│   ├── copilot_ls.lua
│   ├── coq_ls.lua
│   ├── crystalline_ls.lua
│   ├── csharp_ls.lua
│   ├── cspell_ls.lua
│   ├── css_ls.lua
│   ├── cssmodule_ls.lua
│   ├── cssvariable_ls.lua
│   ├── cucumber_ls.lua
│   ├── customelements_ls.lua
│   ├── cypher_ls.lua
│   ├── dart_ls.lua
│   ├── deno_ls.lua
│   ├── diagnostic_ls.lua
│   ├── dj_ls.lua
│   ├── djt_ls.lua
│   ├── dockercompose_ls.lua
│   ├── docker_ls.lua
│   ├── dolmen_ls.lua
│   ├── dot_ls.lua
│   ├── dprint_ls.lua
│   ├── dts_ls.lua
│   ├── elixir_ls.lua
│   ├── elm_ls.lua
│   ├── elp_ls.lua
│   ├── ember_ls.lua
│   ├── emmet_ls.lua
│   ├── emmylua_ls.lua
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
│   ├── gdscript_ls.lua
│   ├── gdshader_ls.lua
│   ├── ghactions_ls.lua
│   ├── ghcide_ls.lua
│   ├── ghdl_ls.lua
│   ├── gitlabci_ls.lua
│   ├── glasgow_ls.lua
│   ├── gleam_ls.lua
│   ├── glint_ls.lua
│   ├── glslana_ls.lua
│   ├── golangcilint_ls.lua
│   ├── gop_ls.lua
│   ├── graphql_ls.lua
│   ├── groovy_ls.lua
│   ├── harper_ls.lua
│   ├── haxe_ls.lua
│   ├── helm_ls.lua
│   ├── herb_ls.lua
│   ├── h_ls.lua
│   ├── hoon_ls.lua
│   ├── html_ls.lua
│   ├── htmx_ls.lua
│   ├── hydra_ls.lua
│   ├── hypr_ls.lua
│   ├── init.lua
│   ├── intelephense_ls.lua
│   ├── java_ls.lua
│   ├── jdt_ls.lua
│   ├── jinja_ls.lua
│   ├── jq_ls.lua
│   ├── json_ls.lua
│   ├── jsonnet_ls.lua
│   ├── julia_ls.lua
│   ├── just_ls.lua
│   ├── kotlin_ls.lua
│   ├── kulala_ls.lua
│   ├── laravel_ls.lua
│   ├── lean_ls.lua
│   ├── lemminx_ls.lua
│   ├── ltex_ls.lua
│   ├── ltexplus_ls.lua
│   ├── lua_ls.lua
│   ├── luau_ls.lua
│   ├── lwc_ls.lua
│   ├── m68k_ls.lua
│   ├── makelint_ls.lua
│   ├── markdown_oxide.lua
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
│   ├── moveana_ls.lua
│   ├── msbuildptoo_ls.lua
│   ├── muon_ls.lua
│   ├── mutt_ls.lua
│   ├── neocmake_ls.lua
│   ├── nextflow_ls.lua
│   ├── nginx_ls.lua
│   ├── nickel_ls.lua
│   ├── nil_ls.lua
│   ├── nixd_ls.lua
│   ├── nomad_ls.lua
│   ├── ntt_ls.lua
│   ├── nu_ls.lua
│   ├── nx_ls.lua
│   ├── ocaml_ls.lua
│   ├── o_ls.lua
│   ├── omnisharp_ls.lua
│   ├── opencl_ls.lua
│   ├── openscad_ls.lua
│   ├── oxlint_ls.lua
│   ├── pas_ls.lua
│   ├── pb_ls.lua
│   ├── perl_ls.lua
│   ├── perlnav_ls.lua
│   ├── phan_ls.lua
│   ├── phpactor_ls.lua
│   ├── please_ls.lua
│   ├── p_ls.lua
│   ├── postgres_ls.lua
│   ├── postgrestoo_ls.lua
│   ├── prisma_ls.lua
│   ├── prosemd_ls.lua
│   ├── proto_ls.lua
│   ├── psalm_ls.lua
│   ├── pug_ls.lua
│   ├── puppet_ls.lua
│   ├── purescript_ls.lua
│   ├── pwrshelles_ls.lua
│   ├── pyrefly_ls.lua
│   ├── qml_ls.lua
│   ├── quicklintjs_ls.lua
│   ├── README.md
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
│   ├── rune_ls.lua
│   ├── rustana_ls.lua
│   ├── selene3p_ls.lua
│   ├── selene_ls.lua
│   ├── served_ls.lua
│   ├── slangd_ls.lua
│   ├── slint_ls.lua
│   ├── smarty_ls.lua
│   ├── smithy_ls.lua
│   ├── snakeskin_ls.lua
│   ├── solang_ls.lua
│   ├── solargraph_ls.lua
│   ├── solc_ls.lua
│   ├── solidity_ls.lua
│   ├── solidnomic_ls.lua
│   ├── somesass_ls.lua
│   ├── sorbet_ls.lua
│   ├── spectral_ls.lua
│   ├── spyglass_ls.lua
│   ├── sq_ls.lua
│   ├── sqruff_ls.lua
│   ├── standardrb_ls.lua
│   ├── starlark_ls.lua
│   ├── statix_ls.lua
│   ├── steep_ls.lua
│   ├── stimulus_ls.lua
│   ├── stylua3p_ls.lua
│   ├── stylua_ls.lua
│   ├── superhtml_ls.lua
│   ├── svelte_ls.lua
│   ├── svlang_ls.lua
│   ├── sv_ls.lua
│   ├── syntaxtree_ls.lua
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
│   ├── tinymist_ls.lua
│   ├── tofu_ls.lua
│   ├── tombi_ls.lua
│   ├── tsgo_ls.lua
│   ├── ts_ls.lua
│   ├── tsp_ls.lua
│   ├── tsquery_ls.lua
│   ├── ttags_ls.lua
│   ├── turbo_ls.lua
│   ├── turtle_ls.lua
│   ├── tvmffinav_ls.lua
│   ├── twiggy_ls.lua
│   ├── ty_ls.lua
│   ├── typeprof_ls.lua
│   ├── ungrammar_ls.lua
│   ├── unocss_ls.lua
│   ├── uv_ls.lua
│   ├── vacuum_ls.lua
│   ├── vectorcode_ls.lua
│   ├── verible_ls.lua
│   ├── veryl_ls.lua
│   ├── vespa_ls.lua
│   ├── vhdl_ls.lua
│   ├── vim_ls.lua
│   ├── vts_ls.lua
│   ├── vue_ls.lua
│   ├── wasmlangtoo_ls.lua
│   ├── wc_ls.lua
│   ├── wgslana_ls.lua
│   ├── yaml_ls.lua
│   ├── ziggy_ls.lua
│   ├── ziggyschema_ls.lua
│   ├── zk_ls.lua
│   └── z_ls.lua
├── lua
│   ├── config
│   │   ├── cicd
│   │   │   ├── ansible.lua
│   │   │   ├── json.lua
│   │   │   ├── shell.lua
│   │   │   └── sops.lua
│   │   ├── cloud
│   │   │   ├── containers.lua
│   │   │   └── sshfs.lua
│   │   ├── core
│   │   │   ├── autocmds.lua
│   │   │   ├── fixer.lua
│   │   │   ├── flash.lua
│   │   │   ├── init.lua
│   │   │   ├── lint.lua
│   │   │   ├── lsp.lua
│   │   │   ├── neotest.lua
│   │   │   ├── parser.lua
│   │   │   ├── plenary.lua
│   │   │   ├── schema.lua
│   │   │   ├── tree.lua
│   │   │   ├── trouble.lua
│   │   │   └── whichkey.lua
│   │   ├── data
│   │   │   ├── common.lua
│   │   │   ├── mysql.lua
│   │   │   ├── psql.lua
│   │   │   ├── sqlite.lua
│   │   │   └── sql.lua
│   │   ├── edu
│   │   │   └── zotcite.lua
│   │   ├── init.lua
│   │   ├── keymaps.lua
│   │   ├── lang
│   │   │   ├── cmp.lua
│   │   │   ├── go.lua
│   │   │   ├── js.lua
│   │   │   ├── julia.lua
│   │   │   ├── latex.lua
│   │   │   ├── lua.lua
│   │   │   ├── mojo.lua
│   │   │   ├── nix.lua
│   │   │   ├── php.lua
│   │   │   ├── python.lua
│   │   │   ├── ruby.lua
│   │   │   ├── rust.lua
│   │   │   ├── scala.lua
│   │   │   ├── ts.lua
│   │   │   └── zig.lua
│   │   ├── lazy.lua
│   │   ├── nav
│   │   │   ├── fzf.lua
│   │   │   ├── harpoon.lua
│   │   │   └── neotree.lua
│   │   └── ui
│   │       ├── css.lua
│   │       ├── icons.lua
│   │       ├── illuminate.lua
│   │       ├── line.lua
│   │       ├── md.lua
│   │       ├── render.lua
│   │       └── themes.lua
│   ├── mappings
│   │   ├── aimap.lua
│   │   ├── cicdmap.lua
│   │   ├── datamap.lua
│   │   ├── ddxmap.lua
│   │   ├── disable.lua
│   │   ├── genmap.lua
│   │   ├── init.lua
│   │   ├── lintmap.lua
│   │   ├── lspmap.lua
│   │   ├── mojomap.lua
│   │   ├── navmap.lua
│   │   └── pymap.lua
│   ├── plugins
│   │   ├── ai
│   │   │   ├── augment.lua
│   │   │   └── miniai.lua
│   │   ├── cicd
│   │   │   ├── ansible.lua
│   │   │   ├── containers.lua
│   │   │   ├── filetype.lua
│   │   │   ├── git.lua
│   │   │   ├── mail.lua
│   │   │   └── sops.lua
│   │   ├── cloud
│   │   │   ├── distant.lua
│   │   │   ├── fire.lua
│   │   │   ├── mail.lua
│   │   │   ├── qpg.lua
│   │   │   ├── remote.lua
│   │   │   ├── sshfs.lua
│   │   │   └── websocket.lua
│   │   ├── core
│   │   │   ├── cheatsheet.lua
│   │   │   ├── coq.lua
│   │   │   ├── flash.lua
│   │   │   ├── init.lua
│   │   │   ├── neotest.lua
│   │   │   ├── plenary.lua
│   │   │   ├── tree.lua
│   │   │   ├── trouble.lua
│   │   │   └── whichkey.lua
│   │   ├── data
│   │   │   ├── csv.lua
│   │   │   ├── dadbod.lua
│   │   │   ├── init.lua
│   │   │   ├── large.lua
│   │   │   ├── sqlite.lua
│   │   │   └── toggle.lua
│   │   ├── edu
│   │   │   ├── indent.lua
│   │   │   ├── scnvim.lua
│   │   │   ├── stt.lua
│   │   │   └── twilight.lua
│   │   ├── init.lua
│   │   ├── lang
│   │   │   ├── go.lua
│   │   │   ├── lua.lua
│   │   │   └── ts.lua
│   │   ├── nav
│   │   │   ├── fzf.lua
│   │   │   ├── harpoon.lua
│   │   │   ├── neorg.lua
│   │   │   ├── neotree.lua
│   │   │   ├── w3m.lua
│   │   │   └── windowpick.lua
│   │   └── ui
│   │       ├── bufferline.lua
│   │       ├── css.lua
│   │       ├── icons.lua
│   │       ├── illum.lua
│   │       ├── init.lua
│   │       ├── line.lua
│   │       ├── md.lua
│   │       ├── noice.lua
│   │       ├── themes.lua
│   │       └── unreal.lua
│   ├── types
│   │   ├── cicd
│   │   ├── config
│   │   │   ├── lazy.lua
│   │   │   └── options.lua
│   │   ├── core
│   │   │   ├── autocmds.lua
│   │   │   ├── fixer.lua
│   │   │   ├── lint.lua
│   │   │   ├── lsp.lua
│   │   │   ├── plenary.lua
│   │   │   ├── quickfix.lua
│   │   │   ├── schema.lua
│   │   │   └── vim.lua
│   │   ├── edu
│   │   ├── init.lua
│   │   ├── lang
│   │   │   ├── cmp.lua
│   │   │   ├── conform.lua
│   │   │   ├── go.lua
│   │   │   ├── lua.lua
│   │   │   ├── nix.lua
│   │   │   ├── ts.lua
│   │   │   └── zig.lua
│   │   └── ui
│   │       ├── html.lua
│   │       ├── line.lua
│   │       └── md.lua
│   └── utils
│       ├── clipboard.lua
│       ├── core
│       ├── dictionary
│       │   ├── en.utf-8.add
│       │   └── words.txt
│       ├── environ.lua
│       ├── init.lua
│       ├── lang
│       │   ├── go.lua
│       │   ├── lua.lua
│       │   ├── python.lua
│       │   ├── rust.lua
│       │   └── scala.lua
│       ├── safe_require.lua
│       └── ui.lua
├── manifest
├── markdown.css
├── nvim-pack-lock.json
├── qonfig.yaml
├── README.md
├── renovate.jsonc
├── resources
│   └── head.tex
├── scripts
│   ├── cargo.sh
│   ├── find_and_edit.sh
│   ├── generate
│   ├── installers
│   │   ├── go-tools.sh
│   │   └── tmux.sh
│   ├── js.sh
│   ├── quickstart.sh
│   └── ruby.sh
├── snippets
│   └── lua.json5
├── spell
│   └── en.utf-8.add
├── undo
├── vim.toml
└── vim.yml

50 directories, 528 files
```

</details>

<details>
<summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0;"><strong>🧭 About Qompass AI</strong></summary>
<blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">

<div align="center">
  <p>Matthew A. Porter<br>
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
      <img src="https://img.shields.io/badge/LinkedIn-Matt--Porter-blue?style=flat-square&logo=linkedin" alt="Personal LinkedIn">
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

<details id="Dual-License Notice">
  <summary><strong>What a Dual-License Means</strong></summary>

### Protection for Vulnerable Populations

The dual licensing aims to address the cybersecurity gap that disproportionately affects underserved populations. As highlighted by recent attacks<sup><a href="#ref1">\[1]</a></sup>, low-income residents, seniors, and foreign language speakers face higher-than-average risks of being victims of cyberattacks. By offering both open-source and commercial licensing options, we encourage the development of cybersecurity solutions that can reach these vulnerable groups while also enabling sustainable development and support.

### Preventing Malicious Use

The AGPL-3.0 license ensures that any modifications to the software remain open source, preventing bad actors from creating closed-source variants that could be used for exploitation. This is especially crucial given the rising threats to vulnerable communities, including children in educational settings. The attack on Minneapolis Public Schools, which resulted in the leak of 300,000 files and a $1 million ransom demand, highlights the importance of transparency and security<sup><a href="#ref8">\[8]</a></sup>.

### Addressing Cybersecurity in Critical Sectors

The commercial license option allows for tailored solutions in critical sectors such as healthcare, which has seen significant impacts from cyberattacks. For example, the recent Change Healthcare attack<sup><a href="#ref4">\[4]</a></sup> affected millions of Americans and caused widespread disruption for hospitals and other providers. In January 2025, CISA<sup><a href="#ref2">\[2]</a></sup> and FDA<sup><a href="#ref3">\[3]</a></sup> jointly warned of critical backdoor vulnerabilities in Contec CMS8000 patient monitors, revealing how medical devices could be compromised for unauthorized remote access and patient data manipulation.

### Supporting Cybersecurity Awareness

The dual licensing model supports initiatives like the Cybersecurity and Infrastructure Security Agency (CISA) efforts to improve cybersecurity awareness<sup><a href="#ref7">\[7]</a></sup> in "target rich" sectors, including K-12 education<sup><a href="#ref5">\[5]</a></sup>. By allowing both open-source and commercial use, we aim to facilitate the development of tools that support these critical awareness and protection efforts.

### Bridging the Digital Divide

The unfortunate reality is that too many individuals and organizations have gone into a frenzy in every facet of our daily lives<sup><a href="#ref6">\[6]</a></sup>. These unfortunate folks identify themselves with their talk of "10X" returns and building towards Artificial General Intelligence aka "AGI" while offering GPT wrappers. Our dual licensing approach aims to acknowledge this deeply concerning predatory paradigm with clear eyes while still operating to bring the best parts of the open-source community with our services and solutions.

### Recent Cybersecurity Attacks

Recent attacks underscore the importance of robust cybersecurity measures:

* The Change Healthcare cyberattack in February 2024 affected millions of Americans and caused significant disruption to healthcare providers.
* The White House and Congress jointly designated October 2024 as Cybersecurity Awareness Month. This designation comes with over 100 actions that align the Federal government and public/private sector partners are taking to help every man, woman, and child to safely navigate the age of AI.

By offering both open source and commercial licensing options, we strive to create a balance that promotes innovation and accessibility. We address the complex cybersecurity challenges faced by vulnerable populations and critical infrastructure sectors as the foundation of our solutions, not an afterthought.

### References

<div id="footnotes">
<p id="ref1"><strong>[1]</strong> <a href="https://www.whitehouse.gov/briefing-room/statements-releases/2024/10/02/international-counter-ransomware-initiative-2024-joint-statement/">International Counter Ransomware Initiative 2024 Joint Statement</a></p>

<p id="ref2"><strong>[2]</strong> <a href="https://www.cisa.gov/sites/default/files/2025-01/fact-sheet-contec-cms8000-contains-a-backdoor-508c.pdf">Contec CMS8000 Contains a Backdoor</a></p>

<p id="ref3"><strong>[3]</strong> <a href="https://www.aha.org/news/headline/2025-01-31-cisa-fda-warn-vulnerabilities-contec-patient-monitors">CISA, FDA warn of vulnerabilities in Contec patient monitors</a></p>

<p id="ref4"><strong>[4]</strong> <a href="https://www.chiefhealthcareexecutive.com/view/the-top-10-health-data-breaches-of-the-first-half-of-2024">The Top 10 Health Data Breaches of the First Half of 2024</a></p>

<p id="ref5"><strong>[5]</strong> <a href="https://www.cisa.gov/K12Cybersecurity">CISA's K-12 Cybersecurity Initiatives</a></p>

<p id="ref6"><strong>[6]</strong> <a href="https://www.ftc.gov/business-guidance/blog/2024/09/operation-ai-comply-continuing-crackdown-overpromises-ai-related-lies">Federal Trade Commission Operation AI Comply: continuing the crackdown on overpromises and AI-related lies</a></p>

<p id="ref7"><strong>[7]</strong> <a href="https://www.whitehouse.gov/briefing-room/presidential-actions/2024/09/30/a-proclamation-on-cybersecurity-awareness-month-2024/">A Proclamation on Cybersecurity Awareness Month, 2024</a></p>

<p id="ref8"><strong>[8]</strong> <a href="https://therecord.media/minneapolis-schools-say-data-breach-affected-100000/">Minneapolis school district says data breach affected more than 100,000 people</a></p>
</div>
</details>