-- qompassai/Diver/lua/config/lang/js.lua
-- Qompass AI Diver Javascript Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}

---@return table
local function base_tools_config(opts) ---@param opts table|nil
    opts = opts or {}
    return {
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
                update_in_insert = opts.update_in_insert ~= false,
                expose_as_code_action = opts.expose_as_code_action or 'all',
            },
            tailwindCSS = {
                experimental = {
                    classRegex = {
                        'tw`([^`]*)',
                        'tw\\\\.[^`]+`([^`]*)',
                        'tw\\\\(.*?\\\\).*?`([^`]*)',
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
end
---@param opts table|nil
---@return table
function M.javascript_tools(opts)
    local config = base_tools_config(opts)
    local ok, ts_tools = pcall(require, 'typescript-tools')
    if ok then
        ts_tools.setup(config)
    end
    return config
end

---@param opts table|nil
---@return table
function M.typescript_tools(opts)
    local config = base_tools_config(opts)
    local ok, ts_tools = pcall(require, 'typescript-tools')
    if ok then
        ts_tools.setup(config)
    end
    return config
end

vim.api.nvim_create_user_command('VitestFile', function()
    local file = vim.fn.expand('%:p')
    vim.fn.jobstart({
        'vitest',
        'run',
        file,
    }, {
        detach = true,
    })
end, {})
---@param opts table|nil
---@return any|nil
local function base_dap_setup(opts)
    opts = opts or {}
    local dap_ok, dap = pcall(require, 'dap')
    if not dap_ok then
        return nil
    end
    local dap_js_ok, dap_js = pcall(require, 'dap-vscode-js')
    if not dap_js_ok then
        return nil
    end
    dap_js.setup({
        debugger_path = opts.debugger_path or (vim.fn.stdpath('data') .. '/lazy/vscode-js-debug'),
        adapters = {
            'pwa-node',
            'pwa-chrome',
            'pwa-msedge',
            'node-terminal',
            'pwa-extensionHost',
        },
    })

    return dap
end

---@param dap any
---@param languages string[]
local function apply_default_dap_configs(dap, languages)
    for _, language in ipairs(languages) do
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
end
---@param opts table|nil
---@return table
function M.javascript_dap(opts)
    local dap = base_dap_setup(opts)
    if not dap then
        return {}
    end

    apply_default_dap_configs(dap, {
        'javascript',
        'javascriptreact',
    })
    return { dap = dap.configurations }
end

---@param opts table|nil
---@return table
function M.typescript_dap(opts)
    local dap = base_dap_setup(opts)
    if not dap then
        return {}
    end

    apply_default_dap_configs(dap, {
        'typescript',
        'typescriptreact',
    })
    return { dap = dap.configurations }
end

---@param opts table|nil
---@return table
function M.setup_javascript(opts)
    opts = opts or {}
    return {
        tools = M.javascript_tools(opts),
        dap = M.javascript_dap(opts),
        neotest = M.js_neotest and M.js_neotest(opts) or nil,
    }
end

---@param opts table|nil
---@return table
function M.setup_typescript(opts)
    opts = opts or {}
    return {
        tools = M.typescript_tools(opts),
        dap = M.typescript_dap(opts),
        neotest = M.js_neotest and M.js_neotest(opts) or nil,
    }
end

return M