-- qompassai/Diver/lua/config/lang/js.lua
-- Qompass AI Diver Javascript Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
local function xdg_config(path)
  return vim.fn.expand(vim.env.XDG_CONFIG_HOME or '~/.config') .. "/" .. path
end

---@param opts table|nil
---@return table
function M.js_tools(opts)
  opts = opts or {}
  local config = {
    settings = {
      typescript = {
        inlayHints = {
          includeInlayParameterNameHints = 'all',
          includeInlayParameterNameHintsWhenArgumentMatchesName = true,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true
        },
        update_in_insert = opts.update_in_insert or true,
        expose_as_code_action = opts.expose_as_code_action or 'all'
      },
      tailwindCSS = {
        experimental = {
          classRegex = {
            'tw`([^`]*)', 'tw\\.[^`]+`([^`]*)',
            'tw\\(.*?\\).*?`([^`]*)', 'className="([^"]*)',
            'class="([^"]*)'
          }
        }
      },
      code_lens = opts.code_lens or 'all',
      document_formatting = opts.document_formatting ~= false,
      complete_function_calls = opts.complete_function_calls ~= false,
      jsx_close_tag = { enable = opts.jsx_close_tag ~= false }
    }
  }
  local ok, ts_tools = pcall(require, 'typescript-tools')
  if ok then ts_tools.setup(config) end
  return config
end

function M.js_nls(opts)
  opts = opts or {}
  local null_ls = require("null-ls")
  local b = null_ls.builtins
  local biome_config_path = opts.biome_config_path or xdg_config("biome/biome.json5")
  local sources = {
    b.formatting.biome.with({
      extra_args = { "--config-path", biome_config_path },
      filetypes = {
        "javascript", "typescript", "tsx", "jsx", "vue", "svelte", "astro", "json", "jsonc", "markdown"
      },
    }),
    b.diagnostics.biome.with({
      extra_args = { "--config-path", biome_config_path },
      on_output = function(params)
        local diags = {}
        for _, diag in ipairs(params.output.diagnostics or {}) do
          table.insert(diags, {
            row = diag.location.start.line,
            col = diag.location.start.column,
            end_row = diag.location["end"].line,
            end_col = diag.location["end"].column,
            source = "biome",
            message = diag.message,
            severity = vim.diagnostic.severity.WARN,
          })
        end
        return diags
      end,
      filetypes = {
        "javascript", "typescript", "tsx", "jsx", "vue", "svelte", "astro", "json", "jsonc", "markdown"
      },
      format = "json",
    }),
  }
  return sources
end

function M.js_lsp(opts)
  opts = opts or {}
  local lspconfig = require("lspconfig")
  local capabilities = opts.capabilities or require("cmp_nvim_lsp").default_capabilities()
  local filetypes = opts.filetypes or { "javascript", "javascriptreact" }
  local init_options = opts.init_options or { hostInfo = "neovim" }
  local settings = opts.settings or {
    javascript = {
      format = { enable = true },
      preferences = { importModuleSpecifierPreference = "relative" },
    },
  }
  local on_attach = opts.on_attach or function(client, _)
    client.server_capabilities.documentFormattingProvider = true
  end
  lspconfig.ts_ls.setup({
    capabilities = capabilities,
    filetypes = filetypes,
    init_options = init_options,
    settings = settings,
    on_attach = on_attach,
  })
  return { ts_ls = true }
end

function M.js_conform(opts)
  opts = opts or {}
  local conform_config = require("config.lang.conform").conform_cfg(opts)
  local biome_ft = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "tsx",
    "jsx",
    "vue",
    "svelte",
    "astro",
    "json",
    "jsonc",
  }
  local js_config = {
    formatters_by_ft = {},
    formatters = {},
  }
  if conform_config.formatters and conform_config.formatters.biome then
    js_config.formatters.biome = conform_config.formatters.biome
  end
  for _, ft in ipairs(biome_ft) do
    js_config.formatters_by_ft[ft] = { "biome" }
  end
  js_config.format_on_save = conform_config.format_on_save
  js_config.format_after_save = conform_config.format_after_save
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.setup({
      formatters = js_config.formatters,
      formatters_by_ft = js_config.formatters_by_ft,
      format_on_save = opts.format_on_save and {
        lsp_fallback = "fallback",
        timeout_ms = opts.format_timeout_ms or 500,
      } or nil,
    })
  end
  return js_config
end

function M.js_dap(opts)
  opts = opts or {}
  local dap_ok, dap = pcall(require, 'dap')
  if not dap_ok then return {} end
  local dap_js_ok, dap_js = pcall(require, 'dap-vscode-js')
  if not dap_js_ok then return {} end
  dap_js.setup({
    debugger_path = opts.debugger_path or vim.fn.stdpath('data') ..
        '/lazy/vscode-js-debug',
    adapters = {
      'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal',
      'pwa-extensionHost'
    }
  })
  for _, language in ipairs({ 'typescript', 'javascript' }) do
    dap.configurations[language] = {
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        cwd = '${workspaceFolder}'
      }, {
      type = 'pwa-node',
      request = 'attach',
      name = 'Attach',
      processId = require('dap.utils').pick_process,
      cwd = '${workspaceFolder}'
    }, {
      type = 'pwa-node',
      request = 'launch',
      name = 'Debug Jest Tests',
      runtimeExecutable = 'node',
      runtimeArgs = { './node_modules/jest/bin/jest.js', '--runInBand' },
      rootPath = '${workspaceFolder}',
      cwd = '${workspaceFolder}',
      console = 'integratedTerminal',
      internalConsoleOptions = 'neverOpen'
    }, {
      type = 'pwa-node',
      request = 'launch',
      name = 'Debug Vitest Tests',
      runtimeExecutable = 'node',
      runtimeArgs = { './node_modules/vitest/vitest.mjs', '--run' },
      rootPath = '${workspaceFolder}',
      cwd = '${workspaceFolder}',
      console = 'integratedTerminal',
      internalConsoleOptions = 'neverOpen'
    }, {
      type = 'pwa-chrome',
      request = 'launch',
      name = 'Launch Chrome against localhost',
      url = 'http://localhost:3000',
      webRoot = '${workspaceFolder}'
    }
    }
  end
  dap.configurations.typescriptreact = dap.configurations.typescript
  dap.configurations.javascriptreact = dap.configurations.javascript
  return { dap = dap.configurations }
end

function M.js_neotest(opts)
  opts = opts or {}
  local neotest_ok, neotest = pcall(require, 'neotest')
  if not neotest_ok then return {} end
  local adapters = {}
  local vitest_ok, vitest = pcall(require, 'neotest-vitest')
  if vitest_ok then
    table.insert(adapters, vitest(
      { vitestCommand = opts.vitest_command or 'npx vitest' }))
  end
  if #adapters > 0 then neotest.setup({ adapters = adapters }) end
  return { neotest = adapters }
end

function M.setup_js(opts)
  opts = opts or {}
  require('tailwindcss-colorizer-cmp').setup({ color_square_width = 2 })
  return {
    conform = M.js_conform(opts),
    dap = M.js_dap(opts),
    setup_js = M.setup_js,
    neotest = M.js_neotest,
    lsp = M.js_lsp,
    null_ls = M.js_nls
  }
end

return M
