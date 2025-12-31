-- /qompassai/dotfiles./config/lsp/init.lua
-- Qompass AI Diver LSP Init Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://microsoft.github.io/language-server-protocol/implementors/servers/
vim.filetype.add({
  extension = {
    bri = 'brioche',
    brioche = 'brioche',
    cairo = 'cairo',
    clar = 'clar',
    clarity = 'clarity',
    comp = 'glsl',
    cr = 'crystal',
    cypher = 'cypher',
    frag = 'glsl',
    geom = 'glsl',
    hbs = 'html.handlebars',
    handlebars = 'html.handlebars',
    rst = 'rst',
    schelp = 'scdoc',
    tesc = 'glsl',
    tese = 'glsl',
    tsx = 'typescript.tsx',
    ['yaml.ansible'] = 'yaml.ansible',
    ['yml.ansible'] = 'yaml.ansible',
  },
  filename = {
    ['ansible.cfg'] = 'ansible',
    ['project.bri'] = 'brioche',
    brioche = 'brioche',
    Cairo = 'cairo',
    Crystal = 'crystal',
  },
  pattern = {
    ['.*%.als'] = 'alloy',
    ['.*%.ansible%.ya?ml'] = 'yaml.ansible',
    ['.*%.cairo'] = 'cairo',
    ['.*%.clar'] = 'clar',
    ['.*%.clarity'] = 'clarity',
    ['.*%.crystal'] = 'crystal',
    ['.*/gitconfig.*'] = 'gitconfig',
    ['.*/gitignore.*'] = 'gitignore',
    ['.*/gitcommit.*'] = 'gitcommit',
    ['.*/templates/.*%.yaml'] = 'helm',
    ['.*/templates/.*%.yml'] = 'helm',
    ['.*/templates/.*%.tpl'] = 'helm',
    ['.*/values.*%.ya?ml'] = 'yaml.helm-values',
    ['.*%.gts'] = 'typescript.glimmer',
    ['.*%.gjs'] = 'javascript.glimmer',
  },
})
vim.lsp.enable({
  --'abl_ls' ---:TODO ---@source https://github.com/vscode-abl/vscode-abl
  'ada_ls',
  'agda_ls',
  --'ai_ls',
  'aiken_ls',
  'air_ls',
  'alloy_ls',
  'angular_ls',
  'ansible_ls',
  'antlers_ls',
  'apex_ls',
  'arduino_ls',
  'asm_ls',
  'astgrep_ls',
  'astro_ls',
  'atlas_ls',
  'atopile_ls',
  'autotoo_ls',
  'awk_ls',
  'azurepipelines_ls',
  --'b_ls',
  'bacon_ls',
  'basedpy_ls',
  'bash_ls',
  --'basics_ls', --updated last year
  --'bazelrc_ls',
  'beancount_ls',
  'bicep_ls',
  'biome_ls',
  'bitbake_ls',
  'blueprint_ls',
  'bq_ls',
  'brioche_ls',
  'bsc_ls',
  'buck2_ls',
  'buf_ls',

  'c3_ls',
  'cairo_ls',
  --'camel_ls', :TODO ---@source https://github.com/camel-tooling/camel-language-server
  'cc_ls',
  'cds_ls',
  'checkmake_ls',
  --'cir_ls',
  --'circom_ls', --last git in 2023
  'clangd_ls',
  'clarinet_ls',
  'clojure_ls',
  'cmake_ls',
  'cobol_ls',
  'codebook_ls',
  --'codeql_ls', :TODO ---@source https://github.com/github/codeql
  --'coffeesense_ls', -- two years since last git
  --'contextive_ls',
  --'copilot_ls.lua',
  --'coq_ls',
  'crystalline_ls',
  'csharp_ls',
  --'cspell_ls', ---lsp/linter
  --'css_ls', --last update 1 year ago
  'cucumber_ls',
  'dafny_ls',
  --'dagger_ls' -- deprecated
  --'dcm_ls',
  --'debputy_ls',
  'deno_ls', ---lsp/linter
  --'diagnostic_ls', -2years since last commit
  'dj_ls',
  'djt_ls',
  'docker_ls',
  'dockercompose_ls',
  'dolmen_ls',
  'dot_ls',
  --'dotenvlint_ls',
  'dprint_ls',
  --'dspinyin_ls' --deprecated
  'dts_ls',
  --'earthly_ls',
  'editorcc_ls', ---lsp/linter
  --'efm_ls', --last release Nov 2024
  'elixir_ls',
  'elm_ls',
  'elp_ls',
  'ember_ls',
  'emmet_ls',
  -- 'emmylua_ls',
  --'erg_ls', --not using
  --'ecsact_ls',
  'esbonio_ls',
  --'eslint_ls', --using biome instead, last updated 1 year ago.
  --'ecsact_ls',
  'expert_ls',
  'facility_ls',
  'fennel_ls',
  'fish_ls',
  'flow_ls',
  'flux_ls',
  'foam_ls',
  'fort_ls',
  'fsautocomplete_ls',
  --'fsharp_ls', --no longer maintained
  'fstar_ls',
  --'futhark_ls',
  --'gauge_ls', ---:TODO ---@source https://github.com/getgauge/gauge/
  'gdscript_ls',
  'gdshader_ls',
  'ghactions_ls',
  'ghcide_ls',
  --'ghdl_ls', --last activity one year ago.
  --'ginko_ls', last touched 1 year ago
  'gitlabci_ls',
  --'gitlabduo_ls',
  'glasgow_ls',
  'gleam_ls',
  'glint_ls',
  'glslana_ls',
  'golangcilint_ls',
  --'gn_ls', ---:TODO os(https://github.com/google/gn-language-server) vs msft(https://github.com/microsoft/gnls)
  'gop_ls',
  --'gradle_ls',
  --'grain_ls' ---:TODO ---@source https://github.com/grain-lang/grain
  'graphql_ls',
  'groovy_ls',
  --'guile_ls',
  --'h_ls',
  'harper_ls',
  --'haxe_ls',
  --'hdlchecker_ls',
  'helm_ls',
  'herb_ls',
  --'hhvm_ls',
  --'hie_ls', --deprecated
  --'hlasm_ls',
  --'hlsl_ls', ---:TODO ---@source https://github.com/tgjones/HlslTools/tree/master/src/ShaderTools.LanguageServer
  'homeassist_ls',
  'hoon_ls',
  'html_ls',
  'htmx_ls',
  'hydra_ls',
  'hypr_ls',
  --'idris2_ls', ---:TODO ---@source https://github.com/idris-community/idris2-lsp
  --'ink_ls', ---:TODO ---@source https://github.com/ink-analyzer/ink-analyzer/tree/master/crates/lsp-server
  'intelephense_ls',
  --'isabelle_ls', ---:TODO ---@source https://www.cl.cam.ac.uk/research/hvg/Isabelle/
  --'janet_ls',
  'java_ls',
  'jdt_ls',
  --'jedi_ls', ---:TODO ---@source https://github.com/pappasam/jedi-language-server
  --'jimmerdto_ls',---:TODO ---@source https://github.com/Enaium/jimmer-dto-lsp
  'jinja_ls',
  'jq_ls',
  'json_ls',
  'jsonnet_ls',
  'julia_ls',
  'just_ls',
  --'kcl_ls',
  --'koka_ls',
  'kotlin_ls',
  'laravel_ls',
  'lean_ls',
  --'lelwel_ls',
  'lemminx_ls',
  --'lexical_ls', deprecated
  --'ltex_ls',
  'ltexplus_ls',
  'lua_ls',
  'luau_ls',
  'lwc_ls',
  'm68k_ls',
  --'makelint_ls',
  --markdownoxide_ls.lua
  'markojs_ls',
  'marksman_ls',
  'matlab_ls',
  'mdxana_ls',
  'metals_ls',
  'millet_ls',
  'mint_ls',
  'mlir_ls',
  'mlirpdll_ls',
  'mm0_ls',
  'mojo_ls',
  'motoko_ls',
  'msbuildptoo_ls',
  'muon_ls',
  'mutt_ls',
  --'nelua_ls',
  'neocmake_ls',
  'nextflow_ls',
  --'next_ls',
  'nginx_ls',
  'nginxcf_ls',
  'nickel_ls',
  'nil_ls',
  'nixd_ls',
  'nobl9_ls', ---:TODO  https://github.com/nobl9/nobl9-vscode/
  'nomad_ls',
  'ntt_ls',
  'nu_ls',
  --'nx_ls',
  'ocaml_ls',
  'o_ls',
  'omnisharp_ls',
  'opencl_ls',
  'openscad_ls',
  'oxlint_ls', ---lsp/linter
  --'pact_ls',
  --'papyrus_ls', ---:TODO https://github.com/joelday/papyrus-lang
  --'pas_ls',
  'pb_ls',
  'perl_ls',
  'perlnav_ls',
  'perlp_ls',
  --'pest_ls', ---:TODO https://github.com/pest-parser/pest-ide-tools
  'phan_ls',
  --'pharo_ls' ---:TODO https://github.com/badetitou/Pharo-LanguageServer
  'phpactor_ls',
  --'pico8_ls',
  'please_ls',
  --'pli_ls',
  'postgres_ls',
  'pwrshelles_ls',
  'prisma_ls',
  'prolog_ls',
  'prosemd_ls',
  'proto_ls',
  'psalm_ls', ---lsp/linter
  'pug_ls',
  'puppetes_ls',
  'puppet_ls',
  --'py_ls',
  --'pylyzer_ls',
  --'pyre', -- deprecated for pyrefly
  'pyrefly_ls', ---lsp/linter
  'qml_ls',
  --'qlue_ls' ---:TODO https://github.com/IoannisNezis/Qlue-ls
  'quicklintjs_ls',
  --'r_ls',
  'racket_ls',
  --'rascal_ls' ---:TODO https://github.com/usethesource/rascal-language-servers
  'regal_ls', --linter/lsp
  'rego_ls',
  'remark_ls',
  'rescript_ls',
  'robotcode_ls',
  'robotframework_ls',
  'roslyn_ls',
  'rpmspec_ls',
  'rubocop_ls', ---lsp/linter
  'ruby_ls',
  'rumdl_ls',
  'ruff_ls',
  'rune_ls',
  'rustana_ls',
  --'salt_ls',
  --'scry_ls', --deprecated for crystalline
  --'selene_ls',
  --'selene3p_ls',
  'served_ls',
  --'shader_ls' ---:TODO https://github.com/shader-ls/shader-language-server
  --'sixtyfps_ls', --replaced with slint
  'slangd_ls', ---lsp/linter
  'shopifytheme_ls',
  'slint_ls',
  --smarty_ls, --3 years old
  'smithy_ls',
  'snakeskin_ls',
  'solang_ls',
  'solargraph_ls',
  'solc_ls',
  'solidity_ls',
  'solidnomic_ls',
  'somesass_ls',
  'sorbet_ls',
  'sourcekit_ls',
  --'spectral_ls', --last update was 1-3 years ago
  --'spyglass_ls', deprecated
  --'sqlls' --2 years old
  'sq_ls',
  'sqruff_ls',
  'standardrb_ls',
  'starlark_ls',
  'starp_ls',
  'statix_ls',
  'steep_ls',
  'stimulus_ls',
  --'stylable_ls' ---:TODO https://github.com/wix/stylable/tree/master/packages/language-service
  --'stylelint_ls', last release 1 year ago
  --'stylua_ls',
  --'stylua3p_ls',
  'superhtml_ls',
  'svelte_ls',
  'svlant_ls',
  'sv_ls',
  --'sway_ls' ---:TODO https://github.com/FuelLabs/sway/tree/master/sway-lsp
  'syntaxtree_ls',
  --'sysl_ls' ---:TODO https://github.com/anz-bank/sysl
  'systemd_ls',
  'tailwindcss_ls',
  'taplo_ls',
  'tblgen_ls',
  --'teal_ls',
  'templ_ls',
  'termux_ls',
  --'terraform_ls', --last release in 2021
  --'test_ls', ---:TODO https://github.com/kbwo/testing-language-server
  'texlab_ls',
  'text_ls',
  'tflint_ls',
  'themecheck_ls.lua',
  'tofu_ls',
  'tombi_ls', ---lsp/linter
  'tsgo_ls',
  'ts_ls',
  'tsquery_ls',
  'tsp_ls',
  'ttags_ls',
  'turbo_ls',
  'turtle_ls',
  'tvmffinav_ls',
  'twiggy_ls',
  'ty_ls',
  'typeprof_ls',
  --'typos_ls',
  'typst_ls',
  --'uiua_ls',
  'viva_ls',
  'ungrammar_ls',
  --'unison_ls',
  'unocss_ls',
  ---'uv_ls', --doesn't compile
  'vala_ls',
  'vale_ls',
  'vacuum_ls',
  --'vectorcode_ls',
  'verible_ls',
  'veridian_ls',
  'veryl_ls',
  --'visualforce_ls',
  --'v_ls',
  'rocq_ls',
  'vim_ls',
  'vts_ls',
  'vue_ls',
  'w_ls', ---:TODO https://github.com/kenkangxgwe/lsp-wl
  'wasmlangtoo_ls',
  'wgslana_ls',
  'yaml_ls',
  --'yang_ls',
  --'y_ls',
  --'yara_ls'
  'ziggy_ls',
  'ziggy_schema_ls',
  --'zk_ls',
  'z_ls',
  'zuban_ls',
})
---Deprecated/Outdated/NotUsing
--'apl_ls', ---deprecated ---@source https://github.com/OptimaSystems/apl-language-server
--'as2_ls' ---deprecated ---@source https://github.com/admvx/as2-language-support
--'autohotkey_ls',
--'benten_ls', ---deprecated ---@source https://github.com/rabix/benten
--'bsl_ls',
--'buddy_ls', --not-using
--'bzl_ls', deprecated
--'ceylon_ls' ---deprecated ---@source https://github.com/jvasileff/vscode-ceylon
--'cquery_ls' ---deprecated for clangd/ccls ---@source https://github.com/jacobdufault/cquery
--'fluentbit_ls' ---outdated ---@source https://github.com/sh-cho/fluent-bit-lsp
--'fuzion_ls' ---deprecated ---@source https://github.com/tokiwa-software/fuzion-lsp-server
--'gluon_ls' ---outdated ---@source https://github.com/gluon-lang/gluon_language-server
--'lpg_ls' ---outdated ---@source https://github.com//A-LPG/LPG-language-server
---'meson_ls', deprecated'
--'moveana_ls', ---deprecated
--'oraide_ls' ---deprecated ---@source https://github.com/penev92/Oraide.LanguageServer
--'polymer_ls' ---deprecated ---@source https://github.com/Polymer/tools/tree/master/packages/editor-service
--'raml_ls' ---deprecated ---@source https://github.com/mulesoft-labs/raml-language-server
--'red_ls' ---outdated ---@source https://github.com/bitbegin/redlangserver
--'reason_ls', --deprecated for rescript_ls/ocaml_ls
--'rel_ls' ---deprecated ---@source https://github.com/sscit/rel
--'robotstxt_ls' ---outdated ---@source https://github.com/BeardedFish/vscode-robots-dot-txt-support
---'rnix_ls',| no longer maintained
--scheme_ls --not using
----'sourcegraph_ls', ---deprecated for ts_ls ---@source https://github.com/sourcegraph/javascript-typescript-langserver
---'sourcegraphgo_ls' ---deprecated for gopls ---@source https://github.com/sourcegraph/go-langserver
--'sourcer_ls', ---deprecated ---@source https://github.com/erlang/sourcer
--'sparq_ls' ---outdated ---@source https://github.com/stardog-union/stardog-language-servers/tree/master/packages/sparql-language-server
--'tads3too_ls' ---outdated ---@source https://github.com/toerob/vscode-tads3tools
--'trino_ls' ---outdated ---@source https://gitlab.com/rocket-boosters/trinols
--'vdmj_ls' ---outdated ---@source https://github.com/nickbattle/vdmj/tree/master/lsp
--'wolfram_ls' ---outdated ---@source https://github.com/WolframResearch/lspserver
--'wxml_ls' ---outdated ---@source https://github.com/chemzqm/wxml-languageserver