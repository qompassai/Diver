return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
    build = ":TSUpdate",
    opts = function()
      return require "configs.treesitter"
    end,
    config = function(_, opts)
      -- Setup Treesitter configurations
      require("nvim-treesitter.configs").setup(opts)

      require("mappings.navmap")
    end,
  },
}

