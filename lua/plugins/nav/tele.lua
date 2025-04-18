return {
  "nvim-telescope/telescope.nvim",
  lazy = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-media-files.nvim",
    "jvgrootveld/telescope-zoxide",
    "nvim-telescope/telescope-ui-select.nvim",
    "folke/tokyonight.nvim",
    "IllustratedMan-code/telescope-conda.nvim",
    "catppuccin/nvim",
    "nvim-telescope/telescope-symbols.nvim",
    "cljoly/telescope-repo.nvim",
    "piersolenski/telescope-import.nvim",
    "nvim-telescope/telescope-ui-select.nvim",
    "nvim-telescope/telescope-frecency.nvim",
    "gruvbox-community/gruvbox",
    "EdenEast/nightfox.nvim",
    "rose-pine/neovim",
    {
      "nvim-telescope/telescope-dap.nvim",
      dependencies = {
        "mfussenegger/nvim-dap",
      },
      lazy = true,
    },
  },
  cmd = "Telescope",
  keys = function()
    return {
      { "<leader>th", "<cmd>Telescope colorscheme<cr>", desc = "Choose Colorscheme" },
    }
  end,
  opts = function()
    local themes = require("telescope.themes")
    return {
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
        ["ui-select"] = themes.get_dropdown({}),
      },
      pickers = {
        find_files = {
          theme = "dropdown",
        },
        buffers = {
          theme = "dropdown",
        },
        live_grep = {
          theme = "ivy",
        },
        colorscheme = {
          theme = "dropdown",
          enable_preview = true,
          winblend = 0,
        },
      },
    }
  end,
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)

    local function load_extension_safe(extension)
      local ok, _ = pcall(telescope.load_extension, extension)
      if not ok then
        vim.notify("Failed to load Telescope extension: " .. extension, vim.log.levels.WARN)
      end
    end
    load_extension_safe("fzf")
    load_extension_safe("frecency")
    load_extension_safe("dap")
    load_extension_safe("ui-select")
    load_extension_safe("zoxide")
    load_extension_safe("import")
  end,
}
