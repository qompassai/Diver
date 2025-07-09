-- /qompassai/lua/plugins/core/none-ls.lua
-- Qompass AI None-LS Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------

return {
  "nvimtools/none-ls.nvim",
	  event = "LazyFile",
  dependencies = {
    "mason.nvim",
    "nvimtools/none-ls-extras.nvim",
    "gbprod/none-ls-shellcheck.nvim",
    "gbprod/none-ls-luacheck.nvim",
    'gbprod/none-ls-php.nvim',
    'gbprod/none-ls-ecs.nvim',
  },
	init = function()
    LazyVim.on_very_lazy(function()
      LazyVim.format.register({
        name = "none-ls.nvim",
        priority = 11000,
        primary = true,
        format = function(buf)
          return LazyVim.lsp.format({
            bufnr = buf,
            filter = function(client)
              return client.name == 'null-ls'
            end,
          })
        end,
        sources = function(buf)
          local ret = require('null-ls.sources').get_available(vim.bo[buf].filetype, "NULL_LS_FORMATTING") or {}
          return vim.tbl_map(function(source)
            return source.name
          end, ret)
        end,
      })
    end)
  end,
  config = function(_, opts)
    require('config.core.none-ls').nls_cfg(opts)
  end,
}
