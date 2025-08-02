-- /qompassai/Diver/lua/config/core/lsp.lua
-- Qompass AI Diver Native LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
capabilities = vim.lsp.protocol.make_client_capabilities()
vim.lsp.enable({
  'ada_ls',
  'ast_grep',
  'air',
  'angularls',
  'ansiblels',
  'antlersls',
  'arduino_language_server',
  'asm_lsp',
  'astro',
  'autohotkey_lsp',
  'autotools_ls',
  'awk_ls',
  'azure_pipelines_ls',
  'bacon_ls',
  'basepyright',
  'bashls',
  --	'basics_ls',
  'bazelrc_lsp',
  'beancount',
  'bicep',
  'biome',
  'blueprint_ls',
  'bqls',
  'bright_script',
  'bsl_ls',
  'buck2',
  'buddy_ls',
  'buf',
  'buf_ls',
  'bufls',
  'bzl',
  'c3_lsp',
  'cairo_ls',
  'ccls',
  'cds_lsp',
  'circom-lsp',
  'clangd',
  'clarinet',
  'clojure_lsp',
  'cmake',
  'cobol_ls',
  'codebook',
  'coffeesense',
  --	'contextive',
  'coq_lsp',
  'csharp-language-server',
  --'cspell_ls',
  'deno',
  'docker_compose_language_service',
  'dockerls',
  'dolmenls',
  'dotls',
  'dot-language-server',
  'dprint',
  'dts_lsp',
  --	'efm',
  'elixirls',
  'elmls',
  'elp',
  'ember',
  'emmet_language_server',
  'emmet_ls',
  'emmylua_ls',
  'erg_language_server',
  'erlangls',
  'esbonio',
  'eslint',
  'facility_language_server',
  'fennel_language_server',
  'fennel_ls',
  'fish_lsp',
  'flow',
  'flux_lsp',
  'foam_ls',
  'fortls',
  'fsautocomplete',
  'fsharp_language_server',
  'fstar',
  'gdscript',
  'gdshader_lsp',
  'ghcide',
  'gh_actions_ls',
  'ghdl_ls',
  'gitlab_ci_ls',
  'ginko_ls',
  'gitlab_ci_ls',
  'glasgow',
  'gleam',
  'glint',
  'glsl_analyzer',
  'glslls',
  'gnls',
  'golangci_lint_ls',
  'gopls',
  'gradle_ls',
  'graphql',
  'groovyls',
  'guile_ls',
  'helmls',
  'hdl_checker',
  'herb_ls',
  'hlasm',
  'hls',
  'hoon_ls',
  'html',
  'htmx',
  'hydra',
  'hyprls',
  'intelephense',
  'java_language_server',
  'jdtls',
  'jinja_lsp',
  'jsonls',
  'jqls',
  'jsonnet_ls',
  'julials',
  'just',
  'kotlin_language_server',
  'kotlin_lsp',
  'laravel_ls',
  'lexical',
  'lsp_ai',
  'ltex',
  'ltex-ls-plus',
  'lua_ls',
  'luau_lsp',
  'lwc_ls',
  'marksman',
  'matlab_ls',
  'mdx_analyzer',
  'mesonlsp',
  'metals',
  'millet',
  'mlir_lsp_server',
  'mlir_pdll_lsp_server',
  'mm0_ls',
  'mojo',
  'move_analyzer',
  'msbuild_project_tools_server',
  'muon',
  'mutt_ls',
  'nelua_lsp',
  'neocmake',
  'nextflow_ls',
  'nextls',
  'nginx_language_server',
  'nickel_ls',
  'nil_ls',
  'nixd',
  'nomad_lsp',
  'nushell',
  --'nxls',
  'ocamlls',
  'ocamllsp',
  'ols',
  'omnisharp',
  'opencl_ls',
  'openscal_ls',
  'openscad_lsp',
  'oxlint',
  'pasls',
  'pbls',
  'perlls',
  'perlnavigator',
  'perlpls',
  'phan',
  'phpactor',
  'pico8_ls',
  'please',
  'pli',
  'postgres_lsp',
  'powershell_es',
  'prismals',
  'prosemd_lsp',
  'protols',
  'psalm',
  'pug',
  'puppet',
  --  'pylsp',
  --  'pylyzer',
  'pyrefly',
  --  'pyright',
  'qmlls',
  'quick_lint_js',
  'r_language_server',
  'regal',
  'regols',
  --'remark_ls',
  'rls',
  'rnix',
  'robotcode',
  'robotframework_ls',
  'roslyn_ls',
  'rpmspec',
  'rubocop',
  'rubylsp',
  'ruff',
  'rune_languageserver',
  'rust_analyzer',
  'salt_ls',
  'scry',
  'selene3p_ls',
  'serve_d',
  'sixtyfps',
  'slangd',
  'slint_lsp',
  'smithy_ls',
  'snakeskin_ls',
  'solang',
  'solargraph',
  'solc',
  'solidity',
  'solidity_ls_nomicfoundation',
  'somesass_ls',
  'sorbet',
  'sourcekit',
  'spectral',
  'sqlls',
  'sqls',
  'sqlruff',
  'standardrb',
  'starlark_rust',
  'starpls',
  'statix',
  'steep',
  'stimulus_ls',
  'stylelint_lsp',
  'stylua3p_ls',
  'superhtml',
  'svelte',
  'svlantserver',
  'svls',
  'swift_mesonls',
  'syntax_tree',
  'systemd_ls',
  'tailwindcss',
  'taplo',
  'tblgen_lsp_server',
  'teal_ls',
  'templ',
  'termux_language_server',
  'terraform_lsp',
  'terraformls',
  'texlab',
  'textlsp',
  'tflint',
  'tofu_ls',
  'tombi',
  'ts_ls',
  'ts_query_ls',
  'tsp_server',
  'ttags',
  'turbo_ls',
  'turtle_ls',
  --'tvm_ffi_navigator',
  'twiggy_language_server',
  'ty',
  'typeprof',
  'typst_lsp',
  'viva',
  'ungrammar',
  'unison',
  'unocss',
  'uvls',
  'v_analyzer',
  'vacuum',
  --	'vectorcode_server',
  'verible',
  'veridian',
  'veryl_ls',
  'vls',
  'vscoqtop',
  'vimls',
  'vtsls',
  'vue_ls',
  'wasm_language_tools',
  'wgsl_analyzer',
  'yamlls',
  'yls',
  'ziggy',
  'ziggy_schema',
  --	'zk',
  'zls'
})
vim.lsp.set_log_level 'trace'
require('vim.lsp.log').set_format_func(vim.inspect)
vim.diagnostic.show(nil, nil, { virtual_text = true })
vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())
vim.lsp.semantic_tokens.enable(not vim.lsp.semantic_tokens.is_enabled())
local function on_list(options)
  vim.fn.setqflist({}, ' ', options)
  vim.cmd.cfirst()
end
vim.lsp.buf.definition({ on_list = on_list })
vim.lsp.buf.references(nil, { on_list = on_list })
vim.lsp.buf.definition({ loclist = true })
vim.lsp.buf.references(nil, { loclist = true })
vim.lsp.config('*', {
  autostart = true,
  single_file_support = true,
  flags = {
    debounce_text_changes = 150
  },
  workspace_required = false,
  capabilities = vim.tbl_deep_extend("force",
    vim.lsp.protocol.make_client_capabilities(),
    {
      textDocument = {
        synchronization = {
          dynamicRegistration = true,
          willSave = false,
          willSaveWaitUntil = false,
          didSave = true,
          syncKind = vim.lsp.protocol.TextDocumentSyncKind.Incremental,
        },
        inlayHint = {
          dynamicRegistration = true,
        },
        semanticTokens = {
          multilineTokenSupport = true,
          requests = {
            range = true,
            full = {
              delta = true
            },
          },
          tokenTypes = {},
          tokenModifiers = {},
          inlayHint = {
            dynamicRegistration = true,
          },
        },
      }
    }
  ),
  on_attach = function(client, bufnr)
    vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>f", function()
      vim.lsp.buf.format({ async = false })
    end, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.get_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.get__next, opts)
    if client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
      vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
    end
    if client.server_capabilities.documentFormattingProvider then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr, async = false })
        end,
      })
    end
  end,
})
vim.diagnostic.config({
  virtual_text = {
    enabled = true,
    prefix = "●",
    spacing = 4,
  },
  virtual_lines = true,
  underline = {
    severity = {
      min = vim.diagnostic.severity.HINT,
      max = vim.diagnostic.severity.ERROR,
    },
  },
  float = {
    border = "rounded",
    source = "if_many",
    focusable = true,
    scope = "line",
  },
  update_in_insert = false,
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚 ",
      [vim.diagnostic.severity.WARN]  = "󰀪 ",
      [vim.diagnostic.severity.INFO]  = "󰋽 ",
      [vim.diagnostic.severity.HINT]  = "󰌶 ",
    },
  },
  numhl = {
    [vim.diagnostic.severity.ERROR] = 'DiagnosticError',
    [vim.diagnostic.severity.WARN] = 'DiagnosticWarn',
    [vim.diagnostic.severity.INFO] = 'DiagnosticInfo',
    [vim.diagnostic.severity.HINT] = 'DiagnosticHint',
  },
})
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
  callback = function()
    vim.lsp.codelens.refresh()
  end,
})
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities.documentHighlightProvider then
      local bufnr = args.buf
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
      })
    end
  end,
})
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    vim.lsp.document_color.enable(true, args.buf)
  end
})
vim.keymap.set('i', '<c-space>', function()
  vim.lsp.completion.get()
end)
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    vim.lsp.document_color.enable(true, args.buf)
  end
})
return M
