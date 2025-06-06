-- /qompassai/Diver/lua/plugins/lang/zig.lua
-- ----------------------------------------
-- ~/.config/nvim/lua/plugins/lang/zig.lua
return {
  {
    "neovim/nvim-lspconfig",
    ft = { "zig", "zon" },
    dependencies = {
      "NTBBloodbath/zig-tools.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      setup = {
        zls = function(_, _)
          return require("config.lang.zig").setup_zig()
        end
      }
    }
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, { "zig" })
    end
  },
}
