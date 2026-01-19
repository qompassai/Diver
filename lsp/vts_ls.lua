-- /qompassai/Diver/lsp/vt_ls.lua
-- Qompass AI Typescript Extension Wrapper LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/yioneko/vtsls
local vue_plugin = {
    name = '@vue/typescript-plugin',
    location = 'node_modules/@vue/typescript-plugin',
    languages = {
        'javascript',
        'typescript',
        'vue',
    },
}
---@param bufnr integer
---@param markers string[]
---@return string|nil
local function ts_root(bufnr, markers)
    return vim.fs.root(bufnr, markers)
end
---@param bufnr integer
---@return vim.lsp.ClientConfig|nil
local function make_config(bufnr)
    local root = ts_root(bufnr, {
        'package-lock.json',
        'yarn.lock',
        'pnpm-lock.yaml',
        'bun.lockb',
        'bun.lock',
        '.git',
    })
    ---@type vim.lsp.Config
    return {
        cmd = {
            'vtsls',
            '--stdio',
        },
        init_options = {
            hostInfo = 'neovim',
        },

        filetypes = {
            'javascript',
            'javascriptreact',
            'javascript.jsx',
            'typescript',
            'typescriptreact',
            'typescript.tsx',
        },
        root_dir = root or vim.uv.cwd(),
        settings = {
            vtsls = {
                tsserver = {
                    globalPlugins = {
                        vue_plugin,
                    },
                },
            },
        },
    }
end
return {
    make_config = make_config,
}
