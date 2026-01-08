-- /qompassai/dotfiles./config/lsp/init.lua
-- Qompass AI Diver LSP Init Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://microsoft.github.io/language-server-protocol/implementors/servers/
---@source https://langserver.org/
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
    'abaplint_ls', ---:TODO: ---validate ---@source https://github.com/abaplint/abaplint | https://www.npmjs.com/org/abaplint
    'abl_ls', ---:TODO validate ---@source https://github.com/vscode-abl/vscode-abl
    'ada_ls',
    'agda_ls',
    'ai_ls', ---:TODO validate
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
    'astro_ls', ---:TODO  validate ---@source https://github.com/withastro/astro/tree/main/packages/language-tools
    'atlas_ls',
    'atopile_ls',
    'autotoo_ls',
    'awk_ls',
    'azurepipelines_ls',
    'b_ls', ---:TODO validate ---@source https://github.com/hhu-stups/b-language-server
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
    'buck2_ls', ---:TODO validate, add to README
    'buf_ls',
    'c3_ls',
    'cairo_ls',
    'cc_ls',
    'cds_ls',
    'chpl_ls', ---:TODO validate ---@source https://github.com/chapel-lang/chapel/tree/main/tools/chpl-language-server
    'checkmake_ls',
    --'cir_ls',             ---:TODO
    'clangd_ls',
    'clarinet_ls',
    'clojure_ls',
    'cmake_ls',
    'cobol_ls',
    'codebook_ls', ---:TODO validate
    'codeql_ls', ---:TODO ---@source https://github.com/github/codeql
    --'contextive_ls',  ---:TODO add glossary then validate
    'copilot_ls.lua', ---:TODO validate
    --'coq_ls',
    'crystalline_ls',
    'csharp_ls',
    'cucumber_ls', ---:TODO Validate
    'dafny_ls', ---:TODO validate
    --'delphi_ls'           ---:TODO ---@source https://docwiki.embarcadero.com/RADStudio/Florence/en/Code_Insight_Reference
    'debputy_ls', ---:TODO validate ---@source https://salsa.debian.org/debian/debputy
    --'denizen_ls',          ---:TODO ---@source https://github.com/DenizenScript/DenizenVSCode
    'deno_ls', ---lsp/linter
    'dj_ls', ---:TODO
    'djt_ls', ---:TODO
    'docker_ls', ---:TODO
    'dockercompose_ls', ---:TODO
    'dolmen_ls', ---:TODO validate
    'dot_ls', ---:TODO
    'dprint_ls', ---:TODO validate and finish config
    'dts_ls', ---:TODO validate
    'earthly_ls', ---:TODO validate
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
    --'futhark_ls',         ---:TODO install/compile and validate
    'gauge_ls', ---:TODO validate ---@source https://github.com/getgauge/gauge/
    'gdscript_ls',
    'gdshader_ls',
    'ghactions_ls',
    'ghcide_ls',
    'gitlabci_ls', ---:TODO validate
    --'gitlabduo_ls', ---:TODO
    'glasgow_ls',
    'gleam_ls',
    'glint_ls', ---:TODO validate
    'glslana_ls',
    'golangcilint_ls', ---:TODO validate
    'gn_ls', ---:TODO validate os(https://github.com/google/gn-language-server) vs msft(https://github.com/microsoft/gnls)
    'gop_ls',
    --'gradle_ls',
    'grain_ls', --:TODO validate ---@source https://github.com/grain-lang/grain
    'graphql_ls',
    --'groovy_ls',          ---:TODO
    --'groovymoon_ls'       ---:TODO ---@source https://github.com/GroovyLanguageServer/groovy-language-server
    --'guile_ls',           ---:TODO
    'h_ls', ---:TODO validate ---@source https://haskell-language-server.readthedocs.io/en/latest/index.html
    'harper_ls',
    --'haxe_ls', ---:TODO validate
    'helm_ls',
    'herb_ls',
    --'hhvm_ls',            ---:TODO compile/install and validate ---@source https://github.com/facebook/hhvm
    'hlasm_ls', ---:TODO validate
    --'homeassist_ls',      ---:TODO
    'hoon_ls',
    'html_ls',
    'htmx_ls',
    'hydra_ls',
    'hypr_ls',
    'idris2_ls', ---:TODO validate ---@source https://github.com/idris-community/idris2-lsp
    'ink_ls', ---:TODO validate ---@source https://github.com/ink-analyzer/ink-analyzer/tree/master/crates/lsp-server
    'intelephense_ls',
    --'intellisense_ls'     ---:TODO ---@source https://github.com/tailwindlabs/tailwindcss-intellisense
    --'isabelle_ls',        ---:TODO ---@source https://www.cl.cam.ac.uk/research/hvg/Isabelle/
    --'janet_ls',           ---:TODO install janet-lsp, jpm, validate ---@source https://github.com/janet-lang/jpm https://github.com/CFiggers/janet-lsp
    'java_ls',
    'jdt_ls',
    'jedi_ls', ---:TODO validate ---@source https://github.com/pappasam/jedi-language-server
    --'jimmerdto_ls',       ---:TODO ---@source https://github.com/Enaium/jimmer-dto-lsp
    'jinja_ls', ---:TODO
    'jq_ls',
    'json_ls',
    'jsonnet_ls', ---:TODO validate
    'julia_ls',
    'just_ls',
    'kconfig_ls', ---:TODO ---@source https://github.com/anakin4747/kconfig-language-server
    --'kcl_ls',
    --'kedro_ls'            ---:TODO ---@source https://github.com/kedro-org/vscode-kedro
    --'koka_ls',
    'kotlin_ls',
    'laravel_ls',
    'larkparse_ls', ---:TODO validate ---@source https://github.com/dynovaio/lark-parser-language-server
    'lean_ls',
    'lelwel_ls', ---:TODO validate ---@source https://github.com/0x2a-42/lelwel
    'lemminx_ls', ---:TODO validate
    --'ltex_ls',
    'ltexplus_ls',
    'lua_ls',
    'luau_ls',
    'lwc_ls',
    'm68k_ls',
    'markdownoxide_ls',
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
    'mojo_ls', ---:TODO validate
    'motoko_ls', ---:TODO validate ---@source  https://github.com/dfinity/vscode-motoko
    'msbuildptoo_ls',
    'muon_ls',
    'mutt_ls',
    'neocmake_ls',
    'nextflow_ls',
    --'next_ls',
    'nginx_ls',
    'nginxcf_ls',
    'nickel_ls',
    'nil_ls',
    'nixd_ls',
    'nobl9_ls', ---:TODO validate  https://github.com/nobl9/nobl9-language-server
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
    'pas_ls', ---:TODO validate ---@source https://github.com/genericptr/pascal-language-server
    'pb_ls', ---:TODO validate ---@source https://git.sr.ht/~rrc/pbls
    'perl_ls',
    'perlnav_ls', ---:TODO validate ---@source https://github.com/bscan/PerlNavigator
    'perlp_ls',
    'pest_ls', ---:TODO validate https://github.com/pest-parser/pest-ide-tools
    'phan_ls',
    --'pharo_ls'            ---:TODO https://github.com/badetitou/Pharo-LanguageServer
    'phpactor_ls',
    'pico8_ls', ---:TODO validate
    'platuml_ls', ---:TODO validate https://github.com/ptdewey/plantuml-lsp
    'please_ls',
    'pli_ls', ---:TODO validate ---@source https://github.com/zowe/zowe-pli-language-support
    'poryscript_ls', ---:TODO validate  ---@source https://github.com/huderlem/poryscript-pls
    'postgres_ls',
    'prisma_ls',
    'prolog_ls', ---:TODO validate
    'prosemd_ls',
    'proto_ls',
    'psalm_ls', ---lsp/linter
    'pug_ls',
    'puppet_ls',
    'pwrshelles_ls',
    'pyrefly_ls',
    'qml_ls',
    'qlue_ls', ---:TODO validate https://github.com/IoannisNezis/Qlue-ls
    'racket_ls', ---:TODO
    --'raku_ls'             ---:TODO ---@source https://github.com/bscan/RakuNavigator
    --'rascal_ls'           ---:TODO https://github.com/usethesource/rascal-language-servers
    --'rech_ls'             ---:TODO https://github.com/RechInformatica/rech-editor-cobol/tree/master/src/lsp
    'regal_ls', ---:TODO validate ---linter/lsp
    'rego_ls', ---:TODO validate
    'remark_ls',
    'rescript_ls',
    'robotcode_ls',
    'robotframework_ls',
    'rocq_ls', ---:TODO validate ---@source https://github.com/rocq-prover/vsrocq
    'roslyn_ls',
    'rpmspec_ls',
    'rubocop_ls',
    'ruby_ls', ---:TODO validate
    --'rumdl_ls',           ---:TODO validate ---@source  https://github.com/rvben/rumdl
    'ruff_ls',
    'rune_ls',
    'rustana_ls',
    'salt_ls', ---:TODO validate ---@source https://github.com/dcermak/salt-lsp
    --'selene_ls',          ---:TODO
    --'selene3p_ls',        ---:TODO
    'served_ls', ---:TODO ---@source https://github.com/Pure-D/serve-d
    'slangd_ls', ---lsp/linter
    'shopifytheme_ls', ---:TODO validate
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
    'stylable_ls', ---:TODO https://github.com/wix/stylable/tree/master/packages/language-service
    'stylua_ls',
    --'stylua3p_ls',
    'superhtml_ls',
    'svelte_ls',
    'svlant_ls',
    'sv_ls',
    --'sway_ls'   ---:TODO https://github.com/FuelLabs/sway/tree/master/sway-lsp
    'syntaxtree_ls',
    'sysl_ls', ---:TODO validate https://github.com/anz-bank/sysl
    'systemd_ls', ---:TODO validate https://github.com/JFryy/systemd-lsp
    'tailwindcss_ls',
    'taplo_ls',
    'tblgen_ls',
    'tcl_ls', ---:TODO validate https://github.com/nmoroze/tclint
    --'teal_ls', ---:TODO install and validate
    'templ_ls',
    'termux_ls',
    'test_ls', ---:TODO validate https://github.com/kbwo/testing-language-server
    'texlab_ls',
    'text_ls',
    'tflint_ls',
    'tilt_ls', ---:TODO install/validate ---@source https://github.com/tilt-dev/tilt
    'tofu_ls',
    'tombi_ls', ---lsp/linter
    'tsgo_ls',
    'ts_ls',
    'tsquery_ls',
    'tsp_ls',
    'ttags_ls',
    'turbo_ls',
    'tvmffinav_ls',
    'twiggy_ls',
    'ty_ls',
    'typeprof_ls',
    --'typos_ls',
    'typst_ls', ---TODO: validate ---@source https://github.com/nvarner/typst-lsp
    'uiua_ls', ---:TODO validate  ---@source https://github.com/uiua-lang/uiua/
    'unison_ls', ---:TODO validate ---@source https://github.com/unisonweb/unison/blob/trunk/docs/language-server.markdown
    ---'uv_ls', --doesn't compile
    --'v_ls', ---TODO: install/validate ---@source https://github.com/vlang/vls
    --'vana_ls' ---TODO: install/validate ---@source  https://github.com/vlang/v-analyzer
    'vacuum_ls', ---TODO: install/validate ---@source  https://github.com/daveshanley/vacuum
    'vala_ls', ---TODO:  https://github.com/Prince781/vala-language-server
    --'vale_ls',      ---:TODO validate ---@source https://github.com/errata-ai/vale-ls
    --'vectorcode_ls',---:TODO
    'verible_ls', ---TODO: install/validate ---@source  https://github.com/chipsalliance/verible
    'veridian_ls',
    'veryl_ls',
    --'visualforce_ls', ---TODO: install/validate ---@source https://github.com/forcedotcom/salesforcedx-vscode
    'vim_ls', ---TODO: validate ---@source https://github.com/iamcco/vim-language-server
    --'vts_ls', ---:TODO dx
    'vue_ls', ---:TODO validate ---@source  https://github.com/vuejs/language-tools/tree/master/packages/language-server
    --'w_ls', ---:TODO https://github.com/kenkangxgwe/lsp-wl
    'wasmlangtoo_ls',
    'wc_ls', ---:TODO install/validate-  ---@source https://github.com/wc-toolkit/wc-language-server
    'wgslana_ls',
    --'yaml_ls',
    --'y_ls',
    --'yara_ls'
    'ziggy_ls',
    'ziggy_schema_ls',
    --'zk_ls', ---:TODO install/validate ---@source  https://github.com/zk-org/zk
    'z_ls',
    'zuban_ls', ---:TODO validate ---@source https://docs.zubanls.com/en/latest/usage.html#configuration
})
---Deprecated/Outdated/NotUsing
--'apl_ls', ---deprecated ---@source https://github.com/OptimaSystems/apl-language-server
--'as2_ls' ---deprecated ---@source https://github.com/admvx/as2-language-support
--'autohotkey_ls', ---notusing (windows only) ---@source  https://github.com/thqby/vscode-autohotkey2-lsp
--'basics_ls', ---outdated ---@source  https://github.com/antonk52/basics-language-server/
--'batch_ls' ---@outdated ---@source https://github.com/RechInformatica/rech-editor-batch/tree/master/src/lsp
--'benten_ls', ---deprecated ---@source https://github.com/rabix/benten
--'boriel_ls', ---notusing ---@source https://github.com/boriel-basic/boriel-basic-lsp
--'bsl_ls', ---notusing, sec ---@source https://github.com/1c-syntax/bsl-language-server
--'buddy_ls', --not-using, sec ---@source  https://github.com/buddy-compiler/buddy-mlir#buddy-lsp-server
--'bzl_ls', deprecated
-- 'camel_ls',---outdated ---@source https://github.com/camel-tooling/camel-language-server
--'ceylon_ls' ---deprecated ---@source https://github.com/jvasileff/vscode-ceylon
--'circom_ls', ---outdated
--'cl_ls' ---outdated ---@source https://github.com/cxxxr/cl-lsp
--'cquery_ls' ---deprecated for clangd/ccls ---@source https://github.com/jacobdufault/cquery
--'coffeesense_ls', -- two years since last git
--'cspell_ls',          ---deprecated for codebook
--'css_ls', ---outdated last update 1 year ago
--'custom_ls' ---outdated ---@source https://github.com/Matsuuu/custom-elements-language-server
--'dagger_ls' ---deprecated
---'dcm_ls', ---notusing has paid plans https://dcm.dev/docs/getting-started/for-developers/installation/
--'diagnostic_ls', ---outdated
--'dspinyin_ls' --deprecated https://github.com/iamcco/ds-pinyin-lsp
--'ecsact_ls, ---outdated ---@source https://github.com/ecsact-dev/ecsact_lsp_server
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
--'hdlchecker_ls', ---outdated ---@source https://pypi.org/project/hdl-checker/
---'hie_ls', --deprecated
--'hlsl_ls', ---outdated ---@source https://github.com/tgjones/HlslTools/tree/master/src/ShaderTools.
--'kdl_ls' ---outdated ---@source https://github.com/kdl-org/vscode-kdl
--'kos_ls'---outdated ---@source https://github.com/jonnyboyC/kos-language-server
--'languagetool_ls' ---oudated ---@source https://github.com/languagetool-language-server/languagetool-languageserver
--'lpg_ls' ---outdated ---@source https://github.com//A-LPG/LPG-language-server
---'meson_ls', deprecated' ---@source https://github.com/JCWasmx86/mesonlsp
--'moveana_ls', ---deprecated ---@source https://github.com/move-language/move/tree/main/language/move-analyzer
--'nelua_ls', ---outdated  ---@source https://github.com/codehz/nelua-lsp
--'oraide_ls' ---deprecated ---@source https://github.com/penev92/Oraide.LanguageServer
--'orbacle_ls' ---outdated ---@source https://github.com/swistak35/orbacle
---'pact_ls', ---outdated ---@source https://github.com/kadena-io/pact-lsp
--'papyrus_ls', ---outdated https://github.com/joelday/papyrus-lang
--'polymer_ls' ---deprecated ---@source https://github.com/Polymer/tools/tree/master/packages/editor-service
--'py_ls', ---notusing| basedpyright instead
--'pylyzer_ls',  ---deprecated for ty ---@source https://github.com/mtshiba/pylyzer
---'pyre', ---deprecated for pyrefly
--'quicklintjs_ls', ---outdated ---@source https://quick-lint-js.com/
--'r_ls', ---deprecated install, config, validate
--'raml_ls' ---deprecated ---@source https://github.com/mulesoft-labs/raml-language-server
--'red_ls' ---outdated ---@source https://github.com/bitbegin/redlangserver
--'reason_ls', --deprecated for rescript_ls/ocaml_ls
--'rel_ls' ---deprecated ---@source https://github.com/sscit/rel
--'robotstxt_ls' ---outdated ---@source https://github.com/BeardedFish/vscode-robots-dot-txt-support
---'rnix_ls',| no longer maintained
---  --'scry_ls', --deprecated for crystalline
--scheme_ls --not using https://gitlab.com/Serenata/Serenata
--'shader_ls' ---outdated https://github.com/shader-ls/shader-language-server
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
--    --'tibbobasic_ls' ---:outdated https://github.com/tibbotech/tibbo-basic
--'themecheck_ls.lua' ---:deprecated ---@source  https://github.com/Shopify/shopify-cli
--'trino_ls' ---outdated ---@source https://gitlab.com/rocket-boosters/trinols  -
--'turtle_ls', ---outdated ---@source https://github.com/stardog-union/stardog-language-servers/tree/master/packages/turtle-language-server
-- ungrammar_ls', ---outdated ---@source https://github.com/binhtran432k/ungrammar-language-features
--'unocss_ls',  ---outdated ---@source https://github.com/xna00/unocss-language-server
--'vdmj_ls' ---outdated ---@source https://github.com/nickbattle/vdmj/tree/master/lsp
--'wolfram_ls' ---outdated ---@source https://github.com/WolframResearch/lspserver'
--'wxml_ls' ---outdated ---@source https://github.com/chemzqm/wxml-languageserver
---'yang_ls', ---outdated ---@source https://github.com/TypeFox/yang-lsp