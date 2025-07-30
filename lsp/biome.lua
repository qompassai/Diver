-- /qompassai/Diver/lsp/biome.lua
-- Qompass AI Biome LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- npm install -g @biomejs/cli-linux-x64
vim.lsp.config['biome'] = {
    cmd = { 'biome', 'lsp-proxy' },
    filetypes = {
        'astro', 'css', 'graphql', 'html', 'javascript', 'javascriptreact',
        'json', 'jsonc', 'markdown', 'mdx', 'svelte', 'typescript',
        'typescriptreact', 'typescript.tsx', 'vue'
    },
    root_markers = { 'biome.json', 'biome.jsonc', 'biome.json5', '.git' },
    capabilities = vim.lsp.protool.make_client_capabilities(),
    workspace_required = false,
    flags = {
        debounce_text_changes = 150,
    },
    single_file_support = true,
}
