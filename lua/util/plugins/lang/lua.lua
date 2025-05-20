-- ~/.config/nvim/lua/plugins/lang/lua.lua
return {
  {
    "folke/neoconf.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("neoconf").setup({
        live_reload = true,
        filetype_jsonc = true,
        plugins = {
          lspconfig = { enabled = true },
          jsonls = { enabled = true, configured_servers_only = true },
          lua_ls = { enabled_for_neovim_config = true },
        },
      })
    end,
  },
  {
    "folke/lazydev.nvim",
    lazy = true,
    ft = "lua",
    dependencies = {
      "camspiers/luarocks",
      "saghen/blink.cmp",
      "stevearc/conform.nvim",
      "folke/trouble.nvim",
      "nvimtools/none-ls.nvim",
      "gbprod/none-ls-luacheck.nvim",
      "nvimtools/none-ls-extras.nvim",
      "b0o/SchemaStore.nvim",
      "L3MON4D3/LuaSnip",
    },
    opts = {
      enabled = function(root_dir)
        return not vim.uv.fs_stat(root_dir .. "/.luarc.json")
      end,
    },
  },
  {
    "hrsh7th/nvim-cmp",
    ft = "lua",
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      table.insert(opts.sources, { name = "lazydev", group_index = 0 })
    end,
    dependencies = { "folke/lazydev.nvim" },
  },
}
