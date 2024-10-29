return {
  {
    "kndndrj/nvim-projector",
    lazy = false,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "kndndrj/projector-neotest",
      "nvim-neotest/neotest",
      "nvim-telescope/telescope.nvim",
      "nvim-treesitter/nvim-treesitter",
      "neovim/nvim-lspconfig",
      "hrsh7th/nvim-cmp",
      "mfussenegger/nvim-dap",
      "folke/trouble.nvim",
      "nvim-lualine/lualine.nvim",
    },
    config = function()
      require("projector").setup( --[[optional config]])
    end,
  },
  {
    "kndndrj/nvim-dbee",
    lazy = false,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-telescope/telescope.nvim",
      "dccsillag/magma-nvim",
      "lewis6991/gitsigns.nvim",
      "hrsh7th/nvim-cmp",
      "lervag/vimtex",
      "nvim-lualine/lualine.nvim",
      "mfussenegger/nvim-dap",
    },
    build = function()
      require("dbee").install()
    end,
    config = function()
      require("dbee").setup()
      databases = {
        {
          name = "local_psql",
          type = "postgresql",
          user = "your_username", -- Replace with your PostgreSQL username
          password = "your_password", -- Replace with your PostgreSQL password
          host = "localhost", -- Use "localhost" if it's local
          port = 5432, -- Default PostgreSQL port
          database = "your_db_name", -- Replace with your PostgreSQL database name
        },
        {
          name = "other_db", -- Another database
          type = "postgresql",
          user = "your_other_username",
          password = "your_other_password",
          host = "other_host",
          port = 5432,
          database = "other_db_name",
        },
      }
    end,
  },
}
