---~/.config/nvim/lua/config/lang/js.lua
---------------------------------
local M = {}
local function mark_pure(src)
  return src.with({ command = "true" })
end
function M.neoconf(opts)
  opts = opts or {}
  return {
    local_settings = opts.local_settings or ".neoconf.json",
    global_settings = opts.global_settings or "neoconf.json",
    import = opts.import or { vscode = true, coc = true, nlsp = true },
    live_reload = opts.live_reload ~= true,
    filetype_jsonc = opts.filetype_jsonc ~= true,
    plugins = opts.plugins or {
      lspconfig = { enabled = true },
      jsonls = { enabled = true, configured_servers_only = true },
      tsserver = { enabled = true },
      eslint = { enabled = true },
    },
  }
end
---@param opts table|nil
---@return table
function M.js_tools(opts)
  opts = opts or {}
  local config = {
    settings = {
      typescript = {
        inlayHints = {
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = true,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
        update_in_insert = opts.update_in_insert or true,
        expose_as_code_action = opts.expose_as_code_action or "all",
      },
      tailwindCSS = {
        experimental = {
          classRegex = {
            "tw`([^`]*)",
            "tw\\.[^`]+`([^`]*)",
            "tw\\(.*?\\).*?`([^`]*)",
            'className="([^"]*)',
            'class="([^"]*)',
          },
        },
      },
      code_lens = opts.code_lens or "all",
      document_formatting = opts.document_formatting ~= false,
      complete_function_calls = opts.complete_function_calls ~= false,
      jsx_close_tag = { enable = opts.jsx_close_tag ~= false },
    },
  }
  local ok, ts_tools = pcall(require, "typescript-tools")
  if ok then
    ts_tools.setup(config)
  end
  return config
end
function M.js_nls(opts)
  opts = opts or {}
  local null_ls = require("null-ls")
  local b = null_ls.builtins
  local eslint_config_path = opts.eslint_config_path or vim.fn.expand("$HOME/.config/nvim/.eslintrc.json")
  local prettier_config_path = opts.prettier_config_path or vim.fn.expand("$HOME/.config/nvim/.prettierrc")
  return {
    mark_pure(b.code_actions.eslint),
    mark_pure(b.code_actions.refactoring),
    mark_pure(b.completion.luasnip),
    mark_pure(b.diagnostics.todo_comments),
    mark_pure(b.diagnostics.trail_space),
    b.diagnostics.eslint.with({
      ft = { "javascript", "javascriptreact", "vue", "svelte", "astro" },
      command = "eslint",
      extra_args = { "--config", eslint_config_path },
    }),
    b.formatting.prettier.with({
      ft = {
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "vue",
        "svelte",
        "astro",
        "css",
        "scss",
        "html",
        "json",
        "yaml",
        "markdown",
      },
      command = "prettier",
      extra_args = { "--config", prettier_config_path },
    }),
  }
end
function M.js_lsp(opts)
  opts = opts or {}
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  require("typescript-tools").setup({
    capabilities = capabilities,
    settings = {
      tsserver_file_preferences = {
        importModuleSpecifierPreference = "relative",
        includeCompletionsForImportStatements = true,
        includeCompletionsWithSnippetText = true,
        includeAutomaticOptionalChainCompletions = true,
        includeCompletionsWithInsertText = true,
      },
      tsserver_format_options = {
        allowIncompleteCompletions = true,
        allowRenameOfImportPath = true,
      },
      expose_as_code_action = opts.expose_as_code_action or "all",
      organize_imports_on_save = opts.organize_imports_on_save ~= true,
    },
  })
  local lspconfig = require("lspconfig")
  lspconfig.eslint.setup({
  on_attach = function(_, bufnr)
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      command = "EslintFixAll",
    })
  end,
})
  return {
    eslint = true,
  }
end
function M.js_conform(opts)
  opts = opts or {}
  local base_config = require("config.lang.conform").setup(opts)
  local js_config = {
    formatters_by_ft = {
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      vue = { "prettier" },
      svelte = { "prettier" },
      astro = { "prettier" },
      markdown = { "prettier" },
    },
    formatters = {},
  }
  if base_config.formatters and base_config.formatters.prettier then
    js_config.formatters.prettier = vim.deepcopy(base_config.formatters.prettier)
    local original_prepend_args = js_config.formatters.prettier.prepend_args
    js_config.formatters.prettier.prepend_args = function(self, ctx)
      local base_args = {}
      if type(original_prepend_args) == "function" then
        base_args = original_prepend_args(self, ctx) or {}
      elseif type(original_prepend_args) == "table" then
        base_args = original_prepend_args
      end
      local prettier_opts = {}
      pcall(function()
        prettier_opts = require("neoconf").get("prettier") or {}
      end)
      local extra_args = {
        "--print-width",
        tostring(prettier_opts.printWidth or 100),
        "--tab-width",
        tostring(prettier_opts.tabWidth or 2),
        "--use-tabs",
        prettier_opts.useTabs and "true" or "false",
        "--semi",
        prettier_opts.semi ~= false and "true" or "false",
        "--single-quote",
        prettier_opts.singleQuote and "true" or "false",
      }
      return vim.list_extend(base_args, extra_args)
    end
  end
  js_config.format_on_save = base_config.format_on_save
  js_config.format_after_save = base_config.format_after_save
  local conform_ok, conform = pcall(require, "conform")
  if conform_ok then
    conform.setup({
      formatters_by_ft = js_config.formatters_by_ft,
      format_on_save = opts.format_on_save and {
        lsp_fallback = "fallback",
        timeout_ms = opts.format_timeout_ms or 500,
      },
    })
  end
  return js_config
end
function M.js_dap(opts)
  opts = opts or {}
  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then
    return {}
  end
  local dap_js_ok, dap_js = pcall(require, "dap-vscode-js")
  if not dap_js_ok then
    return {}
  end
  dap_js.setup({
    debugger_path = opts.debugger_path or vim.fn.stdpath("data") .. "/lazy/vscode-js-debug",
    adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
  })
  for _, language in ipairs({ "typescript", "javascript" }) do
    dap.configurations[language] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        cwd = "${workspaceFolder}",
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
      },
      {
        type = "pwa-node",
        request = "launch",
        name = "Debug Jest Tests",
        runtimeExecutable = "node",
        runtimeArgs = {
          "./node_modules/jest/bin/jest.js",
          "--runInBand",
        },
        rootPath = "${workspaceFolder}",
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen",
      },
      {
        type = "pwa-node",
        request = "launch",
        name = "Debug Vitest Tests",
        runtimeExecutable = "node",
        runtimeArgs = {
          "./node_modules/vitest/vitest.mjs",
          "--run",
        },
        rootPath = "${workspaceFolder}",
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen",
      },
      {
        type = "pwa-chrome",
        request = "launch",
        name = "Launch Chrome against localhost",
        url = "http://localhost:3000",
        webRoot = "${workspaceFolder}",
      },
    }
  end
  dap.configurations.typescriptreact = dap.configurations.typescript
  dap.configurations.javascriptreact = dap.configurations.javascript
  return { dap = dap.configurations }
end
function M.js_neotest(opts)
  opts = opts or {}
  local neotest_ok, neotest = pcall(require, "neotest")
  if not neotest_ok then
    return {}
  end
  local adapters = {}
  local vitest_ok, vitest = pcall(require, "neotest-vitest")
  if vitest_ok then
    table.insert(
      adapters,
      vitest({
        vitestCommand = opts.vitest_command or "npx vitest",
      })
    )
  end
  if #adapters > 0 then
    neotest.setup({
      adapters = adapters,
    })
  end
  return { neotest = adapters }
end
function M.setup_js(opts)
  opts = opts or {}
  local neoconf_config = M.neoconf(opts)
  require("neoconf").setup(neoconf_config)
  require("tailwindcss-colorizer-cmp").setup({
    color_square_width = 2,
  })
  return {
    setup_js = M.setup_js,
    neotest = M.js_neotest,
    lsp = M.js_lsp,
    dap = M.js_dap,
    conform = M.js_conform,
    null_ls = M.js_nls,
  }
end
return M
