-- /qompassai/Diver/lsp/deno.lua
-- Qompass AI Diver Deno LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@param _ lsp.InitializeParams?
---@param config vim.lsp.Config
---@return boolean?
local function before_init(_, config)
    local fname = vim.api.nvim_buf_get_name(0)
    if fname == '' then
        return
    end
    local deno_root = vim.fs.root(fname, {
        'deno.json',
        'deno.jsonc',
    })
    if not deno_root then
        return false
    end

    config.workspace_folders = {
        {
            name = 'deno',
            uri = vim.uri_from_fname(deno_root),
        },
    }
end

return ---@type vim.lsp.Config
{
    cmd = {
        'deno',
        'lsp',
    },
    filetypes = {
        'javascript',
        'jsx',
        'typescriptreact',
        'javascriptreact',
        'tsx',
        'typescript',
    },
    before_init = before_init,
    init_options = {
        deno = {
            enable = true,
            unstable = true,
            lint = true,
            certificateStores = {},
            tlsCertificate = '',
            unsafelyIgnoreCertificateErrors = false,
            internalDebug = true,
            codeLens = {
                implementations = true,
                references = true,
                referencesAllFunctions = true,
                test = true,
            },
            suggest = {
                autoImports = true,
                names = true,
                paths = true,
                completeFunctionCalls = true,
                imports = {
                    autoDiscover = true,
                    hosts = {
                        ['https://deno.land'] = true,
                        ['https://cdn.nest.land'] = true,
                        ['https://crux.land'] = true,
                    },
                },
            },
        },
    },
    root_markers = {
        'deno.json',
        'deno.jsonc',
    },
}
