-- /qompassai/Diver/lsp/biome.lua
-- Qompass AI Biome LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
-- Reference: https://biomejs.dev/blog/annoucing-biome
-- npm install -g @biomejs/biome
vim.lsp.config['biome_ls'] = {
    cmd = {
        'biome',
        'lsp-proxy',
    },
    filetypes = {
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
        local project_root = vim.fs.root(bufnr, {
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
        local has_biome = vim.fs.find(biome_config_files, {
            path = filename,
            type = 'file',
            limit = 1,
            upward = true,
            stop = vim.fs.dirname(project_root),
        })[1]
        if not has_biome then
            return
        end
        local local_cmd = project_root .. '/node_modules/.bin/biome'
        if vim.fn.executable(local_cmd) == 1 then
            config.cmd = {
                local_cmd,
                'lsp-proxy',
            }
        end
    end,
}
