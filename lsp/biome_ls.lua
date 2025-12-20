-- /qompassai/Diver/lsp/biome.lua
-- Qompass AI Biome LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'biome',
        'lsp-proxy',
    },
    filetypes = { ---@type string[]
        'astro',
        'css',
        'graphql',
        'html',
        'javascript',
        'javascriptreact',
        'json',
        'jsonc',
        'markdown',
        'mdx',
        'svelte',
        'typescript',
        'typescriptreact',
        'typescript.tsx',
        'vue',
    },
    root_markers = {
        'package-lock.json',
        'yarn.lock',
        'pnpm-lock.yaml',
        'bun.lockb',
        'bun.lock',
        '.git',
    },
    workspace_required = true,
    before_init = function(_, config)
        local bufnr = vim.api.nvim_get_current_buf()
        if
            vim.fs.root(bufnr, {
                'deno.json',
                'deno.jsonc',
                'deno.lock',
            })
        then
            return
        end
        local filename = vim.api.nvim_buf_get_name(bufnr)
        local project_root = vim.fs.root(bufnr, { ---@type string
            'package-lock.json',
            'yarn.lock',
            'pnpm-lock.yaml',
            'bun.lockb',
            'bun.lock',
            '.git',
        }) or vim.fn.getcwd()
        local biome_config_files = {
            'biome.json',
            'biome.jsonc',
            'biome.json5',
        }
        local has_biome = vim.fs.find(biome_config_files, { ---@type string
            path = filename,
            type = 'file',
            limit = 1,
            upward = true,
            stop = vim.fs.dirname(project_root), ---@type string
        })[1]
        if not has_biome then
            return
        end
        local local_cmd = project_root .. '/node_modules/.bin/biome'
        if vim.fn.executable(local_cmd) == 1 then
            config.cmd = { local_cmd, 'lsp-proxy' }
        end
    end,
}
