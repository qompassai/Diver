-- qompassai/Diver/lua/config/lang/go.lua
-- Qompass AI Diver Go Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local dap = require('dap')
local lspconfig = require('lspconfig')
local null_ls = require('null-ls')
local M = {}
function M.go_nls()
    local formatting = null_ls.builtins.formatting
    local diagnostics = null_ls.builtins.diagnostics
    local code_actions = null_ls.builtins.code_actions
    local go_sources = {
        code_actions.gomodifytags.with({
            ft = {'go'},
            method = null_ls.methods.CODE_ACTION
        }), code_actions.refactoring.with({
            ft = {'go'},
            method = null_ls.methods.CODE_ACTION
        }), diagnostics.golangci_lint.with({
            ft = {'go'},
            method = null_ls.builtin.DIAGNOSTICS_ON_SAVE,
            cmd = {'golangcli-lint'},
            extra_args = {'run', '--fix=false', '--out-format=json'}
        }), diagnostics.revive.with({
            ft = {'go'},
            method = null_ls.methods.DIAGNOSTICS_ON_SAVE,
            command = {'revive'},
            extra_args = {'-formatter', 'json', './...'}
        }), diagnostics.staticcheck.with({
            ft = {'go'},
            method = null_ls.methods.DIAGNOSTICS_ON_SAVE,
            extra_args = {'-f', 'json', './...'}
        }), diagnostics.vacuum.with({
            ft = {'yaml', 'json'},
            method = null_ls.methods_DIAGNOSTICS,
            args = {'report', '--stdin', '--stdout', '--format', 'json'},
            to_stdin = true,
            format = 'json'
        }), diagnostics.verilator.with({
            ft = {'verilog', 'systemverilog'},
            method = null_ls.builtin.DIAGNOSTICS_ON_SAVE,
            extra_args = {'-lint-only', '-Wno-fatal', '$FILENAME'}
        }),
        formatting.asmfmt
            .with({ft = {'asm'}, method = null_ls.methods.FORMATTING}),
        formatting.goimports.with({
            ft = {'go'},
            method = null_ls.methods.FORMATTING,
            extra_args = {'-srcdir', '$DIRNAME'}
        }),
        formatting.goimports_reviser
            .with({ft = {'go'}, extra_args = {'$FILENAME'}}),
        formatting.gofmt.with({ft = {'go'}}), formatting.gofumpt.with({
            ft = {'go'},
            method = null_ls.methods.FORMATTING,
            cmd = {'gofumpt'}
        }), formatting.golines.with({
            ft = {'go'},
            method = null_ls.methods.FORMATTING,
            cmd = {'golines'}
        })
    }
    return go_sources
end
local function run_in_gvm(cmd)
    local handle = io.popen("bash -c 'source ~/.gvm/scripts/gvm && " .. cmd ..
                                "'")
    if not handle then return nil end
    local result = handle:read('*a')
    handle:close()
    return result and vim.trim(result) or nil
end
local gvm_env = run_in_gvm('env') or ''
local function run_cached_gvm(cmd)
    local handle = io.popen("bash -c '" .. gvm_env .. ' && ' .. cmd .. "'")
    if not handle then return nil end
    local result = handle:read('*a')
    handle:close()
    return result and vim.trim(result) or nil
end
M.get_go_bin = function() return run_cached_gvm('which go') or 'go' end
M.get_dlv_bin = function() return run_cached_gvm('which dlv') or 'dlv' end
M.get_gopath = function()
    return run_cached_gvm('go env GOPATH') or os.getenv('GOPATH') or ''
end
M.get_go_version = function() return run_cached_gvm('go version') or '' end
function M.go_lsp(on_attach, capabilities)
    if not lspconfig.gopls then
        vim.notify('gopls LSP is not available.', vim.log.levels.ERROR)
        return
    end
    lspconfig.gopls.setup({
        cmd = {M.get_go_bin()},
        capabilities = capabilities,
        on_attach = function(client, bufnr)
            if type(on_attach) == 'function' then
                on_attach(client, bufnr)
            end
            vim.api.nvim_create_autocmd('BufWritePre', {
                buffer = bufnr,
                callback = function()
                    if vim.bo.filetype == 'go' then
                        vim.lsp.buf.format({async = false})
                    end
                end
            })
        end,
        settings = {
            gopls = {
                buildFlags = {'-tags=integration,e2e,cgo'},
                staticcheck = true,
                gofumpt = true,
                usePlaceholders = true,
                completeUnimported = true,
                experimentalWorkspaceModule = true,
                analyses = {
                    unusedparams = true,
                    shadow = true,
                    fieldalignment = true,
                    nilness = true
                },
                env = {GOPATH = M.get_gopath()}
            }
        },
        flags = {debounce_text_changes = 150},
        init_options = {buildFlags = {'-tags=cgo'}}
    })
    local status_ok, dap_go = pcall(require, 'dap-go')
    if not status_ok then
        vim.notify('dap-go not available, skipping DAP setup for Go',
                   vim.log.levels.WARN)
    else
        dap_go.setup({
            delve = {
                path = M.get_dlv_bin(),
                initialize_timeout_sec = 20,
                port = '${port}'
            }
        })
    end
    local dapui_ok, dapui = pcall(require, 'dapui')
    if dapui_ok then
        dapui.setup()
        dap.listeners.after.event_initialized['dapui_config'] = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated['dapui_config'] = function()
            dapui.close()
        end
        dap.listeners.before.event_exited['dapui_config'] = function()
            dapui.close()
        end
    end
    dap_go.setup({
        delve = {
            path = M.get_dlv_bin(),
            initialize_timeout_sec = 20,
            port = '${port}'
        }
    })
    dapui.setup()
    dap.listeners.after.event_initialized['dapui_config'] = function()
        dapui.open()
    end
    dap.listeners.before.event_terminated['dapui_config'] = function()
        dapui.close()
    end
    dap.listeners.before.event_exited['dapui_config'] = function()
        dapui.close()
    end
    if vim.fn.executable('go') == 0 then
        vim.notify('Go binary not found in PATH', vim.log.levels.WARN)
    end
    vim.api.nvim_create_user_command('GoEnvInfo', function()
        for label, value in pairs({
            ['Go Binary'] = M.get_go_bin(),
            ['Go Version'] = M.get_go_version(),
            ['GOPATH'] = M.get_gopath(),
            ['Delve Binary'] = M.get_dlv_bin()
        }) do
            vim.notify_once(string.format('%s: %s', label, value),
                            vim.log.levels.INFO)
        end
    end, {})
    vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('GoFmt', {clear = true}),
        pattern = '*.go',
        callback = function() vim.lsp.buf.format({async = false}) end
    })
end
function M.setup_go()
    M.go_lsp()
    M.go_nls()
end
return M
