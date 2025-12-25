-- handlebar.lua
-- Qompass AI FTDetect Handlevar
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.filetype.add({
  extension = {
    hbs = "html.handlebars",
    handlebars = "html.handlebars",
    rst = "rst",
  },
  pattern = {
    ["*.gts"] = "typescript.glimmer",
    ["*.gjs"] = "javascript.glimmer",
  },
})