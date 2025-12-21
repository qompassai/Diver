-- /qompassai/Diver/lua/plugins/data/dadbod.lua
-- Qompass AI Diver VimDadbod Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local sqlite_cfg = require('config.data.sqlite')
local psql_cfg = require('config.data.psql')
return {
  {
    'kristijanhusak/vim-dadbod-ui',
    ft           = { 'sqlite', 'pgsql' },
    cmd          = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    dependencies = {
      'tpope/vim-dadbod',
      { "kristijanhusak/vim-dadbod-completion", ft = { "sqlite", "pgsql" } },
    },
    init         = function()
      vim.g.db_ui_use_nerd_fonts             = 1
      vim.g.db_ui_auto_format_results        = 1
      vim.g.db_ui_win_position               = "right"
      vim.g.db_ui_winwidth                   = 40
      vim.g.db_ui_auto_execute_table_helpers = 1
      vim.g.db_ui_show_help                  = 1
      vim.g.db_ui_connections                = {
        zotero = 'sqlite:///' .. vim.fn.expand("$HOME/.local/share/zotero/zotero.sqlite")
      }
      require("config.data.common").setup_dadbod_connections('~/.config/nvim/dbx.lua')
      sqlite_cfg.sqlite_ftd()
      psql_cfg.psql_ftd()
    end,
  },
}