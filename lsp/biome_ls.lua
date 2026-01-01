-- /qompassai/Diver/lsp/biome.lua
-- Qompass AI Biome LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return ---@type vim.lsp.Config
{
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
    workspace_required = true,
    before_init = function(_, config)
        local bufnr = vim.api.nvim_get_current_buf()
        local fname = vim.api.nvim_buf_get_name(bufnr)
        if fname == '' then
            return
        end
        local deno_root = vim.fs.root(fname, {
            'deno.json',
            'deno.jsonc',
            'deno.lock',
        })
        if deno_root then
            return
        end
        local project_root = vim.fs.root(fname, {
            'biome.json',
            'biome.jsonc',
            'package-lock.json',
            'yarn.lock',
            'pnpm-lock.yaml',
            'bun.lockb',
            'bun.lock',
            '.git',
        }) or vim.fn.getcwd()
        local local_cmd = project_root .. '/node_modules/.bin/biome'
        if vim.fn.executable(local_cmd) == 1 then
            config.cmd = {
                local_cmd,
                'lsp-proxy',
            }
        end
    end,
}
