-- autocmds.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_user_command("HelloWorld", function()
    require("hello").hello()
  end, {})