-- /qompassai/Diver/lsp/vt_ls.lua
-- Qompass AI Typescript Extension Wrapper LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/yioneko/vtsls
local vue_plugin = { ---@type string[]
    name = '@vue/typescript-plugin',
    location = 'node_modules/@vue/typescript-plugin',
    languages = {
        'javascript',
        'typescript',
        'vue',
    },
}
---@type vim.lsp.Config
return {
    cmd = {
        'vtsls',
        '--stdio',
    },
    init_options = { ---@type string[]
        hostInfo = 'neovim',
    },
    filetypes = { ---@type string[]
        'javascript',
        'javascriptreact',
        'javascript.jsx',
        'typescript',
        'typescriptreact',
        'typescript.tsx',
    },
    root_dir = function(bufnr, on_dir)
        if vim.fs(bufnr, {
            'deno.json',
            'deno.jsonc',
            'deno.lock',
        }) then
            return
        end
        local root_markers = { ---@type string[]|string[][]
            'package-lock.json',
            'yarn.lock',
            'pnpm-lock.yaml',
            'bun.lockb',
            'bun.lock',
        }
        if vim.fn.has('nvim-0.11.3') == 1 then
            root_markers = { root_markers, { '.git' } }
        else
            root_markers = vim.list_extend(root_markers, { '.git' })
        end
        local project_root = vim.fs(bufnr, root_markers) or vim.fn.getcwd()
        on_dir(project_root)
    end,
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
