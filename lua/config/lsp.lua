-- /qompassai/Diver/lua/config/lsp.lua
-- Qompass AI Diver LSP Bootstrap
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---
--- LSP server enable bootstrap. The server configs live in lsp/<name>_ls.lua
--- (Neovim 0.11+ native). This module enables them on first FileType,
--- one by one so a single broken config cannot block the rest.
---@module 'config.lsp'
local M = {}

local servers = {
    -- 'abl_ls', ---:TODO validate ---@source https://github.com/vscode-abl/vscode-abl
    --'abaplint_ls',
    'ada_ls',
    --'agda_ls',
    'agentscript_ls',
    'ai_ls', ---:TODO validate
    'aiken_ls',
    'air_ls',
    'alloy_ls',
    --'angular_ls',
    'ansible_ls',
    --'antlers_ls',
    'apex_ls',
    'arduino_ls',
    'asm_ls',
    'astgrep_ls',
    'astro_ls', ---:TODO  validate ---@source https://github.com/withastro/astro/tree/main/packages/language-tools
    'atlas_ls',
    'atopile_ls',
    'autotoo_ls',
    'avalonia_ls',
    'awk_ls',
    -- 'azurepipelines_ls',
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
    --'cc_ls',
    'cds_ls',
    'chpl_ls', ---:TODO validate ---@source https://github.com/chapel-lang/chapel/tree/main/tools/chpl-language-server
    --'cir_ls',             ---:TODO
    'clangd_ls',
    'clarinet_ls',
    'clojure_ls',
    'cmake_ls',
    'cobol_ls',
    --  'codebook_ls', ---:TODO validate
    'codeql_ls', ---:TODO ---@source https://github.com/github/codeql
    --'contextive_ls',  ---:TODO add glossary then validate
    -- 'copilot_ls.lua', ---:TODO validate
    --'coq_ls',
    'crates_ls',
    'crystalline_ls',
    'csharp_ls',
    --'csskit_ls',
    --'ctags_ls',
    --lsp/dexter_ls.lua
    --lsp/zizmor_ls.lua
    'cucumber_ls', ---:TODO Validate
    --cql_ls
    'dafny_ls', ---:TODO validate
    --'delphi_ls' ---:TODO
    ---@source https://docwiki.embarcadero.com/RADStudio/Florence/en/Code_Insight_Reference
    -- 'debputy_ls', ---:TODO validate ---@source https://salsa.debian.org/debian/debputy
    --'denizen_ls',          ---:TODO ---@source https://github.com/DenizenScript/DenizenVSCode
    --'deno_ls', ---lsp/linter
    'dj_ls', ---:TODO
    'djt_ls', ---:TODO
    'docker_ls', ---:TODO
    'dockercompose_ls', ---:TODO
    'dockerx_ls',
    'dolmen_ls', ---:TODO validate
    'dot_ls', ---:TODO
    -- 'dprint_ls', ---:TODO validate and finish config
    'dts_ls', ---:TODO validate
    'earthly_ls', ---:TODO validate
    -- 'editorcc_ls', ---lsp/linter
    'elixir_ls',
    'elm_ls',
    'elp_ls',
    --'ember_ls',
    -- 'emmet_ls',
    --'emmylua_ls',
    'esbonio_ls',
    --'expert_ls',
    --'facility_ls',
    'fennel_ls',
    'fish_ls',
    --'flow_ls', --:TODO
    'flux_ls',
    'foam_ls',
    'fort_ls',
    'fsautocomplete_ls',
    'fstar_ls',
    --'futhark_ls',         ---:TODO install/compile and validate
    --'gauge_ls', ---:TODO validate ---@source https://github.com/getgauge/gauge/
    'gdscript_ls',
    'gdshader_ls',
    --'ghactions_ls',
    'ghcide_ls',
    --'gitlabci_ls', ---:TODO validate
    --'gitlabduo_ls', ---:TODO
    'glasgow_ls',
    'gleam_ls',
    -- 'glint_ls', ---:TODO validate
    'glslana_ls',
    'gn_ls', ---:TODO validate
    -- os(https://github.com/google/gn-language-server) vs msft(https://github.com/microsoft/gnls)
    'golangcilint_ls', ---:TODO validate
    'gop_ls',
    --'gradle_ls',
    'grain_ls', --:TODO validate ---@source https://github.com/grain-lang/grain
    'graphql_ls',
    --'groovy_ls',          ---:TODO
    --'groovymoon_ls'       ---:TODO ---@source https://github.com/GroovyLanguageServer/groovy-language-server
    --'guile_ls',           ---:TODO
    'h_ls', ---:TODO validate ---@source https://haskell-language-server.readthedocs.io/en/latest/index.html
    --'harper_ls',
    --'haxe_ls', ---:TODO validate
    'helm_ls',
    --'herb_ls',
    --'hhvm_ls',            ---:TODO compile/install and validate ---@source https://github.com/facebook/hhvm
    'hlasm_ls', ---:TODO validate
    --'homeassist_ls',      ---:TODO
    'hoon_ls',
    'html_ls',
    'htmlhint_ls',
    'htmx_ls',
    --'hydra_ls',
    -- 'hypr_ls',
    'idris2_ls', ---:TODO validate ---@source https://github.com/idris-community/idris2-lsp
    -- 'ink_ls', ---disabled 2026-10-04: ink-lsp-server not installed; enable when validated
    'intelephense_ls',
    --'intellisense_ls'     ---:TODO ---@source https://github.com/tailwindlabs/tailwindcss-intellisense
    --'isabelle_ls',        ---:TODO ---@source https://www.cl.cam.ac.uk/research/hvg/Isabelle/
    'janet_ls', ---:TODO install janet-lsp, jpm, validate ---@source
    'java_ls',
    'jdt_ls',
    --    'jedi_ls', ---:TODO validate ---@source https://github.com/pappasam/jedi-language-server
    'jimmerdto_ls', ---:TODO validate ---@source https://github.com/Enaium/jimmer-dto-lsp
    'jinja_ls', ---:TODO
    'jq_ls',
    'json_ls',
    'jsonld_ls', ----:TODO validate
    'jsonnet_ls', ---:TODO validate
    'julia_ls',
    'just_ls',
    'kconfig_ls', ---:TODO ---@source https://github.com/anakin4747/kconfig-language-server
    --'kcl_ls',
    --'kedro_ls'            ---:TODO ---@source https://github.com/kedro-org/vscode-kedro
    --'koka_ls', ---:TODO validate
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
    -- 'markdownoxide_ls',
    'markojs_ls',
    --'marksman_ls',
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
    --'nginxcf_ls',
    'nickel_ls',
    'nil_ls',
    'nixd_ls',
    --'nobl9_ls', ---:TODO validate
    'ntt_ls',
    'nu_ls',
    --'nx_ls',
    'o_ls',
    'ocaml_ls',
    --'omnisharp_ls',
    'opencl_ls',
    'openscad_ls',
    'oxlint_ls', ---lsp/linter
    'pas_ls', ---:TODO validate ---@source https://github.com/genericptr/pascal-language-server
    'pb_ls', ---:TODO validate ---@source https://git.sr.ht/~rrc/pbls
    'perl_ls',
    'perlnav_ls', ---:TODO validate
    'perlp_ls',
    'pest_ls', ---:TODO validate https://github.com/pest-parser/pest-ide-tools
    'phan_ls',
    --'pharo_ls'            ---:TODO https://github.com/badetitou/Pharo-LanguageServer
    'phpactor_ls',
    'pico8_ls', ---:TODO validate
    -- 'plantuml_ls', ---:TODO validate https://github.com/ptdewey/plantuml-lsp
    'please_ls',
    'pli_ls', ---:TODO validate ---@source https://github.com/zowe/zowe-pli-language-support
    'poryscript_ls', ---:TODO validate  ---@source https://github.com/huderlem/poryscript-pls
    'postgres_ls',
    'prisma_ls',
    'prolog_ls', ---:TODO validate
    'proto_ls',
    'psalm_ls', ---lsp/linter
    'pug_ls',
    'puppet_ls',
    --'pwrshelles_ls',
    'pyrefly_ls',
    'qlue_ls', ---:TODO validate
    'qml_ls',
    'racket_ls', ---:TODO
    --'raku_ls'             ---:TODO ---@source https://github.com/bscan/RakuNavigator
    --'rascal_ls'           ---:TODO validate
    --'rech_ls'             ---:TODO https://github.com/RechInformatica/rech-editor-cobol/tree/master/src/lsp
    'regal_ls', ---:TODO validate ---linter/lsp
    'rego_ls', ---:TODO validate
    --'remark_ls',
    'rescript_ls',
    'robotcode_ls',
    'robotframework_ls',
    'rocq_ls', ---:TODO validate ---@source https://github.com/rocq-prover/vsrocq
    'ron_ls', ---@source https://github.com/jasonjmcghee/ron-lsp
    'roslyn_ls',
    'rpmspec_ls',
    'rubocop_ls',
    'ruby_ls', ---:TODO validate
    -- 'rumdl_ls', ---:TODO validate
    'ruff_ls',
    'rune_ls',
    'rustana_ls',
    --'selene_ls',          ---:TODO
    --'selene3p_ls',        ---:TODO
    'shopifytheme_ls', ---:TODO validate
    'slangd_ls', ---lsp/linter
    'slint_ls',
    'smithy_ls',
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
    -- 'starp_ls',
    'statix_ls',
    'steep_ls',
    --'stimulus_ls', ---:TODO validate/come back to
    -- 'stylable_ls', ---:TODO https://github.com/wix/stylable/tree/master/packages/language-service
    'stylua_ls',
    --'stylua3p_ls',
    'superhtml_ls',
    'sv_ls',
    -- 'svlant_ls',
    'svelte_ls',
    --'sway_ls'   ---:TODO https://github.com/FuelLabs/sway/tree/master/sway-lsp
    -- 'stree_ls',
    'sysl_ls', ---:TODO validate https://github.com/anz-bank/sysl
    'systemd_ls', ---:TODO validate https://github.com/JFryy/systemd-lsp
    'tailwindcss_ls',
    'taplo_ls',
    --'tblgen_ls',
    'tcl_ls', ---:TODO validate https://github.com/nmoroze/tclint
    --'teal_ls', ---:TODO install and validate
    'templ_ls',
    'termux_ls',
    -- 'test_ls', ---:TODO validate https://github.com/kbwo/testing-language-server
    'texlab_ls',
    'text_ls',
    --'tflint_ls',
    'tilt_ls', ---:TODO install/validate ---@source https://github.com/tilt-dev/tilt
    'tofu_ls',
    'tombi_ls', ---lsp/linter
    'tsgo_ls',
    --  'ts_ls',
    'tsp_ls',
    'tsquery_ls',
    --'ttags_ls',
    --  'turbo_ls',
    --'tvmffinav_ls', --validate
    'twiggy_ls',
    'ty_ls',
    'typeprof_ls',
    --'typos_ls', ---:TODO validate
    --'typst_ls', ---TODO: validate ---@source https://github.com/nvarner/typst-lsp
    'uiua_ls', ---:TODO validate  ---@source https://github.com/uiua-lang/uiua/
    'unison_ls', ---:TODO validate
    ---@source https://github.com/unisonweb/unison/blob/trunk/docs/language-server.markdown
    ---'uv_ls', --doesn't compile
    --'v_ls', ---TODO: install/validate ---@source https://github.com/vlang/vls
    --'vana_ls' ---TODO: install/validate ---@source  https://github.com/vlang/v-analyzer
    'vacuum_ls', ---TODO: install/validate ---@source  https://github.com/daveshanley/vacuum
    --'vala_ls', ---TODO:  https://github.com/Prince781/vala-language-server
    -- 'vale_ls', ---:TODO validate ---@source https://github.com/errata-ai/vale-ls
    --'vectorcode_ls',---:TODO
    -- 'verible_ls', ---TODO: install/validate ---@source  https://github.com/chipsalliance/verible
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
    'yaml_ls',
    --'y_ls',
    'yara_ls',
    'z_ls',
    --'ziggy_schema_ls',
    --'zk_ls', ---:TODO install/validate ---@source  https://github.com/zk-org/zk
    'ziggy_ls',
    --  'zuban_ls', ---:TODO validate ---@source https://docs.zubanls.com/en/latest/usage.html#configuration
}

---Enable all LSP servers, one by one (a broken config won't block others).
---@return nil
function M.enable_all()
    local failed = {}
    for _, name in ipairs(servers) do
        local ok, err = pcall(vim.lsp.enable, name)
        if not ok then
            failed[#failed + 1] = ('%s: %s'):format(name, tostring(err))
        end
    end
    if #failed > 0 then
        vim.notify(
            ('[diver] %d LSP server(s) failed to enable:\n%s'):format(#failed, table.concat(failed, '\n')),
            vim.log.levels.WARN
        )
    end
end

---Set up LSP enable. Enables immediately (vim.lsp.enable is lazy;
---servers only start when a matching buffer is opened, so there's no
---startup cost to enabling eagerly).
---@return nil
function M.setup()
    M.enable_all()
end

return M
