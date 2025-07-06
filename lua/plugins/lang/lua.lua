-- /qompassai/Diver/lua/plugins/lang/lua.lua
-- Qompass AI Diver Lua Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

local lua_conf = require("config.lang.lua")
local lua_ft   = { "lua", "luau" }
local plugins = {
  {
    "folke/lazydev.nvim",
    lazy = false,
    dependencies = { "folke/neodev.nvim", "Bilal2453/luvit-meta" },
    opts  = function() return lua_conf.lua_lazydev() end,
    init  = function(_, opts) require("lazydev").setup(opts) end,
  },
  {
    "camspiers/luarocks",
    lazy = false,
    opts   = function() return lua_conf.lua_luarocks() end,
    config = function(_, opts) require("luarocks").setup(opts) end,
  },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-plenary",
      "nvim-lua/plenary.nvim",
    },
    opts   = function() return lua_conf.lua_test() end,
    config = function(_, opts) require("neotest").setup(opts) end,
  },
}
return vim.tbl_map(function(spec)
  spec.ft = spec.ft or lua_ft
  return spec
end, plugins)
