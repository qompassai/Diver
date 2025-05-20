-- ~/.config/nvim/lua/plugins/ui/svelte.lua
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      require("config.ui.svelte").svelte_lsp(opts)
      require("config.ui.svelte").astro_lsp(opts)
      return opts
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      return require("config.ui.svelte").svelte_treesitter(opts)
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      return require("config.ui.svelte").svelte_conform(opts)
    end,
  },
}
