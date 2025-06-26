-- /qompassai/Diver/lua/plugins/lang/lua.lua
-- -- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

local lua_conf = require('config.lang.lua')
local lua_ft = { 'lua', 'luau' }
local plugins = {
  {
    'folke/neoconf.nvim',
    lazy = false,
    priority = 1000,
    opts = function() return lua_conf.lua_neoconf() end,
    config = function(_, opts) require('neoconf').setup(opts) end,
  },
  {
    'folke/lazydev.nvim',
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "Bilal2453/luvit-meta" },
    opts = function() return lua_conf.lua_lazydev() end,
    config = function(_, opts) require('lazydev').setup(opts) end,
  },
  {
    'nvimtools/none-ls.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      'gbprod/none-ls-luacheck.nvim',
      'nvimtools/none-ls-extras.nvim',
    },
    opts = function() return { sources = lua_conf.lua_nls() } end,
    config = function(_, opts) require("null-ls").setup(opts) end,
  },
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre', 'BufNewFile' },
    opts = function() return lua_conf.lua_conform() end,
    config = function(_, opts) require('conform').setup(opts) end,
  },
  {
    'neovim/nvim-lspconfig',
    opts = function() return lua_conf.lua_lsp() end,
    config = function(_, opts) require('lspconfig').lua_ls.setup(opts) end,
  },
    {
    'camspiers/luarocks',
    event = { "BufReadPre", 'BufNewFile' },
    opts = function() return lua_conf.lua_luarocks() end,
    config = function(_, opts) require('luarocks').setup(opts) end,
  },
  {
    'camspiers/snap',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { "camspiers/luarocks" },
  },
    {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/neotest-plenary',
    'nvim-lua/plenary.nvim'
  },
  opts = function()
    return lua_conf.lua_test()
  end,
  config = function(_, opts)
    require('neotest').setup(opts)
  end
},
}
return vim.tbl_map(function(plugin)
  return vim.tbl_extend('force', plugin, { ft = lua_ft })
end, plugins)
