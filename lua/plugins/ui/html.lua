-- ~/.config/nvim/lua/plugins/ui/html.lua
return {
  {
    "windwp/nvim-ts-autotag",
    ft = { "html", "xml", "jsx", "tsx", "vue", "svelte", "php", "astro", "handlebars", "erb" },
    dependencies = {
      "stevearc/conform.nvim",
      "nvimtools/none-ls.nvim",
      "nvim-treesitter/nvim-treesitter",
      "mattn/emmet-vim",
      "brianhuster/live-preview.nvim",
      "ibhagwan/fzf-lua",
      {
        "norcalli/nvim-colorizer.lua",
        ft = { "html", "css", "astro" },
        config = function()
          require("colorizer").setup({ "html", "css", "javascript" })
        end,
      },
    },
    config = function(_, opts)
      require("config.ui.html").setup_html(opts)
    end,
  },
}
