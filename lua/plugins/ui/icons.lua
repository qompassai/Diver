return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
    config = function()
      require("nvim-web-devicons").setup {
        -- Custom icon configuration
        override = {
          zsh = {
            icon = "",
            color = "#428850",
            cterm_color = "65",
            name = "Zsh"
          },
          lua = {
            icon = "",
            color = "#000080",
            cterm_color = "4",
            name = "Lua"
          },
          -- Adding specific icons for plugins in different directories
          nvim_be_good = {
            icon = "",
            color = "#f9dc5c",
            cterm_color = "220",
            name = "Edu"
          },
          jupyter = {
            icon = "",
            color = "#f28e1c",
            cterm_color = "214",
            name = "Jupyter"
          },
          remote = {
            icon = "",
            color = "#00bfff",
            cterm_color = "45",
            name = "Remote"
          },
          sshfs = {
            icon = "",
            color = "#4ec9b0",
            cterm_color = "80",
            name = "SSHFS"
          },
          rustaceanvim = {
            icon = "🦀",
            color = "#dea584",
            cterm_color = "173",
            name = "Rustacean"
          },
          quarto = {
            icon = "",
            color = "#ffa500",
            cterm_color = "214",
            name = "Quarto"
          },
          toggle = {
            icon = "",
            color = "#56b6c2",
            cterm_color = "74",
            name = "Toggle"
          },
          -- Add more icons as per your plugin needs
        },
        -- Default icon to use when no other icon is specified
        default = true,
        -- Option to highlight specific file icons with their respective colors
        color_icons = true,
      }
      -- Additional plugin-specific settings
      vim.cmd [[
        augroup DevIconsRefresh
          autocmd!
          autocmd BufEnter * lua require("nvim-web-devicons").refresh()
        augroup END
      ]]
    end,
  },
  {
    "yamatsum/nvim-nonicons",
    lazy = true,
    config = function()
      require("nvim-nonicons").setup {
        default = true,
        icons = {
          file = "",
          folder = "",
          git_branch = "",
          cloud = "", -- Icon for cloud-related files
          data = "",  -- Icon for data-related files
          ai = "ﮧ",    -- Icon for AI-related files
          edu = "",   -- Icon for educational plugins
          rust = "",  -- Icon for Rust-related files
        },
      }
    end,
  },
  {
    "echasnovski/mini.nvim",
    version = false,  -- Use the latest version
    lazy = true,
    config = function()
      require("mini.icons").setup({
        -- Corrected configuration
        symbols = {
          error = "",
          warn = "",
          info = "",
          hint = "",
        },
        default = {
          -- Specify the default icons in a table
          file = "",
          folder = "",
        },
        color_icons = true,  -- Enable color highlights for icons if needed
      })
    end,
  },
}
