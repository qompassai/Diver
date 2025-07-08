-- /qompassai/Diver/lua/plugins/lang/js.lua
-- Qompass AI JS Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
  {
    'pmizio/typescript-tools.nvim',
    ft = {
      'typescript', 'typescriptreact', 'javascript', 'javascriptreact',
      'vue', 'svelte', 'astro', 'deno'
    },
    dependencies = {
      'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig',
      'nvim-treesitter/nvim-treesitter', 'nvim-neo-tree/neo-tree.nvim',
      { 'roobert/tailwindcss-colorizer-cmp.nvim', config = true }, {
      'hrsh7th/vscode-langservers-extracted',
      cond = function()
        return vim.fn.executable('vscode-eslint-language-server') ==
            0
      end
    }, {
      'nvim-neotest/neotest',
      optional = true,
      dependencies = { 'marilari88/neotest-vitest' }
    }
    },
    config = function(_, opts) require('config.lang.js').setup_js(opts) end
  }
}
