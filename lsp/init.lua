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
    --'abaplint_ls'         ---:TODO: ---@source https://github.com/abaplint/abaplint
    --'abl_ls'              ---:TODO ---@source https://github.com/vscode-abl/vscode-abl
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
    --'astro_ls',           ---:TODO ---@source https://github.com/withastro/astro/tree/main/packages/language-tools
    'atlas_ls',
    'atopile_ls',
    'autotoo_ls',
    'awk_ls',
    'azurepipelines_ls',
    --'b_ls',               ---:TODO ---@source https://github.com/hhu-stups/b-language-server
    'bacon_ls',
    'basedpy_ls',
    'bash_ls',
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
    --'camel_ls',           ---:TODO ---@source https://github.com/camel-tooling/camel-language-server
    'cc_ls',
    'cds_ls',
    --'chpl_ls'             ---:TODO ---@source https://github.com/chapel-lang/chapel/tree/main/tools/chpl-language-server
    'checkmake_ls',
    --'cir_ls',             ---:TODO
    'clangd_ls',
    'clarinet_ls',
    'clojure_ls',
    'cmake_ls',
    'cobol_ls',
    'codebook_ls',
    --'codeql_ls',          ---:TODO ---@source https://github.com/github/codeql
    --'contextive_ls',
    --'copilot_ls.lua',
    --'coq_ls',
    'crystalline_ls',
    'csharp_ls',
    --'cspell_ls', ---lsp/linter
    --'cucumber_ls',
    --'dafny_ls',           ---:TODO
    --'dcm_ls',
    --'delphi_ls'           ---:TODO ---@source https://docwiki.embarcadero.com/RADStudio/Florence/en/Code_Insight_Reference
    --'debputy_ls',         ---:TODO ---@source https://salsa.debian.org/debian/debputy
    --'denizen_ls'          ---:TODO ---@source https://github.com/DenizenScript/DenizenVSCode
    'deno_ls', ---lsp/linter
    --'dj_ls',              ---:TODO
    --'djt_ls',             ---:TODO
    --'docker_ls',          ---:TODO
    --'dockercompose_ls',   ---:TODO
    --'dolmen_ls',          ---:TODO
    --'dot_ls',             ---:TODO
    --'dotenvlint_ls',
    --'dprint_ls',          ---:TODO
    --'dts_ls',             ---:TODO
    --'earthly_ls',         ---:TODO
    --'ecsact_ls',          ---:TODO
    'editorcc_ls', ---lsp/linter
    'elixir_ls',
    'elm_ls',
    'elp_ls',
    'ember_ls',
    'emmet_ls',
    --'emmylua_ls',
    'esbonio_ls',
    'expert_ls',
    'facility_ls',
    'fennel_ls',
    'fish_ls',
    'flow_ls',
    'flux_ls',
    'foam_ls',
    'fort_ls',
    'fsautocomplete_ls',
    'fstar_ls',
    --'futhark_ls',         ---:TODO
    --'gauge_ls',           ---:TODO ---@source https://github.com/getgauge/gauge/
    'gdscript_ls',
    'gdshader_ls',
    'ghactions_ls',
    'ghcide_ls',
    'gitlabci_ls',
    --'gitlabduo_ls',       ---:TODO
    'glasgow_ls',
    'gleam_ls',
    'glint_ls',
    'glslana_ls',
    'golangcilint_ls',
    --'gn_ls',        ---:TODO os(https://github.com/google/gn-language-server) vs msft(https://github.com/microsoft/gnls)
    'gop_ls',
    --'gradle_ls',
    --'grain_ls'      ---:TODO ---@source https://github.com/grain-lang/grain
    'graphql_ls',
    --'groovy_ls',    ---:TODO
    --'groovymoon_ls' ---:TODO ---@source https://github.com/GroovyLanguageServer/groovy-language-server
    --'guile_ls',     ---:TODO
    --'h_ls',
    'harper_ls',
    --'haxe_ls',
    --'hdlchecker_ls',      ---:TODO
    'helm_ls',
    'herb_ls',
    --'hhvm_ls',            ---:TODO
    --'hlasm_ls',           ---:TODO
    --'hlsl_ls',            ---:TODO ---@source https://github.com/tgjones/HlslTools/tree/master/src/ShaderTools.LanguageServer
    --'homeassist_ls',      ---:TODO
    'hoon_ls',
    'html_ls',
    'htmx_ls',
    'hydra_ls',
    'hypr_ls',
    --'idris2_ls',          ---:TODO ---@source https://github.com/idris-community/idris2-lsp
    --'ink_ls',             ---:TODO ---@source https://github.com/ink-analyzer/ink-analyzer/tree/master/crates/lsp-server
    'intelephense_ls',
    --'intellisense_ls'     ---:TODO ---@source https://github.com/tailwindlabs/tailwindcss-intellisense
    --'isabelle_ls',        ---:TODO ---@source https://www.cl.cam.ac.uk/research/hvg/Isabelle/
    --'janet_ls',           ---:TODO
    'java_ls',
    'jdt_ls',
    --'jedi_ls',            ---:TODO ---@source https://github.com/pappasam/jedi-language-server
    --'jimmerdto_ls',       ---:TODO ---@source https://github.com/Enaium/jimmer-dto-lsp
    --'jinja_ls',           ---:TODO
    'jq_ls',
    'json_ls',
    --'jsonnet_ls',         ---:TODO
    'julia_ls',
    'just_ls',
    --'kconfig_ls'          ---:TODO ---@source https://github.com/anakin4747/kconfig-language-server
    --'kcl_ls',
    --'kedro_ls'            ---:TODO ---@source https://github.com/kedro-org/vscode-kedro
    --'koka_ls',
    --'kos_ls'              ---:TODO ---@source https://github.com/jonnyboyC/kos-language-server
    'kotlin_ls',
    'laravel_ls',
    --'larkparse_ls'        ---:TODO ---@source https://github.com/dynovaio/lark-parser-language-server
    'lean_ls',
    --'lelwel_ls',          ---:TODO
    'lemminx_ls', ---:TODO
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
    --'mojo_ls',            ---:TODO
    --'motoko_ls',          ---:TODO
    'msbuildptoo_ls',
    'muon_ls',
    'mutt_ls',
    --'nelua_ls',           ---:TODO
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
    --'papyrus_ls',         ---:TODO https://github.com/joelday/papyrus-lang
    --'pas_ls',
    --'pb_ls',              ---:TODO
    'perl_ls',
    'perlnav_ls',
    'perlp_ls',
    --'pest_ls',            ---:TODO https://github.com/pest-parser/pest-ide-tools
    'phan_ls',
    --'pharo_ls'            ---:TODO https://github.com/badetitou/Pharo-LanguageServer
    'phpactor_ls',
    --'pico8_ls',
    'please_ls',
    --'pli_ls',
    'postgres_ls',
    'pwrshelles_ls',
    'prisma_ls',
    --'prolog_ls',          ---:TODO
    'prosemd_ls',
    'proto_ls',
    'psalm_ls', ---lsp/linter
    'pug_ls',
    'puppetes_ls',
    'puppet_ls',
    --'py_ls',
    --'pylyzer_ls',
    'pyrefly_ls', ---lsp/linter
    'qml_ls',
    --'qlue_ls'             ---:TODO https://github.com/IoannisNezis/Qlue-ls
    'quicklintjs_ls',
    --'r_ls',
    --'racket_ls',          ---:TODO
    --'raku_ls'             ---:TODO ---@source https://github.com/bscan/RakuNavigator
    --'rascal_ls'           ---:TODO https://github.com/usethesource/rascal-language-servers
    --'rech_ls'             ---:TODO https://github.com/RechInformatica/rech-editor-cobol/tree/master/src/lsp
    'regal_ls', ---linter/lsp
    'rego_ls',
    'remark_ls',
    'rescript_ls',
    'robotcode_ls',
    'robotframework_ls',
    'roslyn_ls',
    'rpmspec_ls',
    'rubocop_ls', ---lsp/linter
    'ruby_ls',
    --'rumdl_ls',           ---:TODO
    'ruff_ls',
    'rune_ls',
    'rustana_ls',
    --'salt_ls',            ---:TODO
    --'selene_ls',          ---:TODO
    --'selene3p_ls',        ---:TODO
    --'served_ls',          ---:TODO
    --'shader_ls'           ---:TODO https://github.com/shader-ls/shader-language-server
    'slangd_ls', ---lsp/linter
    --'shopifytheme_ls',    ---:TODO
    'slint_ls',
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
    'sq_ls',
    'sqruff_ls',
    'standardrb_ls',
    'starlark_ls',
    'starp_ls',
    'statix_ls',
    'steep_ls',
    'stimulus_ls',
    --'stylable_ls'   ---:TODO https://github.com/wix/stylable/tree/master/packages/language-service
    --'stylua_ls',
    --'stylua3p_ls',
    'superhtml_ls',
    'svelte_ls',
    'svlant_ls',
    'sv_ls',
    --'sway_ls'             ---:TODO https://github.com/FuelLabs/sway/tree/master/sway-lsp
    'syntaxtree_ls',
    --'sysl_ls'             ---:TODO https://github.com/anz-bank/sysl
    'systemd_ls',
    'tailwindcss_ls',
    'taplo_ls',
    'tblgen_ls',
    --'teal_ls',
    --'tibbobasic_ls'       ---:TODO https://github.com/tibbotech/tibbo-basic
    'templ_ls',
    'termux_ls',
    --'test_ls',            ---:TODO https://github.com/kbwo/testing-language-server
    'texlab_ls',
    'text_ls',
    'tflint_ls',
    --'themecheck_ls.lua',  ---:TODO
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
    --'vale_ls',      ---:TODO
    'vacuum_ls',
    --'vectorcode_ls',---:TODO
    'verible_ls',
    'veridian_ls',
    'veryl_ls',
    --'visualforce_ls',
    --'v_ls',
    --'rocq_ls', ---:TODO
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
    --'zuban_ls', ---:TODO
})
---Deprecated/Outdated/NotUsing
--'apl_ls', ---deprecated ---@source https://github.com/OptimaSystems/apl-language-server
--'as2_ls' ---deprecated ---@source https://github.com/admvx/as2-language-support
--'autohotkey_ls', ---notusing (windows only)
--'basics_ls', ---outdated
--'batch_ls' ---@outdated ---@source https://github.com/RechInformatica/rech-editor-batch/tree/master/src/lsp
--'benten_ls', ---deprecated ---@source https://github.com/rabix/benten
--'boriel_ls', ---notusing ---@source https://github.com/boriel-basic/boriel-basic-lsp
--'bsl_ls',
--'buddy_ls', --not-using
--'bzl_ls', deprecated
--'ceylon_ls' ---deprecated ---@source https://github.com/jvasileff/vscode-ceylon
--'circom_ls', ---outdated
--'cl_ls' ---outdated ---@source https://github.com/cxxxr/cl-lsp
--'cquery_ls' ---deprecated for clangd/ccls ---@source https://github.com/jacobdufault/cquery
--'coffeesense_ls', -- two years since last git
--'css_ls', ---outdated last update 1 year ago
--'dagger_ls' ---deprecated
--'diagnostic_ls', ---outdated
--'dspinyin_ls' --deprecated
--'efm_ls', --last release Nov 2024
--'erg_ls', ---not using
---'eslint_ls', --using biome instead, last updated 1 year ago.
--'fluentbit_ls' ---outdated ---@source https://github.com/sh-cho/fluent-bit-lsp
--'fsharp_ls', --no longer maintained
--'fuzion_ls' ---deprecated ---@source https://github.com/tokiwa-software/fuzion-lsp-server
--'ghdl_ls', --last activity one year ago.
--'ginko_ls', last touched 1 year ago
--'gluon_ls' ---outdated ---@source https://github.com/gluon-lang/gluon_language-server
--'gql_ls' ---outdated ---@source https://github.com/Mayank1791989/gql-language-server
---'hie_ls', --deprecated
--'kdl_ls' ---outdated ---@source https://github.com/kdl-org/vscode-kdl
--'languagetool_ls' ---oudated ---@source https://github.com/languagetool-language-server/languagetool-languageserver
--'lpg_ls' ---outdated ---@source https://github.com//A-LPG/LPG-language-server
---'meson_ls', deprecated'
--'moveana_ls', ---deprecated
--'oraide_ls' ---deprecated ---@source https://github.com/penev92/Oraide.LanguageServer
--'orbacle_ls' ---outdated ---@source https://github.com/swistak35/orbacle
--'polymer_ls' ---deprecated ---@source https://github.com/Polymer/tools/tree/master/packages/editor-service
---'pyre', ---deprecated for pyrefly
--'raml_ls' ---deprecated ---@source https://github.com/mulesoft-labs/raml-language-server
--'red_ls' ---outdated ---@source https://github.com/bitbegin/redlangserver
--'reason_ls', --deprecated for rescript_ls/ocaml_ls
--'rel_ls' ---deprecated ---@source https://github.com/sscit/rel
--'robotstxt_ls' ---outdated ---@source https://github.com/BeardedFish/vscode-robots-dot-txt-support
---'rnix_ls',| no longer maintained
---  --'scry_ls', --deprecated for crystalline
--scheme_ls --not using
---'sixtyfps_ls', ---deprecated replaced with slint
---smarty_ls ---outdated
----'sourcegraph_ls', ---deprecated for ts_ls ---@source https://github.com/sourcegraph/javascript-typescript-langserver
---'sourcegraphgo_ls' ---deprecated for gopls ---@source https://github.com/sourcegraph/go-langserver
--'sourcer_ls', ---deprecated ---@source https://github.com/erlang/sourcer
--'spectral_ls', ---outdated
--'sparq_ls' ---outdated ---@source https://github.com/stardog-union/stardog-language-servers/tree/master/packages/sparql-language-server
--'spyglass_ls', deprecated'
--'sqlls' ---outdated
---'stylelint_ls', last release 1 year ago
--'tads3too_ls' ---outdated ---@source https://github.com/toerob/vscode-tads3tools
--'terraform_ls', ---outdated
--'trino_ls' ---outdated ---@source https://gitlab.com/rocket-boosters/trinols
--'vdmj_ls' ---outdated ---@source https://github.com/nickbattle/vdmj/tree/master/lsp
--'wolfram_ls' ---outdated ---@source https://github.com/WolframResearch/lspserver'
--
--'wxml_ls' ---outdated ---@source https://github.com/chemzqm/wxml-languageserver
