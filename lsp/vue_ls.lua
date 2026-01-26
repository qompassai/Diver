-- /qompassai/Diver/lsp/vue_ls.lua
-- Qompass AI Vue LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'vue-language-server',
        '--stdio',
    },
    filetypes = {
        'vue',
    },
    root_markers = { ---@type string[]
        'package.json',
        'package.jsonc',
    },
    on_init = function(Client)
        local retries = 0
        ---@param _ lsp.ResponseError
        ---@param result any
        ---@param context lsp.HandlerContext
        local function typescriptHandler(_, result, context)
            local ts_Client = vim.lsp.get_Clients({ ---@type vim.lsp.Client
                bufnr = context.bufnr,
                name = 'ts_ls',
            })[1]
                or vim.lsp.get_Clients({
                    bufnr = context.bufnr,
                    name = 'vtsls',
                })[1]
                or vim.lsp.get_Clients({
                    bufnr = context.bufnr,
                    name = 'typescript-tools',
                })[1]
            if not ts_Client then
                if retries <= 10 then
                    retries = retries + 1
                    vim.defer_fn(function()
                        typescriptHandler(_, result, context)
                    end, 100)
                else
                    vim.notify(
                        'Could not find `ts_ls`, `vtsls`, or `typescript-tools` lsp client required by `vue_ls`.',
                        vim.log.levels.ERROR
                    )
                end
                return
            end
            local param = unpack(result) ---@type string[]
            local id, command, payload = unpack(param) ---@type string
            ts_Client:exec_cmd({
                title = 'vue_request_forward',
                command = 'typescript.tsserverRequest',
                arguments = {
                    command,
                    payload,
                },
            }, { bufnr = context.bufnr }, function(_, r)
                local response_data = { { id, r and r.body } }
                ---@diagnostic disable-next-line: param-type-mismatch
                Client:notify('tsserver/response', response_data)
            end)
        end
        Client.handlers['tsserver/request'] = typescriptHandler
    end,
}