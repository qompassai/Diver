-- qompassai/Diver/lua/config/lang/js.lua
-- Qompass AI Diver Javascript Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}

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
          includeInlayEnumMemberValueHints = true,
        },
        update_in_insert = opts.update_in_insert or true,
        expose_as_code_action = opts.expose_as_code_action or 'all',
      },
      tailwindCSS = {
        experimental = {
          classRegex = {
            'tw`([^`]*)',
            'tw\\.[^`]+`([^`]*)',
            'tw\\(.*?\\).*?`([^`]*)',
            'className="([^"]*)',
            'class="([^"]*)',
          },
        },
      },
      code_lens = opts.code_lens or 'all',
      document_formatting = opts.document_formatting ~= false,
      complete_function_calls = opts.complete_function_calls ~= false,
      jsx_close_tag = { enable = opts.jsx_close_tag ~= false },
    },
  }
  local ok, ts_tools = pcall(require, 'typescript-tools')
  if ok then
    ts_tools.setup(config)
  end
  return config
end

function M.js_dap(opts)
  opts = opts or {}
  local dap_ok, dap = pcall(require, 'dap')
  if not dap_ok then
    return {}
  end
  local dap_js_ok, dap_js = pcall(require, 'dap-vscode-js')
  if not dap_js_ok then
    return {}
  end
  dap_js.setup({
    debugger_path = opts.debugger_path or vim.fn.stdpath('data') .. '/lazy/vscode-js-debug',
    adapters = {
      'pwa-node',
      'pwa-chrome',
      'pwa-msedge',
      'node-terminal',
      'pwa-extensionHost',
    },
  })
  for _, language in ipairs({ 'typescript', 'javascript' }) do
    dap.configurations[language] = {
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        cwd = '${workspaceFolder}',
      },
      {
        type = 'pwa-node',
        request = 'attach',
        name = 'Attach',
        processId = require('dap.utils').pick_process,
        cwd = '${workspaceFolder}',
      },
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Debug Jest Tests',
        runtimeExecutable = 'node',
        runtimeArgs = { './node_modules/jest/bin/jest.js', '--runInBand' },
        rootPath = '${workspaceFolder}',
        cwd = '${workspaceFolder}',
        console = 'integratedTerminal',
        internalConsoleOptions = 'neverOpen',
      },
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Debug Vitest Tests',
        runtimeExecutable = 'node',
        runtimeArgs = { './node_modules/vitest/vitest.mjs', '--run' },
        rootPath = '${workspaceFolder}',
        cwd = '${workspaceFolder}',
        console = 'integratedTerminal',
        internalConsoleOptions = 'neverOpen',
      },
      {
        type = 'pwa-chrome',
        request = 'launch',
        name = 'Launch Chrome against localhost',
        url = 'http://localhost:3000',
        webRoot = '${workspaceFolder}',
      },
    }
  end
  dap.configurations.typescriptreact = dap.configurations.typescript
  dap.configurations.javascriptreact = dap.configurations.javascript
  return { dap = dap.configurations }
end

function M.setup_js(opts)
  opts = opts or {}
  return {
    dap = M.js_dap(opts),
    neotest = M.js_neotest(opts),
  }
end

return M