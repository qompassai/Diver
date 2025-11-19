-- /qompassai/Diver/lsp/biome.lua
-- Qompass AI Biome LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
-- npm install -g @biomejs/cli-linux-x64
vim.lsp.config['biome'] = {
  cmd = { 'biome', 'lsp-proxy' },
  filetypes = {
    'astro', 'css', 'graphql', 'html', 'javascript', 'javascriptreact',
    'json', 'jsonc', 'markdown', 'mdx', 'svelte', 'typescript',
    'typescriptreact', 'typescript.tsx', 'vue'
  },
  document_highlight = { enabled = false },
  root_markers = { 'biome.json', 'biome.jsonc', 'biome.json5', '.git' },
  capabilities = vim.lsp.protocol.make_client_capabilities(),
  on_attach = function(client, bufnr)
    client.server_capabilities.documentHighlightProvider = false
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = false }) end, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    if client.server_capabilities.inlayHintProvider and type(vim.lsp.inlay_hint) == "function" then
      vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
      vim.lsp.inlay_hint(bufnr, true)
    end
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function() vim.lsp.buf.format({ async = false }) end,
    })
  end,
  workspace_required = false,
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}