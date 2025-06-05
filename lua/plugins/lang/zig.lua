-- /qompassai/Diver/lua/plugins/lang/zig.lua
-- ----------------------------------------
return {
  {
    "ziglang/zig.vim",
    lazy = true,
    ft = { "zig", "zon" },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "zig" })
    end,
  },
  {
    "NTBBloodbath/zig-tools.nvim",
    lazy = true,
    ft = { "zig", "zon" },
    config = function()
      require("zig-tools").setup(require("config.lang.zig").setup_all().tools)
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ft = { "zig", "zon" },
    config = function()
      require("lspconfig").zls.setup(require("config.lang.zig").zig_lsp())
    end,
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    ft = { "zig", "zon" },
  },
}
